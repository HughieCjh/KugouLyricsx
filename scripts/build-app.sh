#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/build/KugouLyricsx.app"
CONTENTS_DIR="$APP_DIR/Contents"
ICONSET_DIR="$PROJECT_DIR/build/AppIcon.iconset"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$PROJECT_DIR/build/KugouLyricsx" "$CONTENTS_DIR/MacOS/KugouLyricsx"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/now-playing.js" "$CONTENTS_DIR/Resources/now-playing.js"
cp "$PROJECT_DIR/Resources/media-command.js" "$CONTENTS_DIR/Resources/media-command.js"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$CONTENTS_DIR/Resources/THIRD_PARTY_NOTICES.md"

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$PROJECT_DIR/Resources/AppIcon.png" "$ICONSET_DIR/icon_512x512@2x.png"
/usr/bin/clang -fobjc-arc -framework Foundation \
    "$PROJECT_DIR/scripts/make-icns.m" \
    -o "$PROJECT_DIR/build/make-icns"
"$PROJECT_DIR/build/make-icns" \
    "$ICONSET_DIR" \
    "$CONTENTS_DIR/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

rm -rf "$CONTENTS_DIR/Resources/MediaControl"
cp -R "$PROJECT_DIR/Vendor/MediaControl" "$CONTENTS_DIR/Resources/MediaControl"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
