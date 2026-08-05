# Lua 脚本保护方案对比报告(RXboxes)

> 调研日期:2026-08 | 基线:本地仓库 `androlua/src/main/jni/lua`(标准 Lua 5.4.8)
> 目标:找出「最强、最新」的 .lua 保护方案,含对抗动态 dump;对比后给出分阶段落地路线图。

---

## 1. 威胁模型与目标

| 攻击者层级 | 手段 | 现状(未加固) | 目标 |
|---|---|---|---|
| L0 unzip 党 | 解包 APK 直接读 `assets/*.lua` | ❌ 明文可读 | ✅ 已达成(CTR 加密) |
| L1 静态分析 | 取密钥 → 离线解密全部脚本;`unluac` 反编译字节码 | ❌ 密钥硬编码可提取 | ✅ 可达成 |
| L2 动态分析 | Frida hook `luaL_loadbufferx` / dump 内存明文 | ❌ 明文在内存驻留 | ⚠️ 拖延到天/周级 |
| L3 专业逆向 | 反汇编 so、KPM 内核级绕过、脱壳 | ❌ | ❌ 客户端无法绝对防住 |

**诚实边界**:密钥/明文最终必然存在于客户端内存,"数学级保密"在纯客户端场景不成立。
本报告目标是:把门槛从「unzip 就读源码」抬到「要会脱壳 + 逆向 native + 对抗反调试」,
动态 dump 从「小时级」拖到「天/周级」。

---

## 2. 现状盘点(本地代码)

| 组件 | 位置 | 现状 |
|---|---|---|
| 运行时解密 | `androlua/src/main/jni/lua/luaenc.c` | nonce(8)+tag(8)+CTR-XOR,SHA-256 当 PRF,无明文魔数;密钥 32B 硬编码(`LUAENC_KEY_BEGIN/END` 之间) |
| 加载钩子 | `lauxlib.c` :836(`luaL_loadfilex`)/ :901(`luaL_loadbufferx`) | 命中 tag 即透明解密;Java 侧全部 10 类加载入口(LloadFile/LloadBuffer:init.lua、main.lua、update.lua、Welcome、LuaAssetLoader、Runnable/Service/Thread/TimerTask)均经此两钩子 |
| 打包加密器 | `native/luaenc/pack.py` | 与 C 端同算法同密钥(解析 luaenc.c);`selftest` 通过 |
| CI 集成 | `.github/workflows/android.yml` | 签名前 `enc-apk` + `verify-apk` 强校验 |
| 构建 | `Android.mk`(luaenc.c 已编入)、`Application.mk`(16KB 对齐) | 正常 |
| 反 hook/反调试 | — | **无任何代码** |
| 语义回归 | `native.yml` | 仅编译 + 导出符号校验,无语义回归 |

**现状结论**:加密管线工程完整、两端一致,但属于「混淆级」:反汇编 so 取密钥或
Frida hook 解密点即可全破,内存明文无对抗。

---

## 3. 六类方案横向对比(2023–2025 工具链实测)

| 方案 | 现成开源 | 5.4 改动量 | 挡住什么 | 弱点 |
|---|---|---|---|---|
| ① `luac -s` strip 调试信息 | 内置(`string.dump(f,true)`) | **0** | **unluac 直接失效**(unluac 要求调试信息未剥离) | 仍可被针对性工具恢复(困难) |
| ② 源码级混淆(Prometheus 思路) | 有:hercules-obfuscator(220★,活跃,纯 Lua,支持 5.4) | 打包期接入 | 人读源码 | 产出仍是标准字节码,**unluac 可解** |
| ③ LuaJIT 字节码 | 有(ljd 反编译质量差) | **大:换 VM** | 反编译工具 | AndroLua+ 的 C API/require/模块体系要全量适配,ARM64 维护是长期痛点;**不推荐为保护目的切换** |
| ④ 定制 VM(opcode 重排/位域盐/常量池加密) | **无**(历史项目 ObscureLua/LuaVirtualMachine/K4LC/LuaGuard 均已删库;可参考 ironbrew-2,Luau 生态) | 重排 1–2 人日;常量池加密 2–4 人日;变长指令 2–4 周 | unluac/luadec 全灭;静态对齐/语义恢复大幅变难 | 需自研;动态 dump 仍可破,须配反调试 |
| ⑤ 服务端下发 + 一次性 token | 无(自建) | 中(加载器 + 服务端) | 静态/半动态分析(**质变**) | 需服务器;root 环境抓包/重放需配 SSL pinning + 防重放 |
| ⑥ 混合加固(现有管线增量) | 有(Darvin 系列) | 低 | 各层叠加拖延 | 单层均可绕过 |

**商业方案核实(2026-08 实测)**:

- **ppprotect**:GitHub / npm / Bing 三重检索**零命中**,查无此物,不可依赖。
- **腾讯 LuaGuard、虎牙 LuaVM**:无任何公开仓库/文档/演讲,内部不可验证,不可依赖。
- **Luraph**(lura.ph):唯一确认活跃的通用 Lua 商业混淆服务(付费云端 API,2017 年至今,官方 GitHub + Node/.NET/VSCode SDK);SDK 选项含 `TARGET_VERSION: "Lua 5.2"`,**Lua 5.4 支持未公开确认**,可联系官方验证。
- **FairGuard**(fair-guard.com):真实商业产品,但脚本加密**绑定 Cocos 引擎**,不适用独立 5.4 解释器。
- **Roblox 生态**(PSU 已停更、Moonsec 源码已泄露被批量破解、Prometheus 开源活跃):技术思路可借鉴,产物不兼容标准 5.4。
- **结论:市场上没有可验证的、直接支持标准 Lua 5.4 的现成商业加壳产品,只能自研或组合开源方案。**

---

## 4. 最强组合推荐(按威胁模型 L0–L2)

```
Lua 5.4 字节码 strip(零成本,unluac 失效)
+ 定制 VM:opcode 重排 + 位域盐(构建期随机,每包不同)
+ 常量池加密(字符串/数字常量)
+ 现有 CTR-XOR 加密管线(密文编入 .so,去掉 unzip 拿密文这步)
+ 密钥运行时派生(设备指纹 + 多段拼接,不再静态可见)
+ 反 hook(函数头比对 + 直接地址调用绕过 GOT/PLT)
+ 反 Frida(maps/端口 D-Bus/线程名, syscall 直读防 libc hook)
+ 反调试(TracerPid,注意 KPM 可绕过 → 只作一层)
+ 内存对抗(explicit_bzero 擦除 + 双缓冲 mmap 页 + 按需解密;Android 16+ 可加 mseal)
+ 核心业务脚本服务端下发 + 一次性 token(质变层,可选)
```

**各层实测工具链依据**:

- **unluac**(sourceforge.net/projects/unluac,仍更新,支持 5.0–5.4):要求调试信息未剥离 → strip 后失效;luadec(viruscamp/luadec,1.3k★)只到 5.3,**5.4 天然免疫**。
- **纯 opcode 重排可被恢复**:ulua(bananabr/ulua)演示了「指令交换混淆」的已知明文/统计攻击 → 必须叠加位域盐 + 构建期随机映射 + 常量池加密。
- **VM 混淆可被自动化去虚拟化**:Prometheus-Deobfuscator(0x251,62★)已能对 Luau VM 混淆做 CFG 重建;LuaHunt(hayden-droid/Dev)能语义测试自动分析定制解释器 → 反编译只是被大幅拖延,不是永远。
- **反 dump 落地清单**(13 项技术,含 Android 兼容性/误报风险,详见调研):
  - 低成本低误报:`TracerPid`、maps 库名扫描、27042+D-Bus 握手、线程名(gum-js-loop)、named pipe、`explicit_bzero` 擦除、双缓冲 mmap+munmap、GOT/PLT 绕过调用。
  - 中成本:`/proc/self/mem` 比对、入口字节比对(inline hook 检测,注意 Stalker 时序攻击)、解释器循环内按需解密(chunk 级,密钥链派生)、inotify 防 dump 监控(误报高)。
  - 高成本/高收益:`mseal`(仅 64 位 + Android 16+ / 内核 6.10+,封禁解密页与自身 .text,无 munseal;误报风险高,勿封 malloc 堆)。
  - 2025 新威胁:**KPM(内核级)可 hook openat 屏蔽 TracerPid 读取** → 所有检测都按「可绕过层」设计,多层叠加才是目的。

---

## 5. 分阶段落地路线图(含文件级改动点)

### 阶段 A:零成本加固(约 1 人日)
- 打包管线(`native/luaenc/pack.py` + CI)增加 `string.dump(f, true)` strip 步骤:把 `.lua` 先编译成 strip 后字节码再加密分发。
  - 改动点:`pack.py` 新增 `strip` 模式(Lua 5.4 二进制格式需对照 `lundump.c` 实现,或打包机装 lua5.4 用 `luac -s`);`android.yml` 加密步骤前调用。
  - 效果:unluac 即刻失效(调试信息剥离)。
  - 风险:AndroLua+ 的 `loadstring`/`load` 文本加载路径不受影响;`require` 走 `luaL_loadfilex` 二进制路径需全量回归。

### 阶段 B:低成本加固(约 1 周)
- 密文编入 .so:`xxd -i` 把密文(或直接脚本)编进 `luaenc.c`,APK 里连密文文件都不存在;加载走内存路径(已有 `luaL_loadbufferx` 钩子)。
- 密钥运行时派生:`luaenc.c` 去掉静态 32B 数组,改为 多段拼接 + 设备指纹(SHA-256(`Build.FINGERPRINT` 等)派生)+ 异或表;`pack.py` 同步生成派生参数。
- 反 hook:`lauxlib.c` 钩子函数头字节比对(inline hook 检测);内部通过 `dlopen` + `DT_SYMTAB` 直接解析地址调用,绕过 GOT/PLT。
- 反 Frida:`luaenc.c`/新 `luaanti.c` 实现 maps 扫描、27042 D-Bus 握手、线程名检测,全部 **syscall 直读**(openat/read/connect)防 libc hook;检测到即延迟自毁。
- 反调试:`/proc/self/status` TracerPid(视为可绕过层)。
- 内存擦除:解密后 `explicit_bzero` 明文缓冲;双缓冲 mmap 页,用完 munmap。
- 回归:新增语义回归脚本(现有 `native.yml` 只有编译+符号校验)。

### 阶段 C:定制 VM(约 1–2 周,自研)
- **C1 opcode 重排 + 位域盐(1–2 人日)**:重排 `lopcodes.h` 枚举 + `ljumptab.h` 同步(文件头自带生成命令);改 `POS_*`/`SIZE_*`/`GETARG_*`/`SETARG_*`/`CREATE_*` 宏(交换 B/C、Bx 加盐)。构建期随机映射 → 每包不同。lparser.c 零改动;ldump/lundump 两端一致即可。
- **C2 常量池加密(2–4 人日)**:`ldump.c dumpConstants`(:112-135)加密 + `lundump.c` 解密;按需解密改 `lvm.c` 常量访问路径(`k[]` 常量表,5.4 所有 LOADK/LOADKX/GETTABUP 都走这里)。字符串常量最终以 TString 明文存在 → 只能拖延。
- **C3(可选,不建议首期)变长指令(2–4 周,研究级)**:重写 `lvm.c` 取指/pc 步进、`lcode.c` 两遍编码与跳转 patch、`ljumptab.h` dispatch、lineinfo↔pc 映射、`lua_Hook` count。5.4 特有风险:83 个 opcode 中约 20 个为 5.4 新增(LOADI/LOADF/MMBIN*/EQK/RETURN0/TBC/LFALSESKIP 等)须全覆盖;goto 的 OP_JMP(isJ 25 位偏移)+ OP_CLOSE/OP_TBC 配合;Android ARM 上热循环可能慢 10–30%;AndroLua+ 扩展(defer/getfenv 等)在 lparser/lvm 有补丁,需全量语义回归。
- 回归通道:阶段 B 新增的语义回归脚本 + `native.yml` 编译校验。

### 阶段 D:质变层(服务端下发,约 1–2 周 + 服务器)
- 核心业务脚本不出包;启动时拉取 + 短期一次性 token + 设备绑定鉴权,内存执行不落盘(走已有 `LloadBuffer` 钩子路径)。
- 配套:SSL pinning(OkHttp/Cronet)、nonce + 时间窗防重放。
- 弱点:root 环境动态分析、抓包重放 → 与阶段 B/C 的检测叠加。

---

## 6. 结论

1. **2023–2025 没有可验证的、直接支持标准 Lua 5.4 的商业加壳产品**(ppprotect 查无此物,LuaGuard/虎牙 LuaVM 无公开资料,Luraph 的 5.4 支持未确认)——**只能自研或组合开源思路**。
2. **最强可行组合** = 字节码 strip(免费让 unluac 失效)+ 定制 VM(重排+位域盐+常量池加密)+ 现有加密管线 + 密钥派生 + 反 hook/反 Frida/反调试 + 内存擦除/按需解密 + 核心逻辑服务端下发。
3. **性价比排序**:阶段 A(零成本,立竿见影)→ 阶段 B(低成本,把 L1 静态分析基本堵死)→ 阶段 C(中等成本,堵死 unluac/luadec,拖延动态)→ 阶段 D(质变,但有服务端运维成本)。
4. **诚实边界**:客户端永远无法绝对防住 L3 专业逆向(密钥/明文终在内存;Frida/KPM 组合可绕过任何检测);定制 VM 的天花板是把「小时级 dump」拖到「天/周级」,同时反编译器工具链(unluac/Prometheus-Deobfuscator/LuaHunt)也在持续进化。

---

## 7. 参考来源(2026-08 实测)

- 反编译/恢复工具:unluac(sourceforge.net/projects/unluac) · luadec(github.com/viruscamp/luadec) · ulua(github.com/bananabr/ulua) · Prometheus-Deobfuscator(github.com/0x251/Prometheus-Deobfuscator) · LuaHunt(github.com/hayden-droid/Dev) · FateZ-Decompiler(github.com/oxqnd/FateZ-Decompiler)
- 定制 VM 参考:ironbrew-2(github.com/Trollicus/ironbrew-2) · In-depth-guide-to-VM-obfuscation(github.com/VeryCuteLookingCat/In-depth-guide-to-VM-obfsucation) · Lua-Shield-5.3(github.com/sudo-dava25/Lua-Shield-5.3)
- 源码级混淆:hercules-obfuscator(github.com/zeusssz/hercules-obfuscator) · Prometheus(github.com/prometheus-lua/Prometheus) · LuaXen(github.com/bytexenon/LuaXen)
- 反 Frida/反调试/防 dump:DetectFrida(github.com/darvincisec/DetectFrida) · AntiDebugandMemoryDump(github.com/darvincisec/AntiDebugandMemoryDump) · name-cpu/AntiDebug · KPM bypass(medium.com/@omerqw23451)
- 平台机制:Frida docs(frida.re/docs) · Linux mseal(docs.kernel.org/userspace-api/mseal.html) · seccomp(source.android.com) · OWASP MASTG(mas.owasp.org/MASTG/0x05j)
- 商业:Luraph(lura.ph) · FairGuard(fair-guard.com) · PSU(psu.dev,已停更) · Moonsec(已泄露)
