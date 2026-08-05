/*
 * luaenc —— 见 luaenc.h。
 *
 * 密文格式（无明文魔数，整头对没有密钥的人来说与随机字节不可区分）：
 *   nonce[8] = 打包时随机生成（明文存放，仅用于让每个文件密钥流独立，
 *              避免"同一密钥流异或两份密文抵消"这类攻击）
 *   tag[8]   = SHA256(KEY || nonce) 的前 8 字节 —— 既当"是不是本方案加密的"
 *              判据，又顺带校验密钥/完整性。没有 KEY 就算不出 tag，
 *              所以文件头看不出任何固定特征、也 grep 不到签名
 *   ct[...]  = 明文 XOR 密钥流
 *
 * 密钥流（CTR 模式，SHA-256 当 PRF）：
 *   block_j = SHA256( KEY(32) || nonce(8) || u64_le(j) )   j = 0,1,2,...
 *   明文[i] = 密文[i] XOR (block_{i/32})[i%32]
 * tag 用 SHA256(KEY||nonce)（40 字节输入），密钥流用 SHA256(KEY||nonce||ctr8)
 *（48 字节输入），输入长度不同 → tag 绝不会撞上任何密钥流块，天然域分离。
 *
 * 内置一份公有领域 SHA-256，避免依赖任何外部库，保证与 hashlib 逐位一致。
 */
#include "luaenc.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ============================ 密钥（唯一真源） ============================
 * 打包脚本 native/luaenc/pack.py 用正则在下面两个标记之间提取这 32 字节，
 * 所以两处不会各写一份、也就不会漂移。改密钥只改这里。
 *
 * 说明：这属于混淆级防护。密钥随 .so 出厂，有决心的逆向者反汇编 so 仍能取到；
 * 目标是把门槛从"unzip 就能看源码"抬到"要会脱壳 + 逆向 so"，不是数学级保密。 */
/* LUAENC_KEY_BEGIN */
static const unsigned char LUAENC_KEY[32] = {
  0xe5, 0x52, 0x3d, 0x73, 0xaa, 0x1b, 0x28, 0xf2,
  0x0b, 0x4c, 0x3c, 0x32, 0x9c, 0xd9, 0x51, 0x3c,
  0xa8, 0xfa, 0x27, 0xb3, 0x61, 0xda, 0x95, 0x5c,
  0x84, 0xc2, 0xe4, 0x5a, 0xc5, 0x08, 0x2a, 0xe5
};
/* LUAENC_KEY_END */

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

/* block_j = SHA256(KEY || nonce || u64_le(j)) */
static void keystream_block(const unsigned char nonce[LUAENC_NONCE_LEN],
                            uint64_t j, unsigned char out[32]) {
    unsigned char ctr[8];
    for (int i = 0; i < 8; ++i) ctr[i] = (unsigned char)((j >> (i * 8)) & 0xff);
    sha256_ctx c;
    sha256_init(&c);
    sha256_update(&c, LUAENC_KEY, sizeof(LUAENC_KEY));
    sha256_update(&c, nonce, LUAENC_NONCE_LEN);
    sha256_update(&c, ctr, sizeof(ctr));
    sha256_final(&c, out);
}

/* tag = SHA256(KEY || nonce) 前 8 字节 */
static void compute_tag(const unsigned char nonce[LUAENC_NONCE_LEN],
                        unsigned char out[LUAENC_TAG_LEN]) {
    unsigned char full[32];
    sha256_ctx c;
    sha256_init(&c);
    sha256_update(&c, LUAENC_KEY, sizeof(LUAENC_KEY));
    sha256_update(&c, nonce, LUAENC_NONCE_LEN);
    sha256_final(&c, full);
    memcpy(out, full, LUAENC_TAG_LEN);
}

/* ------------------------------- 对外接口 ------------------------------ */
int luaEnc_isEncrypted(const unsigned char *p, size_t n) {
    if (!p || n < LUAENC_HEADER_LEN) return 0;
    unsigned char tag[LUAENC_TAG_LEN];
    compute_tag(p, tag);                            /* p 前 8 字节即 nonce */
    return memcmp(tag, p + LUAENC_NONCE_LEN, LUAENC_TAG_LEN) == 0;
}

unsigned char *luaEnc_decrypt(const unsigned char *in, size_t n, size_t *outn) {
    if (!luaEnc_isEncrypted(in, n)) return NULL;
    const unsigned char *nonce = in;                /* nonce(8) | tag(8) | ct */
    const unsigned char *ct = in + LUAENC_HEADER_LEN;
    size_t ctlen = n - LUAENC_HEADER_LEN;

    unsigned char *out = (unsigned char *)malloc(ctlen ? ctlen : 1);
    if (!out) return NULL;

    unsigned char ks[32];
    for (size_t i = 0; i < ctlen; ++i) {
        if ((i & 31) == 0) keystream_block(nonce, (uint64_t)(i >> 5), ks);
        out[i] = ct[i] ^ ks[i & 31];
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
    unsigned char ks[32];
    for (size_t i = 0; i < n; ++i) {
        if ((i & 31) == 0) keystream_block(nonce, (uint64_t)(i >> 5), ks);
        out[LUAENC_HEADER_LEN + i] = pt[i] ^ ks[i & 31];
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
