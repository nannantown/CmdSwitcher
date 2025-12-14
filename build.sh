#!/bin/bash

# CmdSwitcher Build Script
# ユニバーサルバイナリ（Intel + Apple Silicon）対応

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="CmdSwitcher"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Building $APP_NAME (Universal Binary) ==="

# クリーンアップ
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# ARM64 (Apple Silicon) 用にコンパイル
echo "Compiling for arm64..."
swiftc \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macos12.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework Carbon \
    -framework ServiceManagement \
    -o "$BUILD_DIR/${APP_NAME}_arm64" \
    "$SCRIPT_DIR/CmdSwitcher/main.swift" \
    "$SCRIPT_DIR/CmdSwitcher/KeyHandler.swift" \
    "$SCRIPT_DIR/CmdSwitcher/AppDelegate.swift"

# x86_64 (Intel) 用にコンパイル
echo "Compiling for x86_64..."
swiftc \
    -O \
    -whole-module-optimization \
    -target x86_64-apple-macos12.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework Cocoa \
    -framework Carbon \
    -framework ServiceManagement \
    -o "$BUILD_DIR/${APP_NAME}_x86_64" \
    "$SCRIPT_DIR/CmdSwitcher/main.swift" \
    "$SCRIPT_DIR/CmdSwitcher/KeyHandler.swift" \
    "$SCRIPT_DIR/CmdSwitcher/AppDelegate.swift"

# ユニバーサルバイナリを作成
echo "Creating universal binary..."
lipo -create \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64" \
    -output "$MACOS_DIR/$APP_NAME"

# 一時ファイルを削除
rm "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

# Info.plistをコピー
echo "Copying Info.plist..."
cp "$SCRIPT_DIR/CmdSwitcher/Info.plist" "$CONTENTS_DIR/"

# アイコンをコピー
echo "Copying icon..."
cp "$SCRIPT_DIR/CmdSwitcher/AppIcon.icns" "$RESOURCES_DIR/"

# PkgInfoを作成
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 実行権限を付与
chmod +x "$MACOS_DIR/$APP_NAME"

# ad-hoc署名（権限が保持されるように）
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "=== Build Complete ==="
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "NOTE: You need to grant Accessibility permission in:"
echo "  System Settings > Privacy & Security > Accessibility"
