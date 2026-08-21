#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/build/KugouTouchBarLyrics.app"
CONTENTS_DIR="$APP_DIR/Contents"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$PROJECT_DIR/build/KugouTouchBarLyrics" "$CONTENTS_DIR/MacOS/KugouTouchBarLyrics"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/now-playing.js" "$CONTENTS_DIR/Resources/now-playing.js"
cp "$PROJECT_DIR/Resources/media-command.js" "$CONTENTS_DIR/Resources/media-command.js"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$CONTENTS_DIR/Resources/THIRD_PARTY_NOTICES.md"
rm -rf "$CONTENTS_DIR/Resources/MediaControl"
cp -R "$PROJECT_DIR/Vendor/MediaControl" "$CONTENTS_DIR/Resources/MediaControl"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
