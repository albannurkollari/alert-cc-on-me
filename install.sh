#!/usr/bin/env sh
# Lints and tests the addon, then copies the addon into the live WoW AddOns folder.
set -e
cd "$(dirname "$0")"
tests/run.sh
DEST="${WOW_ADDONS:-E:/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns}"
rm -rf "$DEST/AlertCCOnMe"
cp -r AlertCCOnMe "$DEST/"
echo "Installed to $DEST/AlertCCOnMe - /reload in game."
