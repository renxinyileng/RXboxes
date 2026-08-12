/*
 * luaenc —— 见 luaenc.h。
 *
 * 密文格式（无明文魔数，整头对没有密钥的人来说与随机字节不可区分）：
 *   nonce[8] = 打包时随机生成（明文存放，仅用于让每个文件密钥流独立，
 *              避免"同一密钥流异或两份密文抵消"这类攻击）
 *   tag[8]   = SHA256(KEY || nonce) 的前 8 字节 —— 既当"是不是本方案加密的"
 *              判据，又顺带校验密钥/完整性。没有 KEY 就算不出 tag，
 *              所以文件头看不出任何固定特征、也 grep 不到签名
 *   ct[...]  = 明文 XOR AES-256-CTR 密钥流
 *
 * 密钥流：AES-256-CTR。key = 拆分方案重组出的 32 字节；
 *   block_j(16B) = AES256_encrypt(key, nonce(8) || u64_be(j))   j = 0,1,2,...
 *   明文[i] = 密文[i] XOR (block_{i/16})[i%16]
 * 与 pack.py 的 cryptography AES-CTR(iv = nonce || 0^8) 逐块一致（CTR 把 16
 * 字节计数器当大端整数递增，低 8 字节从 0 起即 j，高 8 字节恒为 nonce）。
 *
 * tag 仍用 SHA-256(KEY||nonce)[:8] 作"是否本方案加密"的判据 + 密钥校验，
 * 与密码算法无关。内置公有领域 SHA-256 与 AES-256，两端逐位对齐、无外部依赖。
 */
#include "luaenc.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ============================ 密钥（唯一真源） ============================
 * 打包脚本 native/luaenc/pack.py 用正则在下面两个标记之间解析这三张表
 * 重建密钥，所以两处不会各写一份、也就不会漂移。换密钥 = 重新生成三表。
 *
 * 防静态提取：32 字节密钥不再以完整形态出现在 .so 里，而是拆成
 *   SEGS[32] 乱序字节 + MASK[32] 异或掩码 + MAP[32] 位置映射(置换)，
 *   运行时重组: key[i] = SEGS[MAP[i]] ^ MASK[MAP[i]]。
 * 说明：这仍属于混淆级防护。密钥随 .so 出厂，有决心的逆向者反汇编 so
 * 并模拟重组逻辑仍能取到；目标是把门槛从"unzip 就能看源码"抬到
 * "要会脱壳 + 逆向 so"，不是数学级保密。 */
/* LUAENC_KEY_BEGIN */
static const unsigned char LUAENC_KEY_SEGS[32] = {
  0x45, 0x03, 0x63, 0x25, 0x9c, 0x9e, 0x37, 0xf5,
  0x77, 0x07, 0x49, 0xe2, 0x2d, 0xdb, 0xa7, 0x66,
  0x54, 0x02, 0x59, 0x62, 0x7b, 0x82, 0x8c, 0x53,
  0x05, 0x37, 0x03, 0x70, 0x58, 0x1a, 0x00, 0x97
};
static const unsigned char LUAENC_KEY_MASK[32] = {
  0x6f, 0xda, 0x2f, 0x2d, 0xef, 0xb9, 0xd3, 0xdd,
  0x4a, 0xc5, 0xfa, 0x07, 0x11, 0x81, 0x42, 0x3a,
  0x66, 0xaa, 0xc5, 0x33, 0x1a, 0x47, 0x56, 0x01,
  0x81, 0x0b, 0xf1, 0xe5, 0xa2, 0x11, 0x1b, 0x3d
};
static const unsigned char LUAENC_KEY_MAP[32] = {
  0x0e, 0x17, 0x08, 0x04, 0x1f, 0x1e, 0x07, 0x1a,
  0x1d, 0x02, 0x0c, 0x10, 0x12, 0x01, 0x13, 0x19,
  0x11, 0x1c, 0x05, 0x0a, 0x14, 0x16, 0x1b, 0x0f,
  0x18, 0x09, 0x06, 0x0d, 0x15, 0x03, 0x00, 0x0b
};
/* LUAENC_KEY_END */

/* 运行时重组 32 字节密钥: key[i] = SEGS[MAP[i]] ^ MASK[MAP[i]] */
static void luaEnc_getKey(unsigned char out[32]) {
  int i;
  for (i = 0; i < 32; i++)
    out[i] = (unsigned char)(LUAENC_KEY_SEGS[LUAENC_KEY_MAP[i]] ^
                             LUAENC_KEY_MASK[LUAENC_KEY_MAP[i]]);
}

/* 内存擦除:volatile 写保证不被编译器优化掉(配合解密缓冲区使用) */
void luaEnc_wipe(void *p, size_t n) {
  volatile unsigned char *v = (volatile unsigned char *)p;
  while (n--) *v++ = 0;
}

#define LUAENC_NONCE_LEN  8
#define LUAENC_TAG_LEN    8
#define LUAENC_HEADER_LEN 16   /* nonce(8) + tag(8)，无明文魔数 */

/* ------------------------------- SHA-256 ------------------------------- */
typedef struct {
    uint32_t state[8];
    uint64_t bitlen;
    unsigned char data[64];
    size_t datalen;
} sha256_ctx;

#define ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

static const uint32_t SHA256_K[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

static void sha256_transform(sha256_ctx *c, const unsigned char *d) {
    uint32_t a,b,e,f,g,h,hh,t1,t2,m[64];
    int i,j;
    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = (d[j] << 24) | (d[j+1] << 16) | (d[j+2] << 8) | (d[j+3]);
    for (; i < 64; ++i)
        m[i] = (ROR(m[i-2],17)^ROR(m[i-2],19)^(m[i-2]>>10)) + m[i-7]
             + (ROR(m[i-15],7)^ROR(m[i-15],18)^(m[i-15]>>3)) + m[i-16];
    a=c->state[0]; b=c->state[1]; e=c->state[2]; f=c->state[3];
    g=c->state[4]; h=c->state[5]; hh=c->state[6]; t1=c->state[7];
    {
        uint32_t s0=a,s1=b,s2=e,s3=f,s4=g,s5=h,s6=hh,s7=t1;
        for (i = 0; i < 64; ++i) {
            uint32_t T1 = s7 + (ROR(s4,6)^ROR(s4,11)^ROR(s4,25)) + ((s4&s5)^(~s4&s6)) + SHA256_K[i] + m[i];
            uint32_t T2 = (ROR(s0,2)^ROR(s0,13)^ROR(s0,22)) + ((s0&s1)^(s0&s2)^(s1&s2));
            s7=s6; s6=s5; s5=s4; s4=s3+T1; s3=s2; s2=s1; s1=s0; s0=T1+T2;
        }
        c->state[0]+=s0; c->state[1]+=s1; c->state[2]+=s2; c->state[3]+=s3;
        c->state[4]+=s4; c->state[5]+=s5; c->state[6]+=s6; c->state[7]+=s7;
    }
}

static void sha256_init(sha256_ctx *c) {
    c->datalen = 0; c->bitlen = 0;
    c->state[0]=0x6a09e667; c->state[1]=0xbb67ae85; c->state[2]=0x3c6ef372; c->state[3]=0xa54ff53a;
    c->state[4]=0x510e527f; c->state[5]=0x9b05688c; c->state[6]=0x1f83d9ab; c->state[7]=0x5be0cd19;
}

static void sha256_update(sha256_ctx *c, const unsigned char *data, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        c->data[c->datalen++] = data[i];
        if (c->datalen == 64) { sha256_transform(c, c->data); c->bitlen += 512; c->datalen = 0; }
    }
}

static void sha256_final(sha256_ctx *c, unsigned char *out) {
    size_t i = c->datalen;
    c->data[i++] = 0x80;
    if (i > 56) { while (i < 64) c->data[i++] = 0; sha256_transform(c, c->data); i = 0; }
    while (i < 56) c->data[i++] = 0;
    c->bitlen += (uint64_t)c->datalen * 8;
    for (int k = 7; k >= 0; --k) c->data[56 + (7 - k)] = (unsigned char)(c->bitlen >> (k * 8));
    sha256_transform(c, c->data);
    for (i = 0; i < 4; ++i)
        for (int k = 0; k < 8; ++k)
            out[i + k*4] = (unsigned char)((c->state[k] >> (24 - i*8)) & 0xff);
}

/* ------------------------------- AES-256 ------------------------------- */
/* 只实现前向分组加密（CTR 模式的密钥流只需要它）。FIPS-197，Nk=8, Nr=14。
 * 该 so 没链 OpenSSL，故自带一份，与 pack.py 逐位对齐（有 KAT 兜底）。 */
static const unsigned char AES_SBOX[256] = {
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

static unsigned char aes_xtime(unsigned char x) {
    return (unsigned char)((x << 1) ^ (((x >> 7) & 1) * 0x1b));
}

static void aes256_key_expansion(const unsigned char key[32], unsigned char rk[240]) {
    unsigned char t[4], rcon = 1;
    int i;
    memcpy(rk, key, 32);
    for (i = 32; i < 240; i += 4) {
        memcpy(t, rk + i - 4, 4);
        if (i % 32 == 0) {
            unsigned char tmp = t[0];
            t[0] = AES_SBOX[t[1]] ^ rcon;
            t[1] = AES_SBOX[t[2]];
            t[2] = AES_SBOX[t[3]];
            t[3] = AES_SBOX[tmp];
            rcon = aes_xtime(rcon);
        } else if (i % 32 == 16) {
            t[0] = AES_SBOX[t[0]]; t[1] = AES_SBOX[t[1]];
            t[2] = AES_SBOX[t[2]]; t[3] = AES_SBOX[t[3]];
        }
        rk[i]   = rk[i-32]   ^ t[0]; rk[i+1] = rk[i-31] ^ t[1];
        rk[i+2] = rk[i-30] ^ t[2]; rk[i+3] = rk[i-29] ^ t[3];
    }
}

/* 状态列主序：字节 (行 r, 列 c) = s[r + 4c] */
static void aes256_encrypt_block(const unsigned char key[32],
                                 const unsigned char in[16], unsigned char out[16]) {
    unsigned char rk[240], s[16], t;
    int round, k, c;
    aes256_key_expansion(key, rk);
    memcpy(s, in, 16);
    for (k = 0; k < 16; ++k) s[k] ^= rk[k];
    for (round = 1; round <= 14; ++round) {
        for (k = 0; k < 16; ++k) s[k] = AES_SBOX[s[k]];
        /* ShiftRows */
        t=s[1];  s[1]=s[5];  s[5]=s[9];  s[9]=s[13]; s[13]=t;
        t=s[2];  s[2]=s[10]; s[10]=t;    t=s[6];     s[6]=s[14]; s[14]=t;
        t=s[15]; s[15]=s[11];s[11]=s[7]; s[7]=s[3];  s[3]=t;
        if (round != 14) {
            for (c = 0; c < 4; ++c) {
                unsigned char *col = s + 4*c;
                unsigned char a0=col[0],a1=col[1],a2=col[2],a3=col[3];
                col[0]= aes_xtime(a0) ^ (aes_xtime(a1)^a1) ^ a2 ^ a3;
                col[1]= a0 ^ aes_xtime(a1) ^ (aes_xtime(a2)^a2) ^ a3;
                col[2]= a0 ^ a1 ^ aes_xtime(a2) ^ (aes_xtime(a3)^a3);
                col[3]= (aes_xtime(a0)^a0) ^ a1 ^ a2 ^ aes_xtime(a3);
            }
        }
        for (k = 0; k < 16; ++k) s[k] ^= rk[16*round + k];
    }
    memcpy(out, s, 16);
    luaEnc_wipe(rk, sizeof(rk));
}

/* AES-256-CTR 密钥流块 j（16 字节）：AES_key( nonce(8) || u64_be(j) )。
 * 与 pack.py 的 cryptography AES-CTR(iv = nonce || 0^8) 逐块一致：CTR 把
 * 16 字节计数器当大端整数递增，低 8 字节从 0 起即 j，高 8 字节恒为 nonce。 */
static void keystream_block(const unsigned char nonce[LUAENC_NONCE_LEN],
                            uint64_t j, unsigned char out[16]) {
    unsigned char key[32], ctr[16];
    int k;
    memcpy(ctr, nonce, LUAENC_NONCE_LEN);
    for (k = 0; k < 8; ++k) ctr[8 + k] = (unsigned char)(j >> (56 - k * 8));
    luaEnc_getKey(key);
    aes256_encrypt_block(key, ctr, out);
    luaEnc_wipe(key, sizeof(key));
}

/* tag = SHA256(KEY || nonce) 前 8 字节 */
static void compute_tag(const unsigned char nonce[LUAENC_NONCE_LEN],
                        unsigned char out[LUAENC_TAG_LEN]) {
    unsigned char full[32];
    unsigned char key[32];
    sha256_ctx c;
    luaEnc_getKey(key);
    sha256_init(&c);
    sha256_update(&c, key, sizeof(key));
    sha256_update(&c, nonce, LUAENC_NONCE_LEN);
    sha256_final(&c, full);
    memcpy(out, full, LUAENC_TAG_LEN);
    luaEnc_wipe(key, sizeof(key));
}

/* ------------------------------- 对外接口 ------------------------------ */
/* ---- 解密函数入口自校验(防运行期 inline hook) ----
 * 首次调用时快照自身入口字节,之后每次进入比对;入口被 Interceptor
 * 改写(通常改前 8-16 字节为跳转)即拒绝解密。局限:首次调用前已被
 * hook 则快照失真——这是已知的拖延层,需与 luaAnti_check 组合使用。 */
static unsigned char entry_snap[16];
static int entry_snap_ready = 0;

static int entry_hooked(void) {
    const unsigned char *fn = (const unsigned char *)(void *)&luaEnc_decrypt;
    if (!entry_snap_ready) {
        memcpy(entry_snap, fn, sizeof(entry_snap));
        entry_snap_ready = 1;
        return 0;
    }
    return memcmp(entry_snap, fn, sizeof(entry_snap)) != 0;
}

/* 字节码常量池载荷盐：8 字节循环掩码，ldump/lundump 对称使用 */
const unsigned char *luaEnc_constMask(void) {
    static const unsigned char mask[8] = {
        0xc5, 0x3a, 0x91, 0x6b, 0x2e, 0x58, 0xa7, 0x4d
    };
    return mask;
}

int luaEnc_isEncrypted(const unsigned char *p, size_t n) {
    if (!p || n < LUAENC_HEADER_LEN) return 0;
    unsigned char tag[LUAENC_TAG_LEN];
    compute_tag(p, tag);                            /* p 前 8 字节即 nonce */
    return memcmp(tag, p + LUAENC_NONCE_LEN, LUAENC_TAG_LEN) == 0;
}

unsigned char *luaEnc_decrypt(const unsigned char *in, size_t n, size_t *outn) {
    if (entry_hooked()) return NULL;  /* 入口被 inline hook：拒绝解密 */
    if (!luaEnc_isEncrypted(in, n)) return NULL;
    const unsigned char *nonce = in;                /* nonce(8) | tag(8) | ct */
    const unsigned char *ct = in + LUAENC_HEADER_LEN;
    size_t ctlen = n - LUAENC_HEADER_LEN;

    unsigned char *out = (unsigned char *)malloc(ctlen ? ctlen : 1);
    if (!out) return NULL;

    unsigned char ks[16];
    for (size_t i = 0; i < ctlen; ++i) {
        if ((i & 15) == 0) keystream_block(nonce, (uint64_t)(i >> 4), ks);
        out[i] = ct[i] ^ ks[i & 15];
    }
    if (outn) *outn = ctlen;
    return out;
}

/* -------- 仅宿主机测试用：加密 + 命令行自测，绝不参与 ndk 构建 -------- */
#ifdef LUAENC_TEST_MAIN
#include <stdio.h>

static unsigned char *enc(const unsigned char *pt, size_t n,
                          const unsigned char nonce[LUAENC_NONCE_LEN], size_t *outn) {
    size_t total = LUAENC_HEADER_LEN + n;
    unsigned char *out = (unsigned char *)malloc(total ? total : 1);
    memcpy(out, nonce, LUAENC_NONCE_LEN);
    compute_tag(nonce, out + LUAENC_NONCE_LEN);
    unsigned char ks[16];
    for (size_t i = 0; i < n; ++i) {
        if ((i & 15) == 0) keystream_block(nonce, (uint64_t)(i >> 4), ks);
        out[LUAENC_HEADER_LEN + i] = pt[i] ^ ks[i & 15];
    }
    *outn = total;
    return out;
}

int main(int argc, char **argv) {
    /* 用法: luaenc_test enc|dec  < in > out   （enc 用固定 nonce 便于比对） */
    unsigned char *buf = NULL; size_t cap = 0, n = 0; int ch;
    while ((ch = getchar()) != EOF) {
        if (n == cap) { cap = cap ? cap*2 : 4096; buf = realloc(buf, cap); }
        buf[n++] = (unsigned char)ch;
    }
    size_t outn = 0; unsigned char *out;
    if (argc > 1 && strcmp(argv[1], "enc") == 0) {
        unsigned char nonce[8] = {1,2,3,4,5,6,7,8};
        out = enc(buf, n, nonce, &outn);
    } else {
        out = luaEnc_decrypt(buf, n, &outn);
        if (!out) { fprintf(stderr, "decrypt failed\n"); return 1; }
    }
    fwrite(out, 1, outn, stdout);
    return 0;
}
#endif
