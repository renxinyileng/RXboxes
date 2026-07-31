LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_C_INCLUDES += $(LOCAL_PATH)/../lua
LOCAL_MODULE     := regex
LOCAL_SRC_FILES  := lposix.c common.c
LOCAL_LDLIBS += -llog -ldl
LOCAL_SHARED_LIBRARIES := luajava

include $(BUILD_SHARED_LIBRARY)
