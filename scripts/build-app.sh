#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
APP_NAME="Codex 岛台.app"
APP_PATH="$PROJECT_ROOT/dist/$APP_NAME"
CONTENTS_PATH="$APP_PATH/Contents"

swift build \
  --package-path "$PROJECT_ROOT" \
  --product CodexNotchNavigator \
  -c release

BUILD_BIN_PATH=$(swift build --package-path "$PROJECT_ROOT" -c release --show-bin-path)
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$BUILD_BIN_PATH/CodexNotchNavigator" "$CONTENTS_PATH/MacOS/CodexNotchNavigator"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$CONTENTS_PATH/Resources/AppIcon.icns"
chmod 755 "$CONTENTS_PATH/MacOS/CodexNotchNavigator"

codesign --force --deep --sign - "$APP_PATH"
echo "$APP_PATH"
