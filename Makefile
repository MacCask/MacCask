# MacCask 构建与打包
APP_NAME    := MacCask
VERSION     ?= 1.0.0
BUILD       ?= $(shell date +%Y%m%d%H%M)
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
BIN_PATH     = $(shell swift build -c release --show-bin-path)
ICON_DIR    := $(BUILD_DIR)/icon-composer
# 自动探测系统中第一个可用的代码签名身份（自签证书），可通过 make SIGN_IDENTITY="xxx" 覆盖
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' 'NR==1 && NF>1 {print $$2}')

.PHONY: all build icon app run install clean

all: app

# Release 编译
build: icon
	swift build -c release

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
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		echo "使用证书签名: $(SIGN_IDENTITY)"; \
		codesign --force --deep --timestamp=none --sign "$(SIGN_IDENTITY)" $(APP_BUNDLE); \
	else \
		echo "未找到代码签名证书，使用 ad-hoc 签名"; \
		codesign --force --deep --sign - $(APP_BUNDLE); \
	fi
	@echo "打包完成: $(APP_BUNDLE)"

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
