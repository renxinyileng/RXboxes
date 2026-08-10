/*
 * luaanti —— 反 Frida / 反调试检测(见 luaanti.c)。
 */
#ifndef LUAANTI_H
#define LUAANTI_H

/* 返回检测标志位组合(非 0 即有命中),3 秒节流缓存 */
int luaAnti_check(void);

/* 延迟自毁:随机 1-5 秒后 abort */
void luaAnti_destruct(void);

#endif /* LUAANTI_H */
