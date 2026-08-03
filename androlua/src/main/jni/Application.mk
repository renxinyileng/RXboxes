# ABI 与最低平台由 AGP 通过 abiFilters / minSdk 传入，这里只设公共编译选项
APP_STL := c++_static
APP_CFLAGS += -Wno-implicit-function-declaration -Wno-int-conversion \
              -Wno-incompatible-pointer-types -Wno-deprecated-non-prototype \
              -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast
APP_ALLOW_MISSING_DEPS := true

# Android 15 起设备可能使用 16KB 内存页，未按 16KB 对齐的 so 会直接加载失败
# （整个 App 起不来，不只是某个功能）。NDK r28+ 默认就是 16KB，本工程用的
# r27 还不是，所以显式指定。
APP_LDFLAGS += -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
