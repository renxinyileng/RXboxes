/*
 * luaenc —— 见 luaenc.h。
 *
 * v2 格式：magic[8] + nonce[12] + tag[32] + ct；magic 为 ESC LENC 02 CR LF。
 * 加密密钥 = HMAC-SHA256(master, "LUAENC2-ENC")，
 * 认证密钥 = HMAC-SHA256(master, "LUAENC2-MAC")，两者分离使用。
 * ct 使用 AES-256-CTR，计数器为 nonce[12] || u32_be(j)，j 从 0 开始；
 * tag = HMAC-SHA256(认证密钥, magic || nonce || ct)，认证成功才解密。
 * 保留旧 nonce[8] + SHA256(master || nonce)[:8] + ct 格式的读取兼容；
 * 旧 tag 只识别密钥及格式，不能检测密文篡改，新打包不再生成旧格式。
 *
 * 密钥随应用分发，仍属于提高逆向成本的混淆防护；认证不能阻止持有密钥的
 * 攻击者重新制作脚本。内置 SHA-256 与 AES-256，与 pack.py 对齐、无外部依赖。
 */
#include "luaenc.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ============================ 密钥（唯一真源） ============================
 * 打包脚本 native/luaenc/pack.py 用正则在下面两个标记之间解析这 6 张表
 * 重建密钥，所以两处不会各写一份、也就不会漂移。换拆分/换密钥 = 重新跑
 * native/luaenc/gen_key.py 生成 6 表（该脚本据目标密钥反解，绝不打印明文）。
 *
 * 防静态提取：32 字节密钥不再以完整形态、也不再以「两表异或即得」的形式
 * 出现在 .so 里，而是拆成 6 张表，用「置换 + 异或掩码 + 加法掩码 + 逐字节
 * 位旋转 + CBC 式链式白化」重组（见下 luaEnc_getKey）。链式白化令每个输出
 * 字节耦合前一个，单看任意几张表都无法还原，抬高静态分析成本。
 * 说明：这仍属于混淆级防护。密钥随 .so 出厂，有决心的逆向者反汇编 so
 * 并模拟重组逻辑仍能取到；目标是把门槛从"unzip 就能看源码"抬到
 * "要会脱壳 + 逆向 so + 复现多级重组"，不是数学级保密。 */
/* LUAENC_KEY_BEGIN */
static const unsigned char LUAENC_KEY_A[32] = {
  0xe2, 0x3d, 0xd6, 0xd3, 0x2f, 0xa8, 0xd2, 0x2f,
  0xec, 0x03, 0xee, 0x0d, 0x4c, 0xf3, 0x95, 0xa6,
  0x55, 0x37, 0x60, 0x7a, 0x3b, 0x3f, 0xcd, 0xf1,
  0xaf, 0xb1, 0x6d, 0x5c, 0x3e, 0x33, 0x91, 0xfa
};
static const unsigned char LUAENC_KEY_B[32] = {
  0x5f, 0x8e, 0xe7, 0x1b, 0x45, 0x66, 0x37, 0xdc,
  0x5f, 0x9f, 0x3c, 0x66, 0x37, 0xbd, 0xcc, 0x7d,
  0x19, 0x14, 0x9e, 0x74, 0xe3, 0x4f, 0xd4, 0x9e,
  0xe7, 0xb6, 0xc1, 0x46, 0xbc, 0xf6, 0x49, 0xe5
};
static const unsigned char LUAENC_KEY_C[32] = {
  0x18, 0xba, 0x9d, 0x23, 0x76, 0x85, 0xbb, 0xbc,
  0x0b, 0x49, 0xbd, 0x98, 0x48, 0x06, 0x9f, 0x95,
  0x34, 0x58, 0xfa, 0x27, 0x69, 0xe4, 0x05, 0x34,
  0xbc, 0xca, 0xd0, 0x2f, 0x04, 0x8a, 0x73, 0x71
};
static const unsigned char LUAENC_KEY_R[32] = {
  0x00, 0x03, 0x04, 0x04, 0x03, 0x05, 0x07, 0x02,
  0x06, 0x04, 0x07, 0x07, 0x01, 0x00, 0x05, 0x00,
  0x06, 0x02, 0x01, 0x00, 0x00, 0x07, 0x03, 0x07,
  0x04, 0x03, 0x01, 0x00, 0x07, 0x06, 0x01, 0x03
};
static const unsigned char LUAENC_KEY_P[32] = {
  0x0a, 0x08, 0x1f, 0x0e, 0x12, 0x1c, 0x01, 0x1d,
  0x0c, 0x1b, 0x1e, 0x06, 0x0f, 0x04, 0x07, 0x0b,
  0x15, 0x1a, 0x00, 0x19, 0x14, 0x09, 0x05, 0x02,
  0x03, 0x10, 0x0d, 0x13, 0x18, 0x16, 0x17, 0x11
};
static const unsigned char LUAENC_KEY_W[32] = {
  0x87, 0x18, 0xeb, 0x51, 0x28, 0xf2, 0x58, 0x09,
  0x7e, 0x0e, 0xe6, 0x5e, 0xde, 0x42, 0x36, 0xec,
  0xbe, 0xaa, 0x08, 0x1a, 0x93, 0xe5, 0x25, 0x25,
  0x66, 0x66, 0x72, 0x8b, 0xdf, 0x3d, 0xf3, 0x22
};
/* LUAENC_KEY_END */

/* 8 位循环左移；n=0 时两次移位量均为 0，避免 x>>8 的未定义行为 */
static unsigned char luaEnc_rotl8(unsigned char x, unsigned n) {
  n &= 7;
  return (unsigned char)(((x << n) | (x >> ((8 - n) & 7))) & 0xff);
}

/* volatile 锚点：本文件在 ndk 侧用 -O3 -flto 编译、六表又全是 const，编译器
 * 有能力把「const 表 → 成品密钥」整体常量折叠进 .rodata——那样拆表就白拆。
 * 把重组结果挂到一个 volatile（运行期恒为 0xA5、编译期不可知）上，强制每次
 * 真正跑一遍重组，成品 32 字节密钥不会以常量形式静态留在镜像里。 */
static volatile unsigned char luaEnc_anchor = 0xA5;

/* 阶段一单字节重组，__noinline__ 拆散成独立函数体（碎片化）：置换取表 +
 * 异或掩码 + 加法掩码 + 位旋转。其中 +、^ 用 MBA 恒等式改写
 * （a^b = (a|b)-(a&b)；a+b = (a^b)+2*(a&b)），抹掉「一眼看出是查表异或」的
 * 模式；zero 恒为 0（volatile 派生）参与运算以牵制优化器，不改变结果。 */
static __attribute__((noinline))
unsigned char luaEnc_stage1(int i, unsigned char zero) {
  unsigned char j = LUAENC_KEY_P[i];
  unsigned char a = LUAENC_KEY_A[j];
  unsigned char b = LUAENC_KEY_B[j];
  unsigned char c = LUAENC_KEY_C[j];
  unsigned char x = (unsigned char)(((a | b) - (a & b)) & 0xff);         /* a ^ b */
  unsigned char v = (unsigned char)(((x ^ c) + ((x & c) << 1)) & 0xff);  /* x + c */
  v = (unsigned char)(v ^ zero);
  return luaEnc_rotl8(v, LUAENC_KEY_R[j] & 7);
}

/* 运行时重组 32 字节密钥（与 pack.py 的 load_key、gen_key.py 的 reconstruct
 * 结果逐位一致；设备端额外做碎片化 / MBA / 防折叠混淆，不改变结果）：
 *   阶段一：j = P[i]; s[i] = rotl8( ((A[j]^B[j])+C[j])&0xff , R[j]&7 )
 *   阶段二（CBC 式链式白化）：prev = 0xA5; out[i] = s[i]^W[i]^prev; prev = out[i]
 * 成品密钥及派生密钥用完由调用方立即擦除。 */
static void luaEnc_getKey(unsigned char out[32]) {
  unsigned char s[32];
  unsigned char prev;
  unsigned char zero;
  int k, i;
  zero = (unsigned char)(luaEnc_anchor ^ 0xA5);   /* 恒 0，但非编译期常量 */
  /* 以步长 7（与 32 互素，构成置换）乱序填充 s[]，避开顺序循环的可读模式 */
  for (k = 0; k < 32; k++) {
    i = (k * 7) & 31;
    s[i] = luaEnc_stage1(i, zero);
  }
  prev = (unsigned char)luaEnc_anchor;            /* 0xA5，volatile 读 */
  for (i = 0; i < 32; i++) {
    unsigned char t = (unsigned char)(s[i] ^ LUAENC_KEY_W[i]);
    out[i] = (unsigned char)(t ^ prev);
    prev = out[i];
  }
  luaEnc_wipe(s, sizeof(s));
}

/* 内存擦除:volatile 写保证不被编译器优化掉(配合解密缓冲区使用) */
void luaEnc_wipe(void *p, size_t n) {
  volatile unsigned char *v = (volatile unsigned char *)p;
  while (n--) *v++ = 0;
}

#define LUAENC_V1_NONCE_LEN  8
#define LUAENC_V1_TAG_LEN    8
#define LUAENC_V1_HEADER_LEN 16
#define LUAENC_MAGIC_LEN     8
#define LUAENC_NONCE_LEN    12
#define LUAENC_TAG_LEN      32
#define LUAENC_HEADER_LEN   52
static const unsigned char LUAENC_MAGIC[LUAENC_MAGIC_LEN] = {
    0x1b, 'L', 'E', 'N', 'C', 2, '\r', '\n'
};

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
    uint32_t a,b,e,f,g,h,hh,t1,m[64];
    int i,j;
    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = ((uint32_t)d[j] << 24) | ((uint32_t)d[j+1] << 16)
             | ((uint32_t)d[j+2] << 8) | (uint32_t)d[j+3];
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
    luaEnc_wipe(m, sizeof(m));
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

/* 所有协议密钥均为 32 字节；分两段输入避免复制整份密文。 */
static void hmac_sha256(const unsigned char key[32],
                        const unsigned char *a, size_t an,
                        const unsigned char *b, size_t bn,
                        unsigned char out[32]) {
    unsigned char pad[64], inner[32];
    sha256_ctx c;
    size_t i;
    for (i = 0; i < sizeof(pad); ++i)
        pad[i] = (unsigned char)((i < 32 ? key[i] : 0) ^ 0x36);
    sha256_init(&c);
    sha256_update(&c, pad, sizeof(pad));
    sha256_update(&c, a, an);
    sha256_update(&c, b, bn);
    sha256_final(&c, inner);
    for (i = 0; i < sizeof(pad); ++i) pad[i] ^= 0x36 ^ 0x5c;
    sha256_init(&c);
    sha256_update(&c, pad, sizeof(pad));
    sha256_update(&c, inner, sizeof(inner));
    sha256_final(&c, out);
    luaEnc_wipe(pad, sizeof(pad));
    luaEnc_wipe(inner, sizeof(inner));
    luaEnc_wipe(&c, sizeof(c));
}

/* 比较完整认证值，不因首个不匹配字节的位置提前返回。 */
static int tags_equal(const unsigned char *a, const unsigned char *b, size_t n) {
    volatile unsigned char diff = 0;
    size_t i;
    for (i = 0; i < n; ++i) diff |= a[i] ^ b[i];
    return diff == 0;
}

static void derive_key(const unsigned char master[32], const char *label,
                       unsigned char out[32]) {
    hmac_sha256(master, (const unsigned char *)label, strlen(label), NULL, 0, out);
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
    luaEnc_wipe(t, sizeof(t));
}

/* 状态列主序：字节 (行 r, 列 c) = s[r + 4c] */
static void aes256_encrypt_block(const unsigned char rk[240],
                                 const unsigned char in[16], unsigned char out[16]) {
    unsigned char s[16], t;
    int round, k, c;
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
    luaEnc_wipe(s, sizeof(s));
}

/* 每个文件只展开一次 AES 密钥；v1 使用 64 位计数器，v2 使用 32 位。
 * 调用方先限制 v2 长度，保证计数器不会溢出后重复密钥流。 */
static void crypt_payload(const unsigned char key[32],
                          const unsigned char *nonce, size_t nonce_len,
                          const unsigned char *in, size_t n, unsigned char *out) {
    unsigned char rk[240], ctr[16], ks[16];
    size_t pos = 0;
    uint64_t block = 0;
    aes256_key_expansion(key, rk);
    memcpy(ctr, nonce, nonce_len);
    while (pos < n) {
        size_t k, count = n - pos < 16 ? n - pos : 16;
        for (k = nonce_len; k < 16; ++k)
            ctr[k] = (unsigned char)(block >> ((15 - k) * 8));
        aes256_encrypt_block(rk, ctr, ks);
        for (k = 0; k < count; ++k) out[pos + k] = in[pos + k] ^ ks[k];
        pos += count;
        ++block;
    }
    luaEnc_wipe(rk, sizeof(rk));
    luaEnc_wipe(ctr, sizeof(ctr));
    luaEnc_wipe(ks, sizeof(ks));
}

/* v2 最多使用 2^32 个分组，禁止 CTR 计数器回绕。 */
static int valid_v2_length(size_t n) {
    return (uint64_t)n <= (UINT64_C(1) << 36);
}

/* 旧格式仅用于兼容读取；此 tag 没有认证密文。 */
static void compute_legacy_tag(const unsigned char key[32],
                               const unsigned char nonce[LUAENC_V1_NONCE_LEN],
                               unsigned char out[LUAENC_V1_TAG_LEN]) {
    unsigned char full[32];
    sha256_ctx c;
    sha256_init(&c);
    sha256_update(&c, key, 32);
    sha256_update(&c, nonce, LUAENC_V1_NONCE_LEN);
    sha256_final(&c, full);
    memcpy(out, full, LUAENC_V1_TAG_LEN);
    luaEnc_wipe(full, sizeof(full));
    luaEnc_wipe(&c, sizeof(c));
}

/* 五字节前缀即可判为新协议候选；截断头和未知版本必须进入拒绝路径。 */
static int has_v2_prefix(const unsigned char *p, size_t n) {
    return p != NULL && n >= 5 && memcmp(p, LUAENC_MAGIC, 5) == 0;
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
    unsigned char key[32], tag[LUAENC_V1_TAG_LEN];
    int valid;
    if (has_v2_prefix(p, n)) return 1;
    if (!p || n < LUAENC_V1_HEADER_LEN) return 0;
    luaEnc_getKey(key);
    compute_legacy_tag(key, p, tag);
    valid = tags_equal(tag, p + LUAENC_V1_NONCE_LEN, sizeof(tag));
    luaEnc_wipe(key, sizeof(key));
    luaEnc_wipe(tag, sizeof(tag));
    return valid;
}

unsigned char *luaEnc_decrypt(const unsigned char *in, size_t n, size_t *outn) {
    unsigned char key[32], enc_key[32], mac_key[32], tag[32];
    const unsigned char *nonce, *ct;
    size_t ctlen, nonce_len;
    unsigned char *out = NULL;
    int version2;
    if (outn) *outn = 0;
    if (entry_hooked()) return NULL;  /* 入口被 inline hook：拒绝解密 */
    if (!in) return NULL;
    version2 = has_v2_prefix(in, n);
    if (version2) {
        if (n < LUAENC_HEADER_LEN || memcmp(in, LUAENC_MAGIC, LUAENC_MAGIC_LEN) != 0)
            return NULL;
        ctlen = n - LUAENC_HEADER_LEN;
        if (!valid_v2_length(ctlen)) return NULL;
        nonce_len = LUAENC_NONCE_LEN;
        nonce = in + LUAENC_MAGIC_LEN;
        ct = in + LUAENC_HEADER_LEN;
    }
    else {
        if (n < LUAENC_V1_HEADER_LEN) return NULL;
        ctlen = n - LUAENC_V1_HEADER_LEN;
        nonce_len = LUAENC_V1_NONCE_LEN;
        nonce = in;
        ct = in + LUAENC_V1_HEADER_LEN;
    }
    luaEnc_getKey(key);
    if (version2) {
        derive_key(key, "LUAENC2-MAC", mac_key);
        hmac_sha256(mac_key, in, LUAENC_MAGIC_LEN + LUAENC_NONCE_LEN,
                    ct, ctlen, tag);
        if (!tags_equal(tag, in + LUAENC_MAGIC_LEN + LUAENC_NONCE_LEN,
                        LUAENC_TAG_LEN)) goto cleanup;
        derive_key(key, "LUAENC2-ENC", enc_key);
    }
    else {
        compute_legacy_tag(key, nonce, tag);
        if (!tags_equal(tag, in + LUAENC_V1_NONCE_LEN, LUAENC_V1_TAG_LEN))
            goto cleanup;
        memcpy(enc_key, key, sizeof(enc_key));
    }
    /* 认证成功之后才分配并生成明文。空脚本仍返回可释放的有效指针。 */
    out = (unsigned char *)malloc(ctlen ? ctlen : 1);
    if (!out) goto cleanup;
    crypt_payload(enc_key, nonce, nonce_len, ct, ctlen, out);
    if (outn) *outn = ctlen;
cleanup:
    luaEnc_wipe(key, sizeof(key));
    luaEnc_wipe(enc_key, sizeof(enc_key));
    luaEnc_wipe(mac_key, sizeof(mac_key));
    luaEnc_wipe(tag, sizeof(tag));
    return out;
}

/* -------- 仅宿主机测试用：加密 + 命令行自测，绝不参与 ndk 构建 -------- */
#ifdef LUAENC_TEST_MAIN
#include <stdio.h>

static unsigned char *enc(const unsigned char *pt, size_t n,
                          const unsigned char nonce[LUAENC_NONCE_LEN], size_t *outn) {
    unsigned char key[32], enc_key[32], mac_key[32];
    unsigned char *out;
    size_t total;
    if (!valid_v2_length(n) || n > SIZE_MAX - LUAENC_HEADER_LEN) return NULL;
    total = LUAENC_HEADER_LEN + n;
    out = (unsigned char *)malloc(total);
    if (!out) return NULL;
    luaEnc_getKey(key);
    derive_key(key, "LUAENC2-ENC", enc_key);
    derive_key(key, "LUAENC2-MAC", mac_key);
    memcpy(out, LUAENC_MAGIC, LUAENC_MAGIC_LEN);
    memcpy(out + LUAENC_MAGIC_LEN, nonce, LUAENC_NONCE_LEN);
    crypt_payload(enc_key, nonce, LUAENC_NONCE_LEN, pt, n, out + LUAENC_HEADER_LEN);
    hmac_sha256(mac_key, out, LUAENC_MAGIC_LEN + LUAENC_NONCE_LEN,
                out + LUAENC_HEADER_LEN, n, out + LUAENC_MAGIC_LEN + LUAENC_NONCE_LEN);
    luaEnc_wipe(key, sizeof(key));
    luaEnc_wipe(enc_key, sizeof(enc_key));
    luaEnc_wipe(mac_key, sizeof(mac_key));
    *outn = total;
    return out;
}

int main(int argc, char **argv) {
    /* 用法: luaenc_test enc|dec < in > out；enc 固定 nonce 便于跨语言比对。 */
    unsigned char *buf = NULL, *out;
    size_t cap = 0, n = 0, outn = 0;
    int ch, status = 1;
    while ((ch = getchar()) != EOF) {
        if (n == cap) {
            size_t next = cap ? cap * 2 : 4096;
            unsigned char *grown;
            if (next < cap) goto done;
            grown = (unsigned char *)realloc(buf, next);
            if (!grown) goto done;
            buf = grown;
            cap = next;
        }
        buf[n++] = (unsigned char)ch;
    }
    if (ferror(stdin)) goto done;
    if (argc > 1 && strcmp(argv[1], "enc") == 0) {
        unsigned char nonce[LUAENC_NONCE_LEN] = {1,2,3,4,5,6,7,8,9,10,11,12};
        out = enc(buf, n, nonce, &outn);
    }
    else out = luaEnc_decrypt(buf, n, &outn);
    if (!out) { fprintf(stderr, "encrypt/decrypt failed\n"); goto done; }
    status = fwrite(out, 1, outn, stdout) != outn || fflush(stdout) != 0;
    luaEnc_wipe(out, outn);
    free(out);
done:
    luaEnc_wipe(buf, n);
    free(buf);
    return status;
}
#endif
