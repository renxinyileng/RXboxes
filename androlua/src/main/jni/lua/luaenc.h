/*
 * luaenc —— Lua 脚本加密的运行时解密支持。
 *
 * 打包时脚本被加密成「魔数头 + 密文」，磁盘/APK 里只有密文；
 * 运行时由 lauxlib.c 的 luaL_loadfilex / luaL_loadbufferx 在把内容送进
 * 虚拟机之前透明解密，明文只在内存里短暂存在、不落盘。
 *
 * 加解密算法与密钥必须与打包脚本 native/luaenc/pack.py 完全一致，
 * 二者共用本文件同目录下 luaenc.c 里的那份密钥（pack.py 直接解析它）。
 */
#ifndef LUAENC_H
#define LUAENC_H

#include <stddef.h>

/* 识别加密候选：v2 的完整 ESC LENC 前缀（包括截断头/未知版本），
 * 或旧格式的匹配 tag。候选不代表认证成功，必须继续调用 decrypt。 */
int luaEnc_isEncrypted(const unsigned char *p, size_t n);

/* 解密。成功返回 malloc 出来的明文（调用方负责 free），*outn 为明文长度；
 * 失败（头不合法/认证失败/长度不够/内存不足）返回 NULL，并清零 *outn。
 * v2 先认证再解密；旧格式兼容读取，但不能检测密文篡改。 */
unsigned char *luaEnc_decrypt(const unsigned char *in, size_t n, size_t *outn);

/* 字节码常量池载荷盐（8 字节循环掩码）。ldump.c 写时异或、
 * lundump.c 读时还原，两端必须用同一张表；仅防直接阅读，非密码学。 */
const unsigned char *luaEnc_constMask(void);

/* 内存擦除（volatile 写，防编译器优化掉），用于解密缓冲用完即清 */
void luaEnc_wipe(void *p, size_t n);

#endif /* LUAENC_H */
