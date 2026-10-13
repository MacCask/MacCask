# MacCask 构建与打包
APP_NAME    := MacCask
# VERSION 是唯一版本来源；命令行 VERSION=... 不覆盖版本文件。
override VERSION := $(shell bash Scripts/Utils/read-version.sh VERSION)
ifeq ($(strip $(VERSION)),)
$(error 无法读取合法的 VERSION 文件)
endif
ARCH        ?= $(shell uname -m)
ifneq ($(words $(ARCH)),1)
$(error ARCH 必须是单一架构：x86_64 或 arm64)
endif
ifeq ($(filter $(ARCH),x86_64 arm64),)
$(error ARCH 只支持 x86_64 或 arm64)
endif
BUILD       ?= $(VERSION)
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
BIN_PATH     = $(shell swift build -c release --arch $(ARCH) --show-bin-path)
ICON_DIR    := $(BUILD_DIR)/icon-composer
# 自动探测系统中第一个可用的代码签名身份（自签证书），可通过 make SIGN_IDENTITY="xxx" 覆盖
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' 'NR==1 && NF>1 {print $$2}')

.PHONY: all build icon app release run install clean

all: app

# Release 编译
build: icon
	swift build -c release --arch $(ARCH)

# 生成应用图标
icon:
	bash Scripts/build-icon.sh

# 组装 .app 并签名
app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	cp "$(BIN_PATH)/$(APP_NAME)" $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD)/' Resources/Info.plist > $(APP_BUNDLE)/Contents/Info.plist
	cp $(ICON_DIR)/AppIcon.icns $(ICON_DIR)/Assets.car $(APP_BUNDLE)/Contents/Resources/
	cp -R "$(BIN_PATH)/MacCask_MacCask.bundle" $(APP_BUNDLE)/Contents/Resources/
	cp -R Resources/Localizations/*.lproj $(APP_BUNDLE)/Contents/Resources/
	/usr/libexec/PlistBuddy -c "Merge $(ICON_DIR)/partial.plist" $(APP_BUNDLE)/Contents/Info.plist
	python3 Scripts/Release/configure-updater.py "$(APP_BUNDLE)" "$(ARCH)"
	bash Scripts/Release/embed-sparkle.sh "$(APP_BUNDLE)" "$(if $(SIGN_IDENTITY),$(SIGN_IDENTITY),-)"
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		echo "使用证书签名: $(SIGN_IDENTITY)"; \
		codesign --force --timestamp=none --sign "$(SIGN_IDENTITY)" $(APP_BUNDLE); \
	else \
		echo "未找到代码签名证书，使用 ad-hoc 签名"; \
		codesign --force --sign - $(APP_BUNDLE); \
	fi
	@echo "打包完成: $(APP_BUNDLE)"

# 生成当前架构的可安装 DMG，版本与应用包均来自 VERSION。
release: app
	bash Scripts/Release/package-app.sh "$(APP_BUNDLE)" "$(ARCH)" "$(BUILD_DIR)/releases"

# 打包并运行
run: app
	open $(APP_BUNDLE)

# 安装到 /Applications
install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/
	@echo "已安装到 /Applications/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR) .build
