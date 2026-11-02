#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="ClickBar"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ICONSET="$BUILD_DIR/AppIcon.iconset"
SDK_PATH="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"

mkdir -p "$BUILD_DIR"

echo "==> Testing..."
swiftc \
  -target "$TARGET" \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -module-name ClickBarCore \
  "$ROOT_DIR"/Sources/ClickBarCore/*.swift \
  "$ROOT_DIR"/Tests/ClickBarTests/StatsTests.swift \
  -o "$BUILD_DIR/clickbar-tests"
"$BUILD_DIR/clickbar-tests"

echo "==> Rendering app icon..."
swift "$ROOT_DIR/Scripts/RenderIcon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/AppIcon.icns"

echo "==> Building $APP_NAME (release)..."
CORE_DIR="$BUILD_DIR/ClickBarCore"
mkdir -p "$CORE_DIR"
swiftc -O \
  -target "$TARGET" \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -module-name ClickBarCore \
  -emit-module \
  -emit-module-path "$CORE_DIR/ClickBarCore.swiftmodule" \
  -emit-library \
  -o "$BUILD_DIR/libClickBarCore.dylib" \
  -Xlinker -install_name -Xlinker @rpath/libClickBarCore.dylib \
  "$ROOT_DIR"/Sources/ClickBarCore/*.swift

swiftc -O \
  -target "$TARGET" \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -module-name ClickBar \
  -I "$CORE_DIR" \
  -L "$BUILD_DIR" \
  -lClickBarCore \
  -framework AppKit \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -framework SwiftUI \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  "$ROOT_DIR"/Sources/ClickBar/*.swift \
  -o "$BUILD_DIR/$APP_NAME"

echo "==> Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CONTENTS/Frameworks"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/libClickBarCore.dylib" "$CONTENTS/Frameworks/libClickBarCore.dylib"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "==> Signing..."
SIGN_DIR="$HOME/Library/Application Support/ClickBar/signing"
KEYCHAIN="$SIGN_DIR/clickbar.keychain-db"
if [[ ! -f "$KEYCHAIN" || ! -f "$SIGN_DIR/clickbar.crt" ]]; then
  echo "Missing local signing identity at $SIGN_DIR" >&2
  exit 1
fi
KEYCHAIN_PASSWORD="${CLICKBAR_KEYCHAIN_PASSWORD:-}"
if [[ -z "$KEYCHAIN_PASSWORD" && -f "$ROOT_DIR/Scripts/.keychain-password" ]]; then
  KEYCHAIN_PASSWORD="$(<"$ROOT_DIR/Scripts/.keychain-password")"
fi
if [[ -z "$KEYCHAIN_PASSWORD" ]]; then
  echo "Set CLICKBAR_KEYCHAIN_PASSWORD or create Scripts/.keychain-password" >&2
  exit 1
fi
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
codesign --force --sign "ClickBar Local Codesign" --keychain "$KEYCHAIN" \
  "$CONTENTS/Frameworks/libClickBarCore.dylib"
codesign --force --sign "ClickBar Local Codesign" --keychain "$KEYCHAIN" \
  --identifier "com.siyunfei.ClickBar" "$APP_DIR"
codesign -d -r- "$APP_DIR" 2>&1 | rg "designated"

echo "==> Smoke launch..."
CLICKBAR_SMOKE=1 "$MACOS_DIR/$APP_NAME"

echo "==> Done: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
