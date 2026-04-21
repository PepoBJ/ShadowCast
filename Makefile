APP_NAME = ShadowCast
BUNDLE   = $(APP_NAME).app
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_PATH = $(BUILD_DIR)/$(BUNDLE)
INSTALL_PATH = /Applications/$(BUNDLE)
WHISPER_FRAMEWORK = .build/artifacts/shadowcast/whisper/whisper.xcframework/macos-arm64_x86_64/whisper.framework

.PHONY: build install uninstall release clean

## Build release binary
build:
	swift build -c release

## Build .app bundle (runs build first)
bundle: build
	@echo "→ Creating $(BUNDLE)..."
	@rm -rf $(APP_PATH)
	@mkdir -p $(APP_PATH)/Contents/MacOS
	@mkdir -p $(APP_PATH)/Contents/Resources
	@cp $(RELEASE_DIR)/$(APP_NAME) $(APP_PATH)/Contents/MacOS/
	@cp -r $(WHISPER_FRAMEWORK) $(APP_PATH)/Contents/MacOS/
	@cp Sources/ShadowCast/Resources/ShadowCast.entitlements $(APP_PATH)/Contents/Resources/
	@cp Sources/ShadowCast/Resources/AppIcon.icns $(APP_PATH)/Contents/Resources/
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0"><dict>\n\
  <key>CFBundleIdentifier</key><string>com.shadowcast.app</string>\n\
  <key>CFBundleName</key><string>$(APP_NAME)</string>\n\
  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>\n\
  <key>CFBundlePackageType</key><string>APPL</string>\n\
  <key>CFBundleIconFile</key><string>AppIcon</string>\n\
  <key>CFBundleShortVersionString</key><string>1.0</string>\n\
  <key>CFBundleVersion</key><string>1</string>\n\
  <key>LSMinimumSystemVersion</key><string>14.0</string>\n\
  <key>NSHighResolutionCapable</key><true/>\n\
  <key>NSPrincipalClass</key><string>NSApplication</string>\n\
  <key>NSHumanReadableCopyright</key><string>© 2026 ShadowCast</string>\n\
</dict></plist>\n' > $(APP_PATH)/Contents/Info.plist
	@codesign --force --deep --sign - $(APP_PATH) 2>/dev/null || true
	@echo "✓ Bundle ready: $(APP_PATH)"

## Install to /Applications
install: bundle
	@echo "→ Installing to $(INSTALL_PATH)..."
	@rm -rf $(INSTALL_PATH)
	@cp -r $(APP_PATH) $(INSTALL_PATH)
	@xattr -cr $(INSTALL_PATH) 2>/dev/null || true
	@codesign --force --deep --sign - $(INSTALL_PATH) 2>/dev/null || true
	@echo "✓ Installed. Open Spotlight and search for ShadowCast."

## Remove from /Applications
uninstall:
	@rm -rf $(INSTALL_PATH)
	@echo "✓ Uninstalled."

## Create a .zip for sharing / GitHub Releases
release: bundle
	@echo "→ Creating $(APP_NAME).zip..."
	@cd $(BUILD_DIR) && zip -r ../$(APP_NAME).zip $(BUNDLE)
	@echo "✓ $(APP_NAME).zip ready for distribution."

## Remove build artifacts
clean:
	@rm -rf $(BUILD_DIR) $(APP_NAME).zip
	@echo "✓ Cleaned."

help:
	@echo ""
	@echo "  make install    — build and install to /Applications"
	@echo "  make uninstall  — remove from /Applications"
	@echo "  make release    — create ShadowCast.zip for sharing"
	@echo "  make clean      — remove build artifacts"
	@echo ""
	@echo "  Requirements: swift, ffmpeg (brew install ffmpeg)"
	@echo ""
