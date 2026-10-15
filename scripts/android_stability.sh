#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${APK_PATH:-build/deadshift-v3-debug.apk}"
PACKAGE="${PACKAGE:-com.dennypag02.deadshift}"
DURATION_SECONDS="${DURATION_SECONDS:-180}"
TAP_X="${TAP_X:-540}"
TAP_Y="${TAP_Y:-650}"
START_X="${START_X:-540}"
START_Y="${START_Y:-1363}"

mkdir -p android-stability
CRASH_LOG="android-stability/crash.log"
RUNTIME_LOG="android-stability/android-runtime.log"
PID_FILE="android-stability/deadshift.pid"
STATUS_FILE="android-stability/status.txt"

capture_logs() {
  set +e
  adb logcat -d > "$CRASH_LOG" 2>&1
  adb shell pidof "$PACKAGE" > "$PID_FILE" 2>/dev/null
  grep "ANDROID_RUNTIME" "$CRASH_LOG" > "$RUNTIME_LOG" 2>/dev/null
  set -e
}
trap capture_logs EXIT

echo "ANDROID_STABILITY_BEGIN" | tee "$STATUS_FILE"
test -s "$APK_PATH"

echo "Checking APK ABI contents..." | tee -a "$STATUS_FILE"
unzip -Z1 "$APK_PATH" > android-stability/apk-files.txt
grep -E 'lib/(arm64-v8a|x86_64)/' android-stability/apk-files.txt | head -20 | tee -a "$STATUS_FILE" || true
if ! grep -Fq 'lib/x86_64/libgodot_android.so' android-stability/apk-files.txt; then
  echo "INSTALL_FAILED_NO_MATCHING_ABIS: APK has no x86_64 native library" | tee -a "$STATUS_FILE"
  exit 21
fi

adb logcat -c
echo "Installing APK..." | tee -a "$STATUS_FILE"
set +e
INSTALL_OUTPUT=$(adb install -r "$APK_PATH" 2>&1)
INSTALL_RC=$?
set -e
printf '%s\n' "$INSTALL_OUTPUT" | tee -a "$STATUS_FILE"
if [ "$INSTALL_RC" -ne 0 ]; then
  if printf '%s\n' "$INSTALL_OUTPUT" | grep -q 'INSTALL_FAILED_NO_MATCHING_ABIS'; then
    echo "INSTALL_FAILED_NO_MATCHING_ABIS detected" | tee -a "$STATUS_FILE"
  fi
  exit "$INSTALL_RC"
fi

adb logcat -c
echo "Launching $PACKAGE..." | tee -a "$STATUS_FILE"
adb shell monkey -p "$PACKAGE" 1 | tee -a "$STATUS_FILE"
sleep 8
# Pixel 6 is 1080x2400: the production 432x960 title button is at (216,545).
# The old (540,650) tap is a level-up-card location, NOT the title's START RUN.
adb exec-out screencap -p > android-stability/title-screen.png
adb shell input tap "$START_X" "$START_Y"
echo "MILESTONE - tapped actual START RUN at $START_X,$START_Y; normal damage, no debug commands" | tee -a "$STATUS_FILE"

START=$(date +%s)
END=$((START + DURATION_SECONDS))
SAMPLES=0
LAST_HEARTBEAT=$START

while [ "$(date +%s)" -lt "$END" ]; do
  PID=$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)
  if [ -z "$PID" ]; then
    echo "APP_PROCESS_DIED elapsed=$(( $(date +%s) - START ))s" | tee -a "$STATUS_FILE"
    capture_logs
    grep -Ein 'FATAL EXCEPTION|AndroidRuntime|SIGSEGV|Fatal signal|Out of memory|OutOfMemoryError|godot' "$CRASH_LOG" | tail -120 | tee -a "$STATUS_FILE" || true
    exit 30
  fi
  printf '%s\n' "$PID" > "$PID_FILE"
  adb shell input tap "$TAP_X" "$TAP_Y" >/dev/null 2>&1 || true
  SAMPLES=$((SAMPLES + 1))
  NOW=$(date +%s)
  if [ "$((NOW - LAST_HEARTBEAT))" -ge 30 ]; then
    echo "RUNNING - Android process alive; elapsed=$((NOW - START))s samples=$SAMPLES" | tee -a "$STATUS_FILE"
    adb logcat -d | grep 'ANDROID_RUNTIME' | tail -1 | tee -a "$STATUS_FILE" || true
    LAST_HEARTBEAT=$NOW
  fi
  sleep 5
done
adb exec-out screencap -p > android-stability/end-screen.png
# Preserve actual local telemetry from this isolated emulator installation.
adb exec-out run-as "$PACKAGE" sh -c 'cd files; tar -cf - runs' > android-stability/local-runs.tar 2>/dev/null || true

capture_logs

if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|SIGSEGV|Fatal signal|Out of memory|OutOfMemoryError' "$CRASH_LOG"; then
  echo "ANDROID_FATAL_SIGNATURE_DETECTED" | tee -a "$STATUS_FILE"
  grep -Ein 'FATAL EXCEPTION|AndroidRuntime|SIGSEGV|Fatal signal|Out of memory|OutOfMemoryError|godot' "$CRASH_LOG" | tail -120 | tee -a "$STATUS_FILE"
  exit 31
fi

if ! grep -q "ANDROID_RUNTIME" "$RUNTIME_LOG"; then
  echo "MISSING_ANDROID_RUNTIME_TELEMETRY" | tee -a "$STATUS_FILE"
  exit 32
fi

python3 - "$RUNTIME_LOG" "$STATUS_FILE" <<'PY'
import re, sys
runtime_path, status_path = sys.argv[1:3]
text = open(runtime_path, encoding="utf-8", errors="ignore").read()
fps = [int(x) for x in re.findall(r"fps=(\d+)", text)]
enemies = [int(x) for x in re.findall(r"enemies=(\d+)", text)]
if not fps or not enemies:
    raise SystemExit("missing Android runtime telemetry")
if max(enemies) < 40:
    raise SystemExit(f"dense horde not reached; enemies_max={max(enemies)}")
line = f"ANDROID_STABILITY_PASS samples={len(fps)} fps_min={min(fps)} fps_avg={sum(fps)/len(fps):.1f} enemies_max={max(enemies)}"
print(line)
with open(status_path, "a", encoding="utf-8") as fh:
    fh.write(line + "\n")
PY
