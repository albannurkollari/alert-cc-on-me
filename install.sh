#!/usr/bin/env sh
# Runs the offline tests, then copies the addon into the live WoW AddOns folder.
set -e
cd "$(dirname "$0")"
"${PYTHON:-C:/Python314/python}" tests/run_tests.py  # lupa has no wheel for 3.15
DEST="${WOW_ADDONS:-E:/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns}"
rm -rf "$DEST/AlertCCOnMe"
cp -r AlertCCOnMe "$DEST/"
echo "Installed to $DEST/AlertCCOnMe - /reload in game."
