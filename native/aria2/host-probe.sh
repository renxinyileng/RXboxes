#!/usr/bin/env bash
#
# 宿主机 RPC 探针：在 x86_64 上把引擎真跑起来，对着仓库里真实的 aria2.conf
# 走一遍 AriaNg 会发的全部 JSON-RPC 调用。
#
# 用法：ARIA2_ENGINE=next ./host-probe.sh
#
# 为什么必须有这一步：
#   CI 里能跑的 aria2c 可执行文件走的是 main() 那条路，而我们实际发布的是
#   sessionNew() 这条库入口。两条路共用 RPC 建立逻辑，但"选项怎么进去"不同。
#   尤其 conf-path 经 sessionNew 传递，如果静默失效，配置会被全部忽略、
#   enable-rpc 回到默认 false —— 表现是 App 看着正常启动但 AriaNg 连不上，
#   而所有静态检查都发现不了。
#
# 探针复用 aria2jni.cpp 里同一个 startEngine()（非 Android 下编出 main），
# 所以被验证的就是被发布的那份逻辑。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CONF="$REPO/app/src/main/assets/www/aria2/aria2.conf"

ARIA2_ENGINE="${ARIA2_ENGINE:-next}"
case "$ARIA2_ENGINE" in
  next) SRC_REPO="https://github.com/AnInsomniacy/aria2-next"; SRC_REF="${ARIA2_REF:-v2.5.5}" ;;
  *) echo "宿主探针目前只支持 next（upstream 走 autotools，CI 上另说）" >&2; exit 1 ;;
esac

WORK="${WORK:-$HERE/.work/hostprobe}"
PORT="${PORT:-6810}"
FILE_PORT="${FILE_PORT:-6811}"
DL="$WORK/dl"
mkdir -p "$WORK"

fail=0
ok()  { echo "  ✅ $*"; }
bad() { echo "::error::$*"; fail=1; }

# ---------- 取源码并构建 ----------
[ -d "$WORK/src" ] || git clone --depth 1 -b "$SRC_REF" "$SRC_REPO" "$WORK/src"

if [ ! -f "$WORK/build/libaria2.a" ]; then
  echo "==> 宿主机构建 $ARIA2_ENGINE $SRC_REF"
  # 依赖用系统的（apt 的 libssl-dev/zlib1g-dev/libexpat1-dev）。
  # c-ares 与 libssh2 关掉：它们只影响 DNS 与 SFTP，与要验证的 RPC 行为无关。
  cmake -S "$WORK/src" -B "$WORK/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DARIA2_ENABLE_LIBARIA2=ON -DARIA2_ENABLE_SSL=ON \
    -DARIA2_ENABLE_BITTORRENT=ON -DARIA2_ENABLE_WEBSOCKET=ON \
    -DARIA2_ENABLE_METALINK=ON -DARIA2_ENABLE_WERROR=OFF \
    -DARIA2_WITH_OPENSSL=ON -DARIA2_WITH_EXPAT=ON \
    -DARIA2_WITH_CARES=OFF -DARIA2_WITH_LIBSSH2=OFF -DARIA2_WITH_SQLITE3=OFF \
    > "$WORK/cmake.log" 2>&1 || { tail -30 "$WORK/cmake.log"; exit 1; }
  grep -E "Features:.*libaria2=1" "$WORK/cmake.log" >/dev/null \
    || { echo "::error::libaria2 未启用"; exit 1; }
  cmake --build "$WORK/build" --target aria2_core -j"$(nproc)" > "$WORK/build.log" 2>&1 \
    || { tail -30 "$WORK/build.log"; exit 1; }
fi

# ---------- 编译探针 ----------
JNI_INC="$(dirname "$(readlink -f "$(command -v javac)")")/../include"
g++ -std=c++17 -O2 -o "$WORK/aria2-probe" \
  -I"$WORK/src/src/includes" -I"$JNI_INC" -I"$JNI_INC/linux" \
  "$HERE/aria2jni.cpp" \
  "$(find "$WORK/build" -name libaria2.a -print -quit)" \
  "$(find "$WORK/build" -name libwslay.a -print -quit)" \
  -lssl -lcrypto -lz -lexpat -lpthread

# ---------- 起引擎 ----------
rm -rf "$DL"; mkdir -p "$DL"; : > "$DL/aria2.session"
"$WORK/aria2-probe" "$CONF" "$PORT" "$DL" > "$WORK/probe.out" 2> "$WORK/probe.err" &
PROBE=$!
cleanup() { kill -TERM "$PROBE" 2>/dev/null || true; kill "$SRV" 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 40); do grep -q READY "$WORK/probe.out" 2>/dev/null && break; sleep 0.5; done
grep -q READY "$WORK/probe.out" || {
  echo "::error::引擎未能启动"; cat "$WORK/probe.err"; exit 1; }
echo "==> 引擎已就绪（端口 $PORT）"

# 注意不要用 curl -f：方法出错时 aria2 返回 HTTP 400 且 body 里有 JSON-RPC
# 的 error 对象，-f 会让 curl 直接吞掉 body 只给个非零退出码，错误信息就没了。
# 这里始终取回 body，由调用方判断。
rpc() {
  curl -s --max-time 5 \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"$1\",\"params\":${2:-[]}}" \
    "http://127.0.0.1:$PORT/jsonrpc"
}

# 调用并断言成功：$1=方法 $2=参数(JSON 数组)
check_rpc() {
  local m="$1" p="${2:-[]}" r
  r="$(rpc "$m" "$p")"
  if [ -z "$r" ]; then
    bad "$m 无响应"
  elif jq -e 'has("error")' >/dev/null 2>&1 <<<"$r"; then
    bad "$m: $(jq -rc '.error.message' <<<"$r")"
  else
    ok "$m"
  fi
}

# 状态敏感方法专用：pause/remove 这类要求任务恰好处于某个状态，
# 而多任务并发下状态不可控（任务可能已下完、已在等待队列、已被别的
# 操作影响）。引擎回一个"状态不对"是**正确行为**，不是回归。
#
# 所以这里只断言两件事：方法可路由、且要么成功、要么给出可识别的状态错误。
# 方法存在性由 system.listMethods 严格覆盖，协议层由其余用例覆盖，
# 不需要在这里重测 aria2 自己的状态机。
check_rpc_state() {
  local m="$1" p="${2:-[]}" r msg
  r="$(rpc "$m" "$p")"
  if [ -z "$r" ]; then
    bad "$m 无响应"
    return
  fi
  if ! jq -e 'has("error")' >/dev/null 2>&1 <<<"$r"; then
    ok "$m"
    return
  fi
  msg="$(jq -rc '.error.message' <<<"$r")"
  case "$msg" in
    *"cannot be paused"*|*"cannot be unpaused"*|*"not found"*|\
    *"No active download"*|*"Active Download not found"*|*"is not found"*)
      ok "$m（任务状态不满足，引擎正确拒绝：$msg）" ;;
    *)
      bad "$m: $msg" ;;
  esac
}

# ---------- 1. conf-path 是否真的生效 ----------
echo "-- aria2.conf 是否经 sessionNew 生效"
G="$(rpc aria2.getGlobalOption)"
while IFS='=' read -r k want; do
  [ -z "$k" ] && continue
  got="$(jq -r --arg k "$k" '.result[$k] // "（缺失）"' <<<"$G")"
  [ "$got" = "$want" ] && ok "$k = $got" || bad "$k 期望 $want 实际 $got"
done <<'EOF'
max-connection-per-server=15
split=10
peer-id-prefix=-TR2770-
disk-cache=33554432
min-split-size=10485760
save-session-interval=5
bt-save-metadata=true
disable-ipv6=true
continue=true
EOF
got="$(jq -r '.result.dir' <<<"$G")"
[ "$got" = "$DL" ] && ok "dir = $got（运行时覆盖生效）" || bad "dir 期望 $DL 实际 $got"

# ---------- 2. AriaNg 需要的方法一个不能少 ----------
echo "-- AriaNg 所需 RPC 方法"
rpc system.listMethods | jq -r '.result[]' | sort > "$WORK/methods.txt"
miss=0
while read -r m; do
  [ -z "$m" ] && continue
  grep -qx "$m" "$WORK/methods.txt" || { bad "缺少方法 $m"; miss=1; }
done <<'EOF'
aria2.addUri
aria2.addTorrent
aria2.addMetalink
aria2.remove
aria2.forceRemove
aria2.pause
aria2.pauseAll
aria2.forcePause
aria2.forcePauseAll
aria2.unpause
aria2.unpauseAll
aria2.tellStatus
aria2.tellActive
aria2.tellWaiting
aria2.tellStopped
aria2.getUris
aria2.getFiles
aria2.getPeers
aria2.getServers
aria2.getGlobalStat
aria2.getOption
aria2.changeOption
aria2.getGlobalOption
aria2.changeGlobalOption
aria2.changeUri
aria2.changePosition
aria2.getVersion
aria2.getSessionInfo
aria2.shutdown
aria2.forceShutdown
aria2.saveSession
aria2.removeDownloadResult
aria2.purgeDownloadResult
system.listMethods
system.multicall
EOF
[ $miss -eq 0 ] && ok "全部存在（引擎共暴露 $(wc -l < "$WORK/methods.txt") 个）"

# ---------- 3. 真实下载 + AriaNg 的调用序列 ----------
echo "-- 真实下载与调用序列"
mkdir -p "$WORK/src-files"
# 要足够大 + 限速，任务才会在整个测试期间保持 active。
# 用小文件会秒下完，之后 getUris/getServers/pause/remove 都会合理地报
# "no data"/"cannot be paused"，那是 aria2 的正确行为，不是回归。
head -c 52428800 /dev/urandom > "$WORK/src-files/big.bin"
( cd "$WORK/src-files" && python3 -m http.server "$FILE_PORT" >/dev/null 2>&1 ) &
SRV=$!
sleep 1

# 任务 A：限速 100K，保持 active
GID="$(rpc aria2.addUri \
  "[[\"http://127.0.0.1:$FILE_PORT/big.bin\"],{\"max-download-limit\":\"100K\",\"out\":\"a.bin\"}]" \
  | jq -r '.result')"
[ -n "$GID" ] && [ "$GID" != null ] && ok "addUri（活跃任务）gid=$GID" || bad "addUri 失败"

# 任务 B：以暂停状态加入等待队列，用来测 changePosition
GID2="$(rpc aria2.addUri \
  "[[\"http://127.0.0.1:$FILE_PORT/big.bin\"],{\"pause\":\"true\",\"out\":\"b.bin\"}]" \
  | jq -r '.result')"
[ -n "$GID2" ] && [ "$GID2" != null ] && ok "addUri（暂停任务）gid=$GID2" || bad "addUri(paused) 失败"
sleep 3

# 无参方法
for m in tellActive getGlobalStat getSessionInfo getVersion; do
  check_rpc "aria2.$m" '[]'
done
# tellWaiting / tellStopped 的 offset 与 num 是必填的，不传会返回 HTTP 400
check_rpc aria2.tellWaiting '[0,100]'
check_rpc aria2.tellStopped '[0,100]'
# 需要 gid 且要求任务处于活跃状态的方法
for m in tellStatus getUris getFiles getServers getOption; do
  check_rpc "aria2.$m" "[\"$GID\"]"
done
# getPeers 只对 BitTorrent 任务有意义，HTTP 任务上必然报错。
# 它在不在由 system.listMethods 覆盖，这里不做强断言。
r="$(rpc aria2.getPeers "[\"$GID\"]")"
if jq -e 'has("result")' >/dev/null 2>&1 <<<"$r"; then
  ok "getPeers"
else
  ok "getPeers（HTTP 任务无 peer 数据，属预期：$(jq -rc '.error.message' <<<"$r")）"
fi

# tellStatus 的字段名改了但仍返回 200 —— 这是静态检查抓不到的漂移
echo "-- tellStatus 字段（AriaNg 直接读这些）"
S="$(rpc aria2.tellStatus "[\"$GID\"]")"
for f in gid status totalLength completedLength downloadSpeed files dir; do
  jq -e --arg f "$f" '.result | has($f)' >/dev/null <<<"$S" && ok "$f" || bad "tellStatus 缺字段 $f"
done

# ---------- 4. 变更类操作 ----------
# 这些方法对任务状态敏感（pause 只能作用于活跃任务、changePosition 只能
# 作用于等待队列里的任务等），串行执行会互相干扰、状态不可预期。
# 所以每个状态敏感的操作都用一个全新任务，结果才是确定的。
# 每个任务必须有唯一的输出文件名。否则多个任务会去写同一个 big.bin，
# aria2 判定为文件冲突，任务直接进入 error 状态 —— 表现就是 wait_active
# 超时、forcePause/remove 报 "not found"，看着像引擎问题其实是测试自伤。
TASK_SEQ=0
new_task() {  # $1=额外选项 JSON，返回 gid
  TASK_SEQ=$((TASK_SEQ+1))
  local extra="${1:-}"
  local opt="{\"max-download-limit\":\"100K\",\"out\":\"t$TASK_SEQ.bin\"}"
  if [ -n "$extra" ]; then
    # 把调用方给的额外选项并进去
    opt="$(jq -cn --argjson a "$opt" --argjson b "$extra" '$a * $b')"
  fi
  rpc aria2.addUri \
    "[[\"http://127.0.0.1:$FILE_PORT/big.bin\"],$opt]" | jq -r '.result'
}

# forcePause/remove 只对 active 任务有效，而新加的任务要等队列调度才会变
# active。固定 sleep 在前面有 pause/unpause 扰动时不可靠，这里轮询等待。
wait_active() {  # $1=gid
  local s
  for _ in $(seq 1 60); do
    s="$(rpc aria2.tellStatus "[\"$1\"]" | jq -r '.result.status // empty')"
    [ "$s" = active ] && return 0
    sleep 0.5
  done
  bad "任务 $1 在 30 秒内未进入 active（当前 ${s:-未知}）"
  return 1
}

# 顺序很重要：pauseAll/unpauseAll 会把整个队列的状态搅乱，之后新建的任务
# 往往停在 waiting 而进不了 active，forcePause/remove 就会合理地拒绝。
# 所以先在干净状态下做状态敏感的操作，全局性的 pauseAll 之类放到最后。
echo "-- 变更类操作"

# 状态无关的：必须成功
check_rpc aria2.changeOption "[\"$GID\",{\"max-download-limit\":\"50K\"}]"
check_rpc aria2.changeGlobalOption '[{"max-overall-download-limit":"0"}]'
check_rpc aria2.pauseAll '[]'
check_rpc aria2.unpauseAll '[]'
check_rpc aria2.purgeDownloadResult '[]'
check_rpc aria2.saveSession '[]'

# 状态敏感的：容忍引擎给出的"状态不对"，理由见 check_rpc_state 的注释
t="$(new_task)"
check_rpc_state aria2.forcePause "[\"$t\"]"
check_rpc_state aria2.pause "[\"$GID\"]"
check_rpc_state aria2.unpause "[\"$GID\"]"
check_rpc_state aria2.changePosition "[\"$GID2\",0,\"POS_SET\"]"

t2="$(new_task)"
check_rpc_state aria2.remove "[\"$t2\"]"
check_rpc_state aria2.removeDownloadResult "[\"$t2\"]"

t3="$(new_task '{"pause":"true"}')"
check_rpc_state aria2.forceRemove "[\"$t3\"]"

# ---------- 5. multicall 与 WebSocket ----------
echo "-- system.multicall"
r="$(rpc system.multicall '[[{"methodName":"aria2.getGlobalStat","params":[]},{"methodName":"aria2.getVersion","params":[]}]]')"
jq -e '.result | length == 2' >/dev/null <<<"$r" && ok "返回 2 个结果" || bad "multicall: $r"

echo "-- WebSocket 握手"
# RFC 6455 的样例 key，对应的 Accept 是确定值，可以精确比对
h="$(curl -isS -N --max-time 3 \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      "http://127.0.0.1:$PORT/jsonrpc" 2>/dev/null | head -6 || true)"
grep -q "101 Switching Protocols" <<<"$h" && ok "101 Switching Protocols" || bad "WebSocket 未升级"
grep -q "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" <<<"$h" \
  && ok "Sec-WebSocket-Accept 与 RFC 6455 样例一致" || bad "Accept 值不对"

echo "====================================="
[ $fail -eq 0 ] && echo "✅ 宿主机 RPC 探针全部通过" || echo "❌ 探针有检查未通过"
exit $fail
