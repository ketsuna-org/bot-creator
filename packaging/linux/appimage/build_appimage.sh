#!/usr/bin/env bash
set -euo pipefail

APP_NAME="bot_creator"
APP_ID="com.cardia_kexa.bot_creator"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
OUT_DIR="$ROOT_DIR/build/appimage"
APPDIR="$OUT_DIR/AppDir"
TOOLS_DIR="$ROOT_DIR/tools/appimage"
APPIMAGE_OUT="$OUT_DIR/${APP_NAME}-linux-x86_64.AppImage"

mkdir -p "$OUT_DIR" "$TOOLS_DIR"

echo "[1/5] Build Flutter Linux release"
flutter build linux --release

echo "[2/5] Prepare AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -a "$BUNDLE_DIR/." "$APPDIR/"

mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp "$ROOT_DIR/packaging/linux/appimage/bot_creator.desktop" "$APPDIR/$APP_ID.desktop"
cp "$ROOT_DIR/packaging/linux/appimage/bot_creator.desktop" "$APPDIR/usr/share/applications/$APP_ID.desktop"
cp "$ROOT_DIR/assets/icon/icon.png" "$APPDIR/$APP_ID.png"
cp "$ROOT_DIR/assets/icon/icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
cp "$ROOT_DIR/packaging/linux/common/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

if [[ ! -x "$TOOLS_DIR/appimagetool.AppImage" ]]; then
  echo "[3/5] Download appimagetool"
  curl -L "https://github.com/AppImage/appimagetool/releases/latest/download/appimagetool-x86_64.AppImage" -o "$TOOLS_DIR/appimagetool.AppImage"
  chmod +x "$TOOLS_DIR/appimagetool.AppImage"
fi

echo "[4/5] Build AppImage"
ARCH=x86_64 "$TOOLS_DIR/appimagetool.AppImage" --appimage-extract-and-run "$APPDIR" "$APPIMAGE_OUT"
chmod +x "$APPIMAGE_OUT"

echo "[5/5] Done"
echo "AppImage: $APPIMAGE_OUT"
