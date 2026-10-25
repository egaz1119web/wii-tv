#!/usr/bin/env bash
# Remove wiiOS from an Amazon Fire TV. The stock launcher was never touched, so this is all it takes.
set -euo pipefail
: "${FIRETV_HOST:?set FIRETV_HOST to the Fire TV IP address}"
ANDROID_HOME="${ANDROID_HOME:-$(for d in ~/Library/Android/sdk ~/Android/Sdk; do [ -d "$d" ] && echo "$d" && break; done)}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
TARGET="$FIRETV_HOST:5555"
adb connect "$TARGET" >/dev/null
CUR=$(adb -s "$TARGET" shell settings get secure enabled_accessibility_services | tr -d '\r')
REST=$(printf '%s' "$CUR" | tr ':' '\n' | grep -v '^com.gathin.tvhome/' | paste -sd: - || true)
if [ -n "$REST" ] && [ "$REST" != null ]; then
  adb -s "$TARGET" shell settings put secure enabled_accessibility_services "$REST"
else
  adb -s "$TARGET" shell settings delete secure enabled_accessibility_services
fi
adb -s "$TARGET" uninstall com.gathin.tvhome
echo "wiiOS removed; Home is the Amazon launcher again."
