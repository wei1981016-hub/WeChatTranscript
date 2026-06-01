APP_NAME := WeChatTranscript
BUILD_DIR := build
APP_DIR := dist/$(APP_NAME).app
BIN := $(APP_DIR)/Contents/MacOS/$(APP_NAME)

.PHONY: all clean run

all: $(APP_DIR)

$(APP_DIR): Sources/WeChatTranscript/main.swift Resources/Info.plist
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	mkdir -p "$(BUILD_DIR)/module-cache"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	xcrun swiftc \
		-target arm64-apple-macos14.0 \
		-module-cache-path "$(BUILD_DIR)/module-cache" \
		-O \
		-framework AppKit \
		-framework AVFoundation \
		-framework ScreenCaptureKit \
		-framework Speech \
		-framework UniformTypeIdentifiers \
		Sources/WeChatTranscript/main.swift \
		-o "$(BIN)"

run: all
	open "$(APP_DIR)"

clean:
	rm -rf "$(BUILD_DIR)" dist
