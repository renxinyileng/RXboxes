#!/usr/bin/env bash
#
# 交叉编译 libaria2 及其 JNI 封装，产出 libaria2jni.so。
#
# 用法：ANDROID_NDK=<ndk 路径> ./build.sh [abi ...]
# 默认编译 arm64-v8a。产物落在 out/<abi>/libaria2jni.so。
#
# 依赖取舍：
#   OpenSSL  必须，HTTPS/BT 都要用
#   zlib     用 NDK sysroot 自带的
#   libxml2 / libexpat  不带 —— 只影响 Metalink 与 XML-RPC，
#           AriaNg 走的是 JSON-RPC，不受影响
#   c-ares / sqlite3 / libssh2  不带
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-$HERE/.work}"
OUT="${OUT:-$HERE/out}"
API="${API:-23}"                       # 与工程 minSdk 保持一致
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.4}"
ARIA2_REF="${ARIA2_REF:-release-1.37.0}"

: "${ANDROID_NDK:?请设置 ANDROID_NDK 指向 NDK 根目录}"
TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64"
[ -d "$TOOLCHAIN" ] || { echo "找不到 NDK 工具链：$TOOLCHAIN" >&2; exit 1; }

ABIS=("$@")
[ ${#ABIS[@]} -eq 0 ] && ABIS=(arm64-v8a)

mkdir -p "$WORK" "$OUT"

fetch_sources() {
  if [ ! -d "$WORK/openssl" ]; then
    echo "==> 获取 OpenSSL $OPENSSL_VERSION"
    git clone --depth 1 -b "openssl-$OPENSSL_VERSION" \
      https://github.com/openssl/openssl "$WORK/openssl"
  fi
  if [ ! -d "$WORK/aria2" ]; then
    echo "==> 获取 aria2 $ARIA2_REF"
    git clone --depth 1 -b "$ARIA2_REF" https://github.com/aria2/aria2 "$WORK/aria2"
    ( cd "$WORK/aria2" && autoreconf -i )
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

# aria2 的 --host 要用不带 API 后缀的三元组；armeabi-v7a 的 clang 前缀带 eabi
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

build_abi() {
  local abi="$1"
  local triple prefix host
  triple="$(abi_triple "$abi")"
  host="$(abi_host "$abi")"
  prefix="$WORK/prefix/$abi"
  mkdir -p "$prefix"

  export PATH="$TOOLCHAIN/bin:$PATH"
  export CC="$TOOLCHAIN/bin/${triple}${API}-clang"
  export CXX="$TOOLCHAIN/bin/${triple}${API}-clang++"
  export AR="$TOOLCHAIN/bin/llvm-ar"
  export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
  export STRIP="$TOOLCHAIN/bin/llvm-strip"

  # ---------- OpenSSL ----------
  if [ ! -f "$prefix/lib/libssl.a" ]; then
    echo "==> [$abi] 编译 OpenSSL"
    rm -rf "$WORK/build-openssl-$abi"
    cp -r "$WORK/openssl" "$WORK/build-openssl-$abi"
    (
      cd "$WORK/build-openssl-$abi"
      # 静态库最终要链进 libaria2jni.so，所有目标文件都必须是位置无关代码
      ANDROID_NDK_ROOT="$ANDROID_NDK" ./Configure "$(openssl_target "$abi")" \
        -D__ANDROID_API__="$API" -fPIC no-shared no-tests no-ui-console \
        --prefix="$prefix" --openssldir="$prefix/ssl"
      make -j"$(nproc)" build_libs
      make install_dev
    )
  fi

  # ---------- aria2（只要静态库 libaria2.a） ----------
  if [ ! -f "$prefix/lib/libaria2.a" ]; then
    echo "==> [$abi] 编译 aria2"
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
      CFLAGS="-fPIC -O2" \
      CXXFLAGS="-fPIC -O2" \
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
  fi

  # ---------- JNI 封装 ----------
  echo "==> [$abi] 编译 libaria2jni.so"
  mkdir -p "$OUT/$abi"
  "$CXX" -shared -fPIC -O2 -std=c++14 \
    -I"$prefix/include" \
    "$HERE/aria2jni.cpp" \
    "$prefix/lib/libaria2.a" \
    "$prefix/lib/libssl.a" "$prefix/lib/libcrypto.a" \
    -lz -llog -static-libstdc++ \
    -Wl,--no-undefined \
    -o "$OUT/$abi/libaria2jni.so"
  "$STRIP" --strip-unneeded "$OUT/$abi/libaria2jni.so"
  ls -la "$OUT/$abi/libaria2jni.so"
}

fetch_sources
for abi in "${ABIS[@]}"; do
  build_abi "$abi"
done
echo "==> 完成，产物在 $OUT"
