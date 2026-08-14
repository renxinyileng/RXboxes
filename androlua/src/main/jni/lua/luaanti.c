/*
 * luaanti —— 反 Frida / 反调试检测(与 luaenc 配套的混淆级防护)。
 *
 * 检测手段:
 *   - maps 扫描:遍历 /proc/self/maps 找 "frida" 特征(frida-agent/gadget)
 *   - 线程名扫描:遍历 /proc/self/task 下每个线程的 comm 文件,
 *     找 gum-js-loop / pool-frida / frida 特征
 *   - 端口探测:127.0.0.1:27042(frida-server 默认端口)connect + D-Bus AUTH
 *     握手,响应为 D-Bus 风格(REJECTED/OK/DATA/ERROR)即命中
 *   - TracerPid:/proc/self/status 的 TracerPid 非 0
 *
 * 文件读取全部走 openat/read syscall 直连,绕过 libc hook(攻击者
 * hook open/read 伪造内容也骗不到);端口探测用普通 libc socket(网络层
 * hook 罕见)。检测结果 3 秒节流缓存,避免高频率解密时反复全量扫描。
 *
 * 注意:这是拖延层,不是防线。Frida 改名/换端口/重编译可绕过;
 * 2025 年起 KPM(内核级)可屏蔽 TracerPid 读取。触发策略由调用方决定
 * (lauxlib 解密钩子检测到即延迟自毁)。
 */
#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#include "luaanti.h"

#define LUAANTI_FRIDA_MAPS    1
#define LUAANTI_FRIDA_THREAD  2
#define LUAANTI_FRIDA_PORT    4
#define LUAANTI_TRACER        8

/* 检测节流窗口(秒) */
#define LUAANTI_THROTTLE 3

static int cached_flags = 0;
static long last_check_sec = 0;

/* ---------------------------- 字符串混淆 ----------------------------------
 * 反注入特征词若以明文留在 .so 里，`strings libluajava.so | grep frida` 一下
 * 就把整套检测方案抖搂干净（查什么、连哪个端口、读哪个 /proc 字段）。这里
 * 把它们按固定 XOR 盐存放，用时解到栈缓冲、用完即弃——仅抬高 `strings`/静态
 * 阅读的门槛，非密码学（动态下断点在解码处仍能看到明文）。 */
#define LUAANTI_XOR 0x5a
/* volatile 盐：否则 -O3 会把 deobf(const 数组, 常量盐) 在编译期算出明文并塞进
 * .rodata（等于没混淆）。挂到 volatile 上（运行期恒为 0x5a、编译期不可知），
 * 强制解码在运行期发生，明文只在栈上短暂出现。 */
static volatile unsigned char luaanti_salt = LUAANTI_XOR;
/* 各特征词密文（明文 ^0x5a）。改动务必与末尾 LUAANTI_TEST_MAIN 自测同步。 */
static const unsigned char OBF_MAPS[]   = { 0x75,0x2a,0x28,0x35,0x39,0x75,0x29,0x3f,0x36,0x3c,0x75,0x37,0x3b,0x2a,0x29 }; /* "/proc/self/maps" */
static const unsigned char OBF_TASK[]   = { 0x75,0x2a,0x28,0x35,0x39,0x75,0x29,0x3f,0x36,0x3c,0x75,0x2e,0x3b,0x29,0x31 }; /* "/proc/self/task" */
static const unsigned char OBF_COMM[]   = { 0x75,0x39,0x35,0x37,0x37 };                                                     /* "/comm" */
static const unsigned char OBF_FRIDA[]  = { 0x3c,0x28,0x33,0x3e,0x3b };                                                     /* "frida" */
static const unsigned char OBF_GUMJS[]  = { 0x3d,0x2f,0x37,0x77,0x30,0x29 };                                                /* "gum-js" */
static const unsigned char OBF_POOLF[]  = { 0x2a,0x35,0x35,0x36,0x77,0x3c,0x28,0x33,0x3e,0x3b };                            /* "pool-frida" */
static const unsigned char OBF_REJECTED[] = { 0x08,0x1f,0x10,0x1f,0x19,0x0e,0x1f,0x1e };                                    /* "REJECTED" */
static const unsigned char OBF_OKSP[]   = { 0x15,0x11,0x7a };                                                               /* "OK " */
static const unsigned char OBF_DATA[]   = { 0x1e,0x1b,0x0e,0x1b };                                                          /* "DATA" */
static const unsigned char OBF_ERROR[]  = { 0x1f,0x08,0x08,0x15,0x08 };                                                     /* "ERROR" */
static const unsigned char OBF_STATUS[] = { 0x75,0x2a,0x28,0x35,0x39,0x75,0x29,0x3f,0x36,0x3c,0x75,0x29,0x2e,0x3b,0x2e,0x2f,0x29 }; /* "/proc/self/status" */
static const unsigned char OBF_TRACER[] = { 0x0e,0x28,0x3b,0x39,0x3f,0x28,0x0a,0x33,0x3e,0x60 };                            /* "TracerPid:" */
static const unsigned char OBF_AUTH[]   = { 0x5a,0x1b,0x0f,0x0e,0x12,0x57,0x50 };                                           /* "\0AUTH\r\n" (7B) */

/* 解混淆到调用方栈缓冲（缓冲须 >= n+1）；返回以 NUL 结尾的明文指针。 */
static char *deobf(const unsigned char *o, size_t n, char *buf) {
    unsigned char salt = luaanti_salt;   /* volatile 读，阻止编译期折叠出明文 */
    size_t i;
    for (i = 0; i < n; i++) buf[i] = (char)(o[i] ^ salt);
    buf[n] = '\0';
    return buf;
}
#define DEOBF(dst, arr) deobf((arr), sizeof(arr), (dst))

static int raw_open(const char *path, int flags) {
    return (int)syscall(SYS_openat, AT_FDCWD, path, flags, 0);
}

static ssize_t raw_read(int fd, void *buf, size_t n) {
    return syscall(SYS_read, fd, buf, n);
}

static void raw_close(int fd) {
    syscall(SYS_close, fd);
}

/* 手写子串匹配(不依赖 memmem) */
static int has_substr(const char *hay, size_t n, const char *needle) {
    size_t m = strlen(needle);
    size_t i, j;
    if (m == 0 || n < m) return 0;
    for (i = 0; i + m <= n; i++) {
        for (j = 0; j < m && hay[i + j] == needle[j]; j++)
            ;
        if (j == m) return 1;
    }
    return 0;
}

/* 分块扫描 maps,块间保留 7 字节重叠避免跨块漏检 */
static int scan_maps(void) {
    char buf[4096];
    char tail[7];
    size_t tlen = 0;
    ssize_t n;
    char pbuf[24], nbuf[8];
    int fd = raw_open(DEOBF(pbuf, OBF_MAPS), O_RDONLY);
    if (fd < 0) return 0;
    DEOBF(nbuf, OBF_FRIDA);
    while ((n = raw_read(fd, buf, sizeof(buf))) > 0) {
        char win[4103];
        size_t wlen = tlen + (size_t)n;
        memcpy(win, tail, tlen);
        memcpy(win + tlen, buf, (size_t)n);
        if (has_substr(win, wlen, nbuf)) {
            raw_close(fd);
            return 1;
        }
        tlen = (size_t)n < 7 ? (size_t)n : 7;
        memcpy(tail, win + wlen - tlen, tlen);
    }
    raw_close(fd);
    return 0;
}

/* 扫描 /proc/self/task 下各线程 comm 文件找 Frida 特征线程名 */
static int scan_threads(void) {
    char taskbuf[24], commsuf[8], n_gum[8], n_pool[12], n_frida[8];
    DIR *d = opendir(DEOBF(taskbuf, OBF_TASK));
    struct dirent *e;
    if (d == NULL) return 0;
    DEOBF(commsuf, OBF_COMM);            /* "/comm" */
    DEOBF(n_gum, OBF_GUMJS);
    DEOBF(n_pool, OBF_POOLF);
    DEOBF(n_frida, OBF_FRIDA);
    while ((e = readdir(d)) != NULL) {
        char p[96];
        char comm[64];
        ssize_t n;
        int fd;
        if (e->d_name[0] == '.') continue;
        /* 用 "%s%s%s" 拼接（路径段本身是解出来的明文），避免非字面量格式串 */
        snprintf(p, sizeof(p), "%s/%s%s", taskbuf, e->d_name, commsuf);
        fd = raw_open(p, O_RDONLY);
        if (fd < 0) continue;
        n = raw_read(fd, comm, sizeof(comm) - 1);
        raw_close(fd);
        if (n <= 0) continue;
        comm[n] = '\0';
        if (strstr(comm, n_gum) != NULL ||
            strstr(comm, n_pool) != NULL ||
            strstr(comm, n_frida) != NULL) {
            closedir(d);
            return 1;
        }
    }
    closedir(d);
    return 0;
}

/* 探测 frida-server 默认端口:connect + D-Bus AUTH 握手 */
static int probe_port(void) {
    int fd = (int)socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sa;
    struct timeval tv;
    fd_set wf;
    int fl, r, hit = 0;
    if (fd < 0) return 0;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_port = htons(27042);
    sa.sin_addr.s_addr = htonl(0x7f000001);  /* 127.0.0.1 */
    fl = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);
    r = connect(fd, (struct sockaddr *)&sa, sizeof(sa));
    if (r != 0 && errno != EINPROGRESS) {
        close(fd);
        return 0;
    }
    FD_ZERO(&wf);
    FD_SET(fd, &wf);
    tv.tv_sec = 0;
    tv.tv_usec = 200000;  /* 200ms */
    r = select(fd + 1, NULL, &wf, NULL, &tv);
    if (r > 0) {
        char auth[8];
        DEOBF(auth, OBF_AUTH);           /* "\0AUTH\r\n"，含前导 NUL，按定长发 */
        if (send(fd, auth, sizeof(OBF_AUTH), 0) > 0) {
            char resp[64];
            ssize_t n = recv(fd, resp, sizeof(resp) - 1, 0);
            if (n > 0) {
                char r_rej[12], r_ok[8], r_dat[8], r_err[8];
                resp[n] = '\0';
                /* D-Bus 响应以 NUL 开头,含 REJECTED/OK/DATA/ERROR */
                if (resp[0] == '\0' &&
                    (strstr(resp, DEOBF(r_rej, OBF_REJECTED)) != NULL ||
                     strstr(resp, DEOBF(r_ok, OBF_OKSP)) != NULL ||
                     strstr(resp, DEOBF(r_dat, OBF_DATA)) != NULL ||
                     strstr(resp, DEOBF(r_err, OBF_ERROR)) != NULL))
                    hit = 1;
            }
        }
    }
    close(fd);
    return hit;
}

/* /proc/self/status 的 TracerPid 非 0 */
static int check_tracer(void) {
    char buf[2048];
    char *p;
    ssize_t n;
    char pbuf[24], tbuf[12];
    int fd = raw_open(DEOBF(pbuf, OBF_STATUS), O_RDONLY);
    if (fd < 0) return 0;
    n = raw_read(fd, buf, sizeof(buf) - 1);
    raw_close(fd);
    if (n <= 0) return 0;
    buf[n] = '\0';
    DEOBF(tbuf, OBF_TRACER);             /* "TracerPid:" */
    p = strstr(buf, tbuf);
    if (p == NULL) return 0;
    p += sizeof(OBF_TRACER);            /* 越过 "TracerPid:"（10 字节） */
    while (*p == ' ' || *p == '\t') p++;
    return (*p != '0' && *p != '\n' && *p != '\0');
}

/* 全量检测(节流窗口内直接返回缓存) */
int luaAnti_check(void) {
    struct timespec ts;
    long now;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
        return cached_flags;
    now = ts.tv_sec;
    if (now - last_check_sec < LUAANTI_THROTTLE)
        return cached_flags;
    cached_flags = 0;
    if (scan_maps()) cached_flags |= LUAANTI_FRIDA_MAPS;
    if (scan_threads()) cached_flags |= LUAANTI_FRIDA_THREAD;
    if (probe_port()) cached_flags |= LUAANTI_FRIDA_PORT;
    if (check_tracer()) cached_flags |= LUAANTI_TRACER;
    last_check_sec = now;
    return cached_flags;
}

/* 延迟自毁:随机 1-5 秒后 abort,增加检测点被定位难度 */
void luaAnti_destruct(void) {
    struct timespec ts;
    ts.tv_sec = 1 + (long)(rand() % 5);
    ts.tv_nsec = 0;
    nanosleep(&ts, NULL);
    abort();
}

/* -------- 仅宿主机测试用：校验混淆表解出的明文与预期一致，绝不参与 ndk 构建。
 * 编码手误会静默让某路检测失效（很危险），这里在编译期就把它挡下：
 *   gcc -DLUAANTI_TEST_MAIN -o /tmp/at luaanti.c && /tmp/at   （全 OK 才算过）-------- */
#ifdef LUAANTI_TEST_MAIN
#include <stdio.h>
static int chk(const char *name, const unsigned char *o, size_t n, const char *want) {
    char buf[64];
    deobf(o, n, buf);
    if (n != strlen(want) || memcmp(buf, want, n) != 0) {
        printf("FAIL %s\n", name);
        return 1;
    }
    return 0;
}
int main(void) {
    int bad = 0;
    bad |= chk("MAPS", OBF_MAPS, sizeof(OBF_MAPS), "/proc/self/maps");
    bad |= chk("TASK", OBF_TASK, sizeof(OBF_TASK), "/proc/self/task");
    bad |= chk("COMM", OBF_COMM, sizeof(OBF_COMM), "/comm");
    bad |= chk("FRIDA", OBF_FRIDA, sizeof(OBF_FRIDA), "frida");
    bad |= chk("GUMJS", OBF_GUMJS, sizeof(OBF_GUMJS), "gum-js");
    bad |= chk("POOLF", OBF_POOLF, sizeof(OBF_POOLF), "pool-frida");
    bad |= chk("REJECTED", OBF_REJECTED, sizeof(OBF_REJECTED), "REJECTED");
    bad |= chk("OKSP", OBF_OKSP, sizeof(OBF_OKSP), "OK ");
    bad |= chk("DATA", OBF_DATA, sizeof(OBF_DATA), "DATA");
    bad |= chk("ERROR", OBF_ERROR, sizeof(OBF_ERROR), "ERROR");
    bad |= chk("STATUS", OBF_STATUS, sizeof(OBF_STATUS), "/proc/self/status");
    bad |= chk("TRACER", OBF_TRACER, sizeof(OBF_TRACER), "TracerPid:");
    {
        char buf[8]; const char want[7] = {0,'A','U','T','H','\r','\n'};
        deobf(OBF_AUTH, sizeof(OBF_AUTH), buf);
        if (sizeof(OBF_AUTH) != 7 || memcmp(buf, want, 7) != 0) {
            printf("FAIL AUTH\n"); bad = 1;
        }
    }
    printf(bad ? "luaanti 混淆自测：有条目不匹配\n"
               : "luaanti 混淆自测：全部 OK\n");
    return bad;
}
#endif
