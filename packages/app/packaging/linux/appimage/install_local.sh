#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APPIMAGE_PATH="${1:-$ROOT_DIR/build/appimage/bot_creator-linux-x86_64.AppImage}"

if [[ ! -f "$APPIMAGE_PATH" ]]; then
  echo "AppImage not found: $APPIMAGE_PATH"
  echo "Build it first with packaging/linux/appimage/build_appimage.sh"
  exit 1
fi

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"

TARGET_APPIMAGE="$HOME/.local/bin/bot_creator.AppImage"
cp "$APPIMAGE_PATH" "$TARGET_APPIMAGE"
chmod +x "$TARGET_APPIMAGE"
cp "$ROOT_DIR/assets/icon/icon.png" "$HOME/.local/share/icons/hicolor/256x256/apps/com.cardia_kexa.bot_creator.png"

cat > "$HOME/.local/share/applications/com.cardia_kexa.bot_creator.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Bot Creator
Comment=Discord bot creator
Exec=$TARGET_APPIMAGE
Icon=com.cardia_kexa.bot_creator
Terminal=false
Categories=Utility;Development;
StartupNotify=true
StartupWMClass=bot_creator
EOF

echo "Installed locally."
echo "You can launch it from your app menu (Bot Creator)."
