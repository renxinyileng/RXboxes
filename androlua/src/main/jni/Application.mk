# ABI 与最低平台由 AGP 通过 abiFilters / minSdk 传入，这里只设公共编译选项
APP_STL := c++_static
APP_CFLAGS += -Wno-implicit-function-declaration -Wno-int-conversion \
              -Wno-incompatible-pointer-types -Wno-deprecated-non-prototype \
              -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast
APP_ALLOW_MISSING_DEPS := true
