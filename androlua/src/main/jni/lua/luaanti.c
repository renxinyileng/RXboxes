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
    int fd = raw_open("/proc/self/maps", O_RDONLY);
    if (fd < 0) return 0;
    while ((n = raw_read(fd, buf, sizeof(buf))) > 0) {
        char win[4103];
        size_t wlen = tlen + (size_t)n;
        memcpy(win, tail, tlen);
        memcpy(win + tlen, buf, (size_t)n);
        if (has_substr(win, wlen, "frida")) {
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
    DIR *d = opendir("/proc/self/task");
    struct dirent *e;
    if (d == NULL) return 0;
    while ((e = readdir(d)) != NULL) {
        char p[96];
        char comm[64];
        ssize_t n;
        int fd;
        if (e->d_name[0] == '.') continue;
        snprintf(p, sizeof(p), "/proc/self/task/%s/comm", e->d_name);
        fd = raw_open(p, O_RDONLY);
        if (fd < 0) continue;
        n = raw_read(fd, comm, sizeof(comm) - 1);
        raw_close(fd);
        if (n <= 0) continue;
        comm[n] = '\0';
        if (strstr(comm, "gum-js") != NULL ||
            strstr(comm, "pool-frida") != NULL ||
            strstr(comm, "frida") != NULL) {
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
        const char auth[] = "\0AUTH\r\n";
        if (send(fd, auth, sizeof(auth) - 1, 0) > 0) {
            char resp[64];
            ssize_t n = recv(fd, resp, sizeof(resp) - 1, 0);
            if (n > 0) {
                resp[n] = '\0';
                /* D-Bus 响应以 NUL 开头,含 REJECTED/OK/DATA/ERROR */
                if (resp[0] == '\0' &&
                    (strstr(resp, "REJECTED") != NULL ||
                     strstr(resp, "OK ") != NULL ||
                     strstr(resp, "DATA") != NULL ||
                     strstr(resp, "ERROR") != NULL))
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
    int fd = raw_open("/proc/self/status", O_RDONLY);
    if (fd < 0) return 0;
    n = raw_read(fd, buf, sizeof(buf) - 1);
    raw_close(fd);
    if (n <= 0) return 0;
    buf[n] = '\0';
    p = strstr(buf, "TracerPid:");
    if (p == NULL) return 0;
    p += strlen("TracerPid:");
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
