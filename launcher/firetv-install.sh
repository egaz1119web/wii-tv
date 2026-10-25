#!/usr/bin/env bash
# Build the launcher APK and install it on an Amazon Fire TV (Fire OS 6 to 8).
#
# Unlike build-and-install.sh this never disables the stock Amazon launcher and never changes the
# home preference: Fire OS keeps Home on its own launcher, and a Fire TV with it disabled has no
# usable Home. Instead FireTvHomeService opens the menu whenever the Amazon home screen comes up.
#
#   FIRETV_HOST=192.168.0.50 launcher/firetv-install.sh
#
# Needs adb (Android SDK platform-tools) and, on the Fire TV, Settings → My Fire TV → Developer
# options → ADB debugging on.
set -euo pipefail
cd "$(dirname "$0")"
: "${FIRETV_HOST:?set FIRETV_HOST to the Fire TV IP address, e.g. FIRETV_HOST=192.168.0.50 $0}"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17 2>/dev/null || { [ -d /opt/homebrew/opt/openjdk@17 ] && echo /opt/homebrew/opt/openjdk@17; } || java -XshowSettings:properties -version 2>&1 | awk '/java.home/ {print $3}')}"
export ANDROID_HOME="${ANDROID_HOME:-$(for d in ~/Library/Android/sdk ~/Android/Sdk; do [ -d "$d" ] && echo "$d" && break; done)}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
[ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties

TARGET="$FIRETV_HOST:5555"
adb connect "$TARGET" >/dev/null
# The first connection shows "Allow USB debugging?" on the TV; wait until it is accepted.
for _ in $(seq 1 30); do
  [ "$(adb -s "$TARGET" get-state 2>/dev/null)" = device ] && break
  echo "Waiting for the Fire TV to allow debugging (accept the prompt on the TV)..."; sleep 2
done
[ "$(adb -s "$TARGET" get-state 2>/dev/null)" = device ] || { echo "ERROR: $TARGET is not reachable over adb." >&2; exit 1; }
sh() { adb -s "$TARGET" shell "$@" | tr -d '\r'; }

MANUFACTURER=$(sh getprop ro.product.manufacturer)
[ "$MANUFACTURER" = Amazon ] || { echo "ERROR: $TARGET is made by '$MANUFACTURER', not Amazon. Use build-and-install.sh for Android TV." >&2; exit 1; }
echo "Fire TV: $(sh getprop ro.product.model), Fire OS $(sh getprop ro.build.version.name)"

./gradlew assembleRelease -q --console=plain
adb -s "$TARGET" install -r app/build/outputs/apk/release/app-release.apk

sh pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
# Accessibility services: add ours without dropping others. Android turns them off on reinstall.
SVC=com.gathin.tvhome/.FireTvHomeService
CUR=$(sh settings get secure enabled_accessibility_services)
case "$CUR" in
  *FireTvHomeService*) ;;
  null|'') sh settings put secure enabled_accessibility_services "$SVC" ;;
  *) sh settings put secure enabled_accessibility_services "$CUR:$SVC" ;;
esac
sh settings put secure accessibility_enabled 1
if [ "${SCREENSAVER:-0}" = 1 ]; then sh settings put secure screensaver_components com.gathin.tvhome/.ClockDream; fi

sh am start -n com.gathin.tvhome/.WiiMenuActivity --ez show_intro true >/dev/null
echo "Installed. Press Home on the remote to see it."
echo "To go back to the Amazon home: FIRETV_HOST=$FIRETV_HOST launcher/firetv-uninstall.sh"
