#!/usr/bin/env bash
#
# 交叉编译 libaria2 及其 JNI 封装，产出 libaria2jni.so。
#
# 用法：ANDROID_NDK=<ndk 路径> [ARIA2_ENGINE=upstream|next] ./build.sh [abi ...]
# 默认编译 arm64-v8a。产物落在 out/<引擎>/<abi>/libaria2jni.so。
#
# 支持两个引擎，可并存、可随时切回：
#   next      aria2-next v2.5.5（CMake）—— 默认，当前发布用的就是它。
#             活跃维护的分支，保留了 libaria2 与 JSON-RPC 接口，所以
#             aria2jni.cpp 和 AriaNg 都不用改
#   upstream  aria2 1.37.0（autotools）—— 上游已停更（2023-01 最后一版），
#             保留作为保底路径：next 万一出问题，改一个环境变量就能编回去
#
# 依赖取舍差异：
#   upstream  只要 OpenSSL，zlib 用 NDK sysroot 自带的（-lz）
#   next      zlib 变成强制依赖且只经 pkg-config 查找，NDK 没提供 zlib.pc，
#             必须自己编。另外按需求开了 SFTP/Metalink/异步 DNS，
#             所以还要 libssh2 / expat / c-ares。sqlite3 不要（只用于
#             导入 Firefox3 cookie，Android 上没意义）。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="${API:-23}"                       # 与工程 minSdk 保持一致

# ---- 体积优化（现代做法）----------------------------------------------------
# SECFLAGS：把每个函数/数据放进独立 section，最终链接时 -Wl,--gc-sections 就能
#           逐函数丢弃未被引用的代码。对本项目收益最大——OpenSSL/aria2 静态库里
#           大量函数我们根本用不到，不分段的话链接器只能按 .o 整体保留。
# OPTFLAGS：依赖改用 clang 的体积优先码生成 -Oz。下载核心是 IO 密集，
#           OpenSSL 的性能热点是手写汇编（不受 C 优化级别影响），故安全。
SECFLAGS="-ffunction-sections -fdata-sections"
OPTFLAGS="${OPTFLAGS:--Oz}"
# 最终链接期的体积优化：
#   --gc-sections    丢弃未引用的 section（需上面的 SECFLAGS 才有效）
#   --exclude-libs,ALL 把所有静态库符号变 local：既不导出、又让 gc 能回收，
#                    同时 .dynsym 大幅变小。JNI 导出来自直接编译的 aria2jni.cpp
#                    （不在任何 .a 里），不受影响，仍正常导出
#   --icf=all        合并逐字节相同的函数（C++ 模板实例化会产生大量重复）
LINK_SIZE_FLAGS="-Wl,--gc-sections -Wl,--exclude-libs,ALL -Wl,--icf=all"

ARIA2_ENGINE="${ARIA2_ENGINE:-next}"
case "$ARIA2_ENGINE" in
  upstream)
    ARIA2_REPO="https://github.com/aria2/aria2"
    ARIA2_REF="${ARIA2_REF:-release-1.37.0}"
    ;;
  next)
    ARIA2_REPO="https://github.com/AnInsomniacy/aria2-next"
    ARIA2_REF="${ARIA2_REF:-v2.5.5}"
    ;;
  *)
    echo "未知引擎: $ARIA2_ENGINE（可选 upstream / next）" >&2; exit 1 ;;
esac

# 两个引擎的 prefix 里都有 lib/libaria2.a 和 include/aria2/aria2.h，
# 必须按引擎隔离，否则会拿 A 的库配 B 的头
WORK="${WORK:-$HERE/.work/$ARIA2_ENGINE}"
OUT="${OUT:-$HERE/out/$ARIA2_ENGINE}"

# 依赖版本与校验和取自 aria2-next 的 packaging/dependencies.env
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.6}"
OPENSSL_SHA256=deae7c80cba99c4b4f940ecadb3c3338b13cb77418409238e57d7f31f2a3b736
ZLIB_VERSION="${ZLIB_VERSION:-1.3.2}"
ZLIB_SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
EXPAT_VERSION="${EXPAT_VERSION:-2.8.1}"
EXPAT_TAG=R_2_8_1
EXPAT_SHA256=f5833dd2e1cd7739ec9182804a1a29c4f0cc7c2f26b633d3a2188b7766a88ecb
CARES_VERSION="${CARES_VERSION:-1.34.5}"
CARES_SHA256=7d935790e9af081c25c495fd13c2cfcda4792983418e96358ef6e7320ee06346
LIBSSH2_VERSION="${LIBSSH2_VERSION:-1.11.1}"
LIBSSH2_SHA256=8ddbd698403a2c3a9987df48f2940c6f6a9bddce28d37eb201938dd7755646f0

: "${ANDROID_NDK:?请设置 ANDROID_NDK 指向 NDK 根目录}"
TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64"
[ -d "$TOOLCHAIN" ] || { echo "找不到 NDK 工具链：$TOOLCHAIN" >&2; exit 1; }

ABIS=("$@")
[ ${#ABIS[@]} -eq 0 ] && ABIS=(arm64-v8a)

mkdir -p "$WORK" "$OUT"

echo "==> 引擎 $ARIA2_ENGINE ($ARIA2_REF)，ABI: ${ABIS[*]}"

# 下载并校验 SHA-256，再解包到 $WORK/<dir>
fetch_tarball() {
  local url="$1" sha="$2" dir="$3" archive
  archive="$WORK/$(basename "$url")"
  [ -d "$WORK/$dir" ] && return 0
  echo "==> 获取 $dir"
  [ -f "$archive" ] || curl -fsSL --retry 3 -o "$archive" "$url"
  echo "$sha  $archive" | sha256sum -c - >/dev/null \
    || { echo "校验和不匹配：$archive" >&2; exit 1; }
  tar xf "$archive" -C "$WORK"
}

fetch_sources() {
  if [ ! -d "$WORK/openssl-$OPENSSL_VERSION" ]; then
    fetch_tarball \
      "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" \
      "$OPENSSL_SHA256" "openssl-$OPENSSL_VERSION"
  fi

  if [ ! -d "$WORK/aria2" ]; then
    echo "==> 获取 $ARIA2_ENGINE $ARIA2_REF"
    git clone --depth 1 -b "$ARIA2_REF" "$ARIA2_REPO" "$WORK/aria2"
    # aria2-next 用 CMake，不需要 autoreconf；上游才需要
    [ "$ARIA2_ENGINE" = upstream ] && ( cd "$WORK/aria2" && autoreconf -i )
  fi

  # next 才需要的额外依赖
  if [ "$ARIA2_ENGINE" = next ]; then
    fetch_tarball \
      "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz" \
      "$ZLIB_SHA256" "zlib-$ZLIB_VERSION"
    fetch_tarball \
      "https://github.com/libexpat/libexpat/releases/download/$EXPAT_TAG/expat-$EXPAT_VERSION.tar.bz2" \
      "$EXPAT_SHA256" "expat-$EXPAT_VERSION"
    fetch_tarball \
      "https://github.com/c-ares/c-ares/releases/download/v$CARES_VERSION/c-ares-$CARES_VERSION.tar.gz" \
      "$CARES_SHA256" "c-ares-$CARES_VERSION"
    fetch_tarball \
      "https://github.com/libssh2/libssh2/releases/download/libssh2-$LIBSSH2_VERSION/libssh2-$LIBSSH2_VERSION.tar.bz2" \
      "$LIBSSH2_SHA256" "libssh2-$LIBSSH2_VERSION"
  fi
}

abi_triple() {
  case "$1" in
    arm64-v8a)   echo "aarch64-linux-android" ;;
    armeabi-v7a) echo "armv7a-linux-androideabi" ;;
    x86_64)      echo "x86_64-linux-android" ;;
    *) echo "不支持的 ABI: $1" >&2; exit 1 ;;
  esac
}

# --host 要用不带 API 后缀的三元组；armeabi-v7a 的 clang 前缀带 eabi
abi_host() {
  case "$1" in
    arm64-v8a)   echo "aarch64-linux-android" ;;
    armeabi-v7a) echo "arm-linux-androideabi" ;;
    x86_64)      echo "x86_64-linux-android" ;;
  esac
}

openssl_target() {
  case "$1" in
    arm64-v8a)   echo "android-arm64" ;;
    armeabi-v7a) echo "android-arm" ;;
    x86_64)      echo "android-x86_64" ;;
  esac
}

# 通用 autotools 依赖构建：$1=源码目录名 $2=产出的静态库名 其余=configure 参数
#
# 一律源外构建，不复制源码树。复制（cp -r）会丢时间戳，automake 会认为
# configure.ac 比 aclocal.m4 新，从而触发 maintainer-mode 去调 aclocal-<版本>
# 重新生成 —— runner 上没有那个精确版本的 aclocal，直接就挂了。
# 源外构建用的是 tar 解出来的原始时间戳，不会误触发。
build_autotools_dep() {
  local dir="$1" lib="$2"; shift 2
  [ -f "$prefix/lib/$lib" ] && return 0
  echo "==> [$abi] 编译 $dir"
  local b="$WORK/build-$dir-$abi"
  rm -rf "$b"; mkdir -p "$b"
  (
    cd "$b"
    # 这些静态库最终要链进 libaria2jni.so，必须是位置无关代码。
    # --disable-shared 会让 libtool 只编 .o 的非 PIC 版本，所以要显式给 -fPIC。
    CFLAGS="-fPIC $OPTFLAGS $SECFLAGS" CXXFLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
    "$WORK/$dir/configure" --host="$host" --prefix="$prefix" \
      --disable-shared --enable-static --with-pic "$@"
    make -j"$(nproc)"
    make install
  )
}

build_deps() {
  # ---------- OpenSSL（两个引擎都要） ----------
  if [ ! -f "$prefix/lib/libssl.a" ]; then
    echo "==> [$abi] 编译 OpenSSL $OPENSSL_VERSION"
    rm -rf "$WORK/build-openssl-$abi"
    cp -a "$WORK/openssl-$OPENSSL_VERSION" "$WORK/build-openssl-$abi"
    (
      cd "$WORK/build-openssl-$abi"
      # 静态库最终要链进 libaria2jni.so，所有目标文件都必须是位置无关代码
      ANDROID_NDK_ROOT="$ANDROID_NDK" ./Configure "$(openssl_target "$abi")" \
        -D__ANDROID_API__="$api" -fPIC $SECFLAGS \
        no-shared no-module no-tests no-ui-console \
        --prefix="$prefix" --openssldir="$prefix/ssl"
      make -j"$(nproc)" build_libs
      make install_dev
    )
  fi

  [ "$ARIA2_ENGINE" = next ] || return 0

  # ---------- zlib ----------
  # aria2-next 里 zlib 是唯一致命的依赖，且只经 pkg-config 查找。
  # NDK sysroot 有 libz.so 和 zlib.h 但没有 zlib.pc，所以必须自己编。
  if [ ! -f "$prefix/lib/libz.a" ]; then
    echo "==> [$abi] 编译 zlib $ZLIB_VERSION"
    rm -rf "$WORK/build-zlib-$abi"
    cp -a "$WORK/zlib-$ZLIB_VERSION" "$WORK/build-zlib-$abi"
    (
      cd "$WORK/build-zlib-$abi"
      # zlib 的 configure 不认 --host，靠环境变量指定交叉编译器
      CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
        ./configure --prefix="$prefix" --static
      make -j"$(nproc)"
      make install
    )
  fi

  # ---------- expat（Metalink） ----------
  build_autotools_dep "expat-$EXPAT_VERSION" libexpat.a \
    --without-docbook --without-examples --without-tests

  # ---------- c-ares（异步 DNS） ----------
  build_autotools_dep "c-ares-$CARES_VERSION" libcares.a

  # ---------- libssh2（SFTP） ----------
  build_autotools_dep "libssh2-$LIBSSH2_VERSION" libssh2.a \
    --with-crypto=openssl --with-libssl-prefix="$prefix" \
    --disable-examples-build
}

# ---------- aria2 1.37.0：autotools ----------
build_aria2_autotools() {
  [ -f "$prefix/lib/libaria2.a" ] && return 0
  echo "==> [$abi] 编译 aria2（autotools）"
  rm -rf "$WORK/build-aria2-$abi"
  mkdir -p "$WORK/build-aria2-$abi"
  (
    cd "$WORK/build-aria2-$abi"
    # 交叉编译时这几个 AC_FUNC_* 检查跑不了，直接给结论
    ac_cv_func_malloc_0_nonnull=yes \
    ac_cv_func_realloc_0_nonnull=yes \
    PKG_CONFIG_PATH="$prefix/lib/pkgconfig" \
    OPENSSL_CFLAGS="-I$prefix/include" \
    OPENSSL_LIBS="-L$prefix/lib -lssl -lcrypto" \
    CPPFLAGS="-I$prefix/include" \
    CFLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
    CXXFLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
    LDFLAGS="-L$prefix/lib" \
    "$WORK/aria2/configure" \
      --host="$host" \
      --prefix="$prefix" \
      --enable-libaria2 \
      --enable-static --disable-shared \
      --without-gnutls --with-openssl \
      --without-libxml2 --without-libexpat \
      --without-libcares --without-sqlite3 --without-libssh2 \
      --without-libgmp --without-libnettle --without-libgcrypt \
      --disable-nls --disable-werror
    make -j"$(nproc)"
    make install
  )
}

# ---------- aria2-next：CMake ----------
build_aria2_cmake() {
  [ -f "$prefix/lib/libaria2.a" ] && [ -f "$prefix/lib/libwslay.a" ] && return 0
  echo "==> [$abi] 编译 aria2-next（CMake）"
  local b="$WORK/build-aria2-$abi"
  rm -rf "$b"

  # PKG_CONFIG_LIBDIR 是"替换"搜索路径，PKG_CONFIG_PATH 是"追加"。
  # 必须用前者，否则 runner 上 apt 装的 x86_64 libssl-dev 会被找到并链进来。
  PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" \
  PKG_CONFIG_PATH= \
  PKG_CONFIG_SYSROOT_DIR= \
  cmake -S "$WORK/aria2" -B "$b" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$api" \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_C_FLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
    -DCMAKE_CXX_FLAGS="-fPIC $OPTFLAGS $SECFLAGS" \
    -DARIA2_ENABLE_LIBARIA2=ON \
    -DARIA2_ENABLE_SSL=ON \
    -DARIA2_ENABLE_BITTORRENT=ON \
    -DARIA2_ENABLE_WEBSOCKET=ON \
    -DARIA2_ENABLE_METALINK=ON \
    -DARIA2_ENABLE_WERROR=OFF \
    -DARIA2_WITH_OPENSSL=ON \
    -DARIA2_WITH_EXPAT=ON \
    -DARIA2_WITH_CARES=ON \
    -DARIA2_WITH_LIBSSH2=ON \
    -DARIA2_WITH_SQLITE3=OFF \
    -DARIA2_WITH_WINTLS=OFF \
    -DARIA2_STATIC_DEPENDENCIES=ON \
    2>&1 | tee "$WORK/cmake-configure-$abi.log"

  # 除 zlib 外所有依赖检查都是非致命的：pkg-config 路径配错会静默降级，
  # 编出一个能链接、符号齐全、但完全不能 HTTPS 的库。必须在这里拦住。
  local f
  for f in "libaria2=1" "WebSocket=1" "OpenSSL=1" "Metalink=1"; do
    grep -qE "Features:.*$f" "$WORK/cmake-configure-$abi.log" \
      || { echo "::error::[$abi] 特性未启用：$f（见 cmake-configure-$abi.log）" >&2; exit 1; }
  done
  echo "==> [$abi] 特性检查通过：$(grep -oE 'Features:.*' "$WORK/cmake-configure-$abi.log" | head -1)"

  # 测试目标是无条件构建的，只能指定 aria2_core，不能构建默认的 all
  cmake --build "$b" --target aria2_core -j"$(nproc)"

  # install() 里带了可执行文件目标，用 cmake --install 会失败，手动取产物。
  # 路径用 find 定位，避免上游重构后写死的路径失效。
  local a w
  a="$(find "$b" -name libaria2.a -print -quit)"
  w="$(find "$b" -name libwslay.a -print -quit)"
  [ -n "$a" ] || { echo "找不到 libaria2.a" >&2; exit 1; }
  [ -n "$w" ] || { echo "找不到 libwslay.a" >&2; exit 1; }
  install -d "$prefix/lib" "$prefix/include/aria2"
  install -m644 "$a" "$w" "$prefix/lib/"
  install -m644 "$WORK/aria2/src/includes/aria2/aria2.h" "$prefix/include/aria2/"
}

build_abi() {
  local abi="$1"
  local triple prefix host api
  triple="$(abi_triple "$abi")"
  host="$(abi_host "$abi")"
  prefix="$WORK/prefix/$abi"
  api="$API"

  # 32 位 ABI 上 fseeko/ftello 从 API 24 才有，而 libc++ 的 <fstream> 直接用了
  # 它们，API 23 编不过。这里为 32 位单独抬到 24。
  # 注意：这样编出的 32 位 so 在 API 23 设备上加载不了。工程当前只打包
  # arm64-v8a（见 app/build.gradle 的 abiFilters），所以实际不受影响。
  case "$abi" in
    armeabi-v7a|x86)
      if [ "$api" -lt 24 ]; then
        echo "==> [$abi] 32 位需要 API >= 24（fseeko/ftello），本 ABI 用 API 24 编译"
        api=24
      fi
      ;;
  esac

  mkdir -p "$prefix"

  export PATH="$TOOLCHAIN/bin:$PATH"
  export CC="$TOOLCHAIN/bin/${triple}${api}-clang"
  export CXX="$TOOLCHAIN/bin/${triple}${api}-clang++"
  export AR="$TOOLCHAIN/bin/llvm-ar"
  export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
  export STRIP="$TOOLCHAIN/bin/llvm-strip"

  build_deps

  local extra_libs=()
  if [ "$ARIA2_ENGINE" = next ]; then
    build_aria2_cmake
    # wslay 是独立静态库，静态库之间不会互相吸收，必须显式链上，
    # 否则 wslay_* 全部未定义（上游把 wslay 直接编进了 libaria2.a）
    extra_libs=(
      "$prefix/lib/libwslay.a"
      "$prefix/lib/libssh2.a"
      "$prefix/lib/libcares.a"
      "$prefix/lib/libexpat.a"
    )
  else
    build_aria2_autotools
  fi

  # ---------- JNI 封装 ----------
  echo "==> [$abi] 链接 libaria2jni.so"
  mkdir -p "$OUT/$abi"
  local zlib_link=(-lz)
  # next 用自己编的静态 zlib；upstream 继续用 NDK 的动态 libz
  [ "$ARIA2_ENGINE" = next ] && zlib_link=("$prefix/lib/libz.a")

  # C++ 标准跟着引擎走：aria2-next 内核按 C++17 编，保持一致；
  # 上游 1.37.0 沿用原来的 c++14（C++17 移除了动态异常规范等特性，
  # 贸然抬标准可能编不过，而这条路径的价值就在于"随时能退回去"）
  local cxxstd=-std=c++14
  [ "$ARIA2_ENGINE" = next ] && cxxstd=-std=c++17

  # -Wl,--no-undefined 同时是 API 级别的守卫：NDK 链的是 API $api 的 stub 库，
  # 任何更高 API 才有的符号会在链接期失败，而不是在用户手机上崩溃
  "$CXX" -shared -fPIC $OPTFLAGS $SECFLAGS "$cxxstd" \
    -I"$prefix/include" \
    "$HERE/aria2jni.cpp" \
    "$prefix/lib/libaria2.a" \
    "${extra_libs[@]}" \
    "$prefix/lib/libssl.a" "$prefix/lib/libcrypto.a" \
    "${zlib_link[@]}" \
    -llog -lm -ldl -static-libstdc++ \
    -Wl,--no-undefined \
    $LINK_SIZE_FLAGS \
    -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 \
    -o "$OUT/$abi/libaria2jni.so"
  "$STRIP" --strip-unneeded "$OUT/$abi/libaria2jni.so"
  ls -la "$OUT/$abi/libaria2jni.so"
}

fetch_sources
for abi in "${ABIS[@]}"; do
  build_abi "$abi"
done
echo "==> 完成（引擎 $ARIA2_ENGINE），产物在 $OUT"
