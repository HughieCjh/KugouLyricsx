#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="0.4.2"
APP_SOURCE="$PROJECT_DIR/build/KugouLyricsx.app"
DIST_DIR="$PROJECT_DIR/dist"
DMG_ROOT="$PROJECT_DIR/build/dmg-root"
DMG_PATH="$DIST_DIR/KugouLyricsx-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/KugouLyricsx-$VERSION-app.zip"

if [ ! -d "$APP_SOURCE" ]; then
    echo "App bundle not found: $APP_SOURCE" >&2
    echo "Run 'make app' first." >&2
    exit 1
fi

rm -rf "$DMG_ROOT" "$DIST_DIR/KugouLyricsx.app"
mkdir -p "$DMG_ROOT" "$DIST_DIR"

cp -R "$APP_SOURCE" "$DMG_ROOT/KugouLyricsx.app"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$PROJECT_DIR/README.md" "$DMG_ROOT/README.md"
cp "$PROJECT_DIR/LICENSE" "$DMG_ROOT/LICENSE"
cp -R "$APP_SOURCE" "$DIST_DIR/KugouLyricsx.app"

rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_SOURCE" "$ZIP_PATH"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "KugouLyricsx" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "$DMG_PATH"
