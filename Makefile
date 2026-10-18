ARCHS = arm64 arm64e
# Match the established SDK's runtime stubs. Package/runtime guards require 17+.
TARGET = iphone:clang:15.6:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = MobileTimer

include $(THEOS)/makefiles/common.mk
TWEAK_NAME = FiveMoreMinutes
FiveMoreMinutes_FILES = Tweak.mm
FiveMoreMinutes_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
FiveMoreMinutes_CCFLAGS = -std=c++17
FiveMoreMinutes_FRAMEWORKS = UIKit Foundation Accessibility
FiveMoreMinutes_LIBRARIES = substrate
include $(THEOS_MAKE_PATH)/tweak.mk
