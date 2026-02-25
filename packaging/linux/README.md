# Linux release packaging

Ce dossier contient les fichiers pour distribuer l'app Linux en format **AppImage** (portable, compatible avec la plupart des distros x86_64).

## Build AppImage

1. Depuis la racine du projet, exécuter:
   `bash packaging/linux/appimage/build_appimage.sh`
2. Le fichier généré sera:
   `build/appimage/bot_creator-linux-x86_64.AppImage`

## Installation locale (menu d'apps)

1. Exécuter:
   `bash packaging/linux/appimage/install_local.sh`
2. Cela copie l'AppImage dans `~/.local/bin` et crée un raccourci `.desktop`.

## Notes

- Format ciblé: **x86_64**.
- AppImage ne nécessite pas d'installation système root.
- C'est le format le plus simple pour "une release Linux" multi-distros.
