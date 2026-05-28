TARGET = iphone:clang:12.4:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SilentPillHUD

SilentPillHUD_FILES = Tweak.xm
SilentPillHUD_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated
SilentPillHUD_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
