#!/usr/bin/env bash
#
# 校验编出来的 libaria2jni.so。两个引擎共用，upstream 产出基线，next 与之比对。
#
# 用法：./verify.sh <libaria2jni.so> [引擎名]
#       ./verify.sh --emit-baseline <libaria2jni.so>   重新生成 RPC 方法基线
#
# 这些检查全部在宿主机上对着 aarch64 的 .so 跑，不需要真机或模拟器。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BASELINE="$HERE/baseline/rpc-methods-upstream.txt"
CONF="$REPO/app/src/main/assets/www/aria2/aria2.conf"

if [ "${1:-}" = "--emit-baseline" ]; then
  strings -a "$2" | grep -E '^(aria2|system)\.[a-zA-Z]+$' | sort -u > "$BASELINE"
  echo "基线已更新：$BASELINE（$(wc -l < "$BASELINE") 个方法）"
  exit 0
fi

SO="${1:?用法: verify.sh <libaria2jni.so> [引擎名]}"
ENGINE="${2:-unknown}"
[ -f "$SO" ] || { echo "::error::找不到 $SO"; exit 1; }

fail=0
note() { echo "  $*"; }
bad()  { echo "::error::$*"; fail=1; }

echo "===== 校验 $SO （引擎 $ENGINE）====="

# ---- 1. JNI 入口 ----
# 注意：不要写成 nm ... | grep -q，grep -q 命中即退出会让 nm 收到 SIGPIPE，
# 在 set -o pipefail 下整条管道返回非零，导致本来正常的符号被误报为缺失
echo "-- JNI 导出符号"
dynsyms="$(mktemp)"
nm -D --defined-only "$SO" > "$dynsyms"
for sym in nativeStart nativeStop nativeIsRunning; do
  if grep -q "Java_com_rxteam_aria2_Aria2_$sym" "$dynsyms"; then
    note "✅ $sym"
  else
    bad "缺少导出 Java_com_rxteam_aria2_Aria2_$sym"
  fi
done
rm -f "$dynsyms"

# ---- 2. 动态依赖 ----
# next 会把 zlib 静态链进去，所以 libz.so 消失是正常的；
# 关键是不能出现宿主机的库（pkg-config 路径配错的典型症状）
echo "-- NEEDED 依赖"
allowed="libz.so liblog.so libm.so libdl.so libc.so libc++_shared.so"
while read -r lib; do
  if grep -qw -- "$lib" <<<"$allowed"; then
    note "✅ $lib"
  else
    bad "出现意料之外的依赖：$lib（可能链到了宿主机的库）"
  fi
done < <(readelf -d "$SO" | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/')

# ---- 3. RPC 方法面 ----
# AriaNg 用的是整套 aria2 JSON-RPC，少任何一个方法都会让前端功能缺失
echo "-- RPC 方法集合"
methods="$(mktemp)"
strings -a "$SO" | grep -E '^(aria2|system)\.[a-zA-Z]+$' | sort -u > "$methods"
note "本次 $(wc -l < "$methods") 个，基线 $(wc -l < "$BASELINE") 个"
missing="$(comm -23 "$BASELINE" "$methods")"
added="$(comm -13 "$BASELINE" "$methods")"
if [ -n "$missing" ]; then
  bad "相对基线缺失了方法：$(echo "$missing" | tr '\n' ' ')"
else
  note "✅ 基线里的方法一个不少"
fi
[ -n "$added" ] && note "ℹ️  新增方法：$(echo "$added" | tr '\n' ' ')"

# ---- 4. 配置项名 ----
# 选项名不存在会让 sessionNew 直接失败。注意 strings 对 <=4 字符的名字
# 有误报（编译器会把短字面量并进长字符串），那些交给宿主机 RPC 探针覆盖。
echo "-- aria2.conf 选项名"
opts="$(mktemp)"
strings -a -n 2 "$SO" | sort -u > "$opts"
short=0; okn=0
while read -r k; do
  [ -z "$k" ] && continue
  if [ "${#k}" -le 4 ]; then short=$((short+1)); continue; fi
  if grep -qx -- "$k" "$opts"; then okn=$((okn+1)); else bad "配置项在 so 中不存在：$k"; fi
done < <(grep -vE '^\s*(#|;|$)' "$CONF" | sed 's/=.*//' | tr -d ' ' | sort -u)
note "✅ $okn 个选项名存在（另有 $short 个 <=4 字符的跳过，由 RPC 探针覆盖）"

# ---- 5. WebSocket ----
# AriaNg 的实时推送走 WebSocket，RFC 6455 的魔数在就说明编进来了
echo "-- WebSocket"
if grep -qa "Sec-WebSocket-Accept" "$SO" && grep -qa "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" "$SO"; then
  note "✅ 握手头与 RFC 6455 GUID 均在"
else
  bad "WebSocket 支持缺失"
fi

# ---- 6. TLS ----
# 依赖检查除 zlib 外都是非致命的，OpenSSL 没链上会静默降级成不能 HTTPS
echo "-- TLS"
if ver="$(strings -a "$SO" | grep -oE 'OpenSSL 3\.[0-9.]+[a-z]*' | head -1)" && [ -n "$ver" ]; then
  note "✅ $ver"
else
  bad "没找到 OpenSSL 版本串，TLS 很可能没编进来"
fi

# ---- 7. 引擎身份与体积 ----
echo "-- 引擎与体积"
note "版本串: $(strings -a "$SO" | grep -oE 'aria2/[0-9]+\.[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ')"
size=$(stat -c%s "$SO")
note "体积: $size 字节"
# 基线 10,656,864。突然瘦一大截通常意味着某个功能被静默关掉了
if [ "$size" -lt 6000000 ]; then
  note "⚠️  明显小于基线 10.6MB，请确认没有功能被静默禁用"
fi

rm -f "$methods" "$opts"
echo "====================================="
[ $fail -eq 0 ] && echo "✅ 全部通过" || echo "❌ 有检查未通过"
exit $fail
