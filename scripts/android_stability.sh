#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${APK_PATH:-build/deadshift-v3-debug.apk}"
PACKAGE="${PACKAGE:-com.dennypag02.deadshift}"
DURATION_SECONDS="${DURATION_SECONDS:-180}"
TAP_X="${TAP_X:-540}"
TAP_Y="${TAP_Y:-650}"

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
unzip -l "$APK_PATH" | grep -E 'lib/(arm64-v8a|x86_64)/' | head -20 | tee -a "$STATUS_FILE"
if ! unzip -l "$APK_PATH" | grep -q 'lib/x86_64/'; then
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

START=$(date +%s)
END=$((START + DURATION_SECONDS))
SAMPLES=0

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
  sleep 5
done

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
line = f"ANDROID_STABILITY_PASS samples={len(fps)} fps_min={min(fps)} fps_avg={sum(fps)/len(fps):.1f} enemies_max={max(enemies)}"
print(line)
with open(status_path, "a", encoding="utf-8") as fh:
    fh.write(line + "\n")
if max(enemies) < 40:
    raise SystemExit(f"dense horde not reached; enemies_max={max(enemies)}")
PY
