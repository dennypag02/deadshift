#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${APK_PATH:-build/deadshift-v3-debug.apk}"
PACKAGE="${PACKAGE:-com.dennypag02.deadshift}"
DURATION_SECONDS="${DURATION_SECONDS:-180}"
TAP_X="${TAP_X:-540}"
TAP_Y="${TAP_Y:-750}"
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

# A fresh emulator continues installing dynamic theme overlays after boot_completed.
# Do not launch Godot while Android is recreating activities for CONFIG_ASSETS_PATHS.
# This readiness gate runs before app installation; no in-app crash is retried or hidden.
python3 - <<'PY'
from pathlib import Path
import hashlib, json, subprocess, time
start = time.monotonic()
stable_since = start
previous = None
records = []
while time.monotonic() - start < 75:
    boot = subprocess.run(['adb','shell','getprop','sys.boot_completed'],capture_output=True,text=True,timeout=10,check=True).stdout.strip()
    overlays = subprocess.run(['adb','shell','cmd','overlay','list','--user','0'],capture_output=True,text=True,timeout=10,check=True).stdout
    fingerprint = hashlib.sha256(overlays.encode()).hexdigest()
    now = time.monotonic()
    if fingerprint != previous:
        stable_since = now
        previous = fingerprint
    row = {'elapsed_s':round(now-start,2),'unchanged_s':round(now-stable_since,2),'boot_completed':boot,'overlay_sha256':fingerprint}
    records.append(row)
    print('RUNNING - emulator readiness ' + json.dumps(row),flush=True)
    Path('android-stability/boot-readiness.json').write_text(json.dumps(records,indent=2))
    if boot == '1' and now-start >= 20 and now-stable_since >= 10:
        Path('android-stability/settled-overlays.txt').write_text(overlays)
        print('MILESTONE - first-boot overlay state settled; launching a clean test session.',flush=True)
        break
    time.sleep(2)
else:
    raise SystemExit('EMULATOR_FIRST_BOOT_NOT_SETTLED; app not launched')
PY

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
# Fresh Android installations show a system-owned immersive-mode teaching
# overlay. Dismiss only its observed Got it button, never an arbitrary app control.
adb exec-out screencap -p > android-stability/before-system-prompt.png
timeout 20s adb shell uiautomator dump /sdcard/deadshift-system-ui.xml > android-stability/system-ui-dump.log 2>&1
adb pull /sdcard/deadshift-system-ui.xml android-stability/system-ui.xml >/dev/null
python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
root = ET.parse('android-stability/system-ui.xml').getroot()
for node in root.iter('node'):
    text = node.attrib.get('text', '').strip().lower()
    package = node.attrib.get('package', '')
    if text == 'got it' and package in ('com.android.systemui', 'android'):
        bounds = list(map(int, re.findall(r'\d+', node.attrib.get('bounds', ''))))
        assert len(bounds) == 4, 'System prompt bounds unavailable'
        x, y = (bounds[0]+bounds[2])//2, (bounds[1]+bounds[3])//2
        subprocess.run(['adb','shell','input','tap',str(x),str(y)],check=True,timeout=10)
        message=f'MILESTONE - dismissed observed Android system Got it prompt at {x},{y}'
        print(message)
        with Path('android-stability/status.txt').open('a') as f: f.write(message+'\n')
        break
else:
    print('MILESTONE - no system Got it prompt present in UI hierarchy')
PY
sleep 2
# Pixel 6 is 1080x2400: production 432x960 title button is at (216,545).
# A normal level-up card center is around (216,300), separate from START RUN.
adb exec-out screencap -p > android-stability/title-screen.png
adb shell input tap "$START_X" "$START_Y"
echo "MILESTONE - tapped START RUN at $START_X,$START_Y; normal damage, no debug commands" | tee -a "$STATUS_FILE"

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
# This isolated installation is automation evidence, never a human-player cohort.
adb exec-out run-as "$PACKAGE" sh -c 'cd files; tar -cf - runs' > android-stability/local-runs.tar 2>/dev/null || true
capture_logs

if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|SIGSEGV|Fatal signal|Out of memory|OutOfMemoryError|SCRIPT ERROR|Parse Error' "$CRASH_LOG"; then
  echo "ANDROID_FATAL_OR_SCRIPT_SIGNATURE_DETECTED" | tee -a "$STATUS_FILE"
  grep -Ein 'FATAL EXCEPTION|AndroidRuntime|SIGSEGV|Fatal signal|Out of memory|OutOfMemoryError|godot' "$CRASH_LOG" | tail -120 | tee -a "$STATUS_FILE"
  exit 31
fi
if ! grep -q "ANDROID_RUNTIME" "$RUNTIME_LOG"; then
  echo "MISSING_ANDROID_RUNTIME_TELEMETRY" | tee -a "$STATUS_FILE"
  exit 32
fi

# Read the contract from the APK, not a hardcoded pre-tuning enemy count.
# Preserve the 60-active-second gate and add non-silent mixer/cue/cap evidence.
python3 - "$RUNTIME_LOG" "$STATUS_FILE" "$CRASH_LOG" "$APK_PATH" <<'PY'
import json, math, re, sys, zipfile
runtime_path, status_path, crash_path, apk_path = sys.argv[1:5]
text = open(runtime_path, encoding='utf-8', errors='ignore').read()
fps = [int(x) for x in re.findall(r'fps=(\d+)', text)]
enemies = [int(x) for x in re.findall(r'enemies=(\d+)', text)]
if not fps or not enemies:
    raise SystemExit('missing Android runtime telemetry')
with zipfile.ZipFile(apk_path) as apk:
    movement = json.loads(apk.read('assets/data/movement.json'))
    tuning = json.loads(apk.read('assets/data/early_tuning.json'))
    audio_cfg = json.loads(apk.read('assets/data/sounds.json'))
expected_min = math.floor(float(movement['pressure']['minimums'][0][1])*float(tuning['pressure_by_wave'][0])+0.5)
if expected_min < 1 or max(enemies) < expected_min:
    raise SystemExit(f'configured horde not reached; enemies_max={max(enemies)} required={expected_min}')
active, audio = [], []
crash = open(crash_path, encoding='utf-8', errors='ignore').read()
if re.search(r'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|AndroidRuntime.*FATAL|SIGSEGV|Fatal signal|OutOfMemoryError',crash,re.I):
    raise SystemExit('Android script/fatal signature detected')
for line in crash.splitlines():
    if 'PACING {' in line:
        try: active.append(float(json.loads(line.split('PACING ',1)[1]).get('active_s',0)))
        except (ValueError, TypeError): continue
    if 'STAGE2 {' in line:
        try: row = json.loads(line.split('STAGE2 ',1)[1])
        except (ValueError, TypeError): continue
        if row.get('event') == 'audio_sample': audio.append(row)
if not active or max(active) < 60:
    raise SystemExit(f'insufficient active gameplay; active_seconds={max(active,default=0)}')
if not audio or not any(float(row.get('master_peak_db',-200)) > -70 for row in audio):
    raise SystemExit('missing non-silent Android audio mixer evidence')
if not any(int(row.get('played',{}).get('smg_fire',0)) > 0 for row in audio):
    raise SystemExit('weapon sound hook did not run')
if any(int(row.get('peak_voices',0)) > int(audio_cfg['hard_cap']) for row in audio):
    raise SystemExit('audio voice cap exceeded')
if any(int(row.get('sounds_loaded',0)) != len(audio_cfg['sounds']) for row in audio):
    raise SystemExit('audio cue catalog not fully loaded')
line = f'ANDROID_STABILITY_PASS samples={len(fps)} fps_min={min(fps)} fps_avg={sum(fps)/len(fps):.1f} enemies_max={max(enemies)} configured_min={expected_min} active_seconds={max(active):.3f} audio_samples={len(audio)} peak_voices={max(int(r.get("peak_voices",0)) for r in audio)}'
print(line)
with open(status_path, 'a', encoding='utf-8') as fh: fh.write(line+'\n')
print('180 wall seconds of process validation, not 180 active seconds survived or physical-phone FPS/audibility acceptance.')
PY
