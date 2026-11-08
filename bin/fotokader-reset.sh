#!/usr/bin/env nix-shell
#!nix-shell -i bash -p android-tools
set -euo pipefail

TARGET="fotokader.l.nathan.gs:5555"
KIOSK_PKG="com.freekiosk"
KIOSK_ACTIVITY="com.freekiosk/.MainActivity"
FRAMEO_PKG="net.frameo.frame"

echo "[*] Connecting to ${TARGET} via nix-shell adb..."
adb disconnect "${TARGET}" >/dev/null 2>&1 || true

if ! adb connect "${TARGET}" | grep -qE "connected to|already connected"; then
    echo "[-] Error: Failed to connect to ${TARGET}" >&2
    exit 1
fi

echo "[+] Connected. Waiting for device..."
adb -s "${TARGET}" wait-for-device

echo "[*] 1. Disabling stock Frameo launcher..."
adb -s "${TARGET}" shell pm disable-user --user 0 "${FRAMEO_PKG}" 2>/dev/null || \
adb -s "${TARGET}" shell pm disable "${FRAMEO_PKG}" 2>/dev/null || true

echo "[*] 2. Applying system kiosk policies..."
# Keep display awake permanently while connected to AC power
adb -s "${TARGET}" shell svc power stayon true

# Prevent device lock screen (swipe / keyguard) on boot
adb -s "${TARGET}" shell settings put secure lockscreen.disabled 1

# Prevent Wi-Fi from entering low-power sleep when idle
adb -s "${TARGET}" shell settings put global wifi_sleep_policy 2

# Force immersive mode to hide navigation/status bars for FreeKiosk
adb -s "${TARGET}" shell settings put global policy_control "immersive.full=${KIOSK_PKG}"

echo "[*] 3. Granting runtime app permissions..."
# Overlay permission
adb -s "${TARGET}" shell appops set "${KIOSK_PKG}" SYSTEM_ALERT_WINDOW allow

# Whitelist from Android battery optimization / Doze mode
adb -s "${TARGET}" shell dumpsys deviceidle whitelist +"${KIOSK_PKG}" >/dev/null 2>&1 || true

echo "[*] 4. Checking and enabling accessibility service..."
ACCESSIBILITY_SVC=$(adb -s "${TARGET}" shell dumpsys accessibility 2>/dev/null | grep -oE "${KIOSK_PKG}/[a-zA-Z0-9_.]*" | head -n 1 || true)
if [[ -n "${ACCESSIBILITY_SVC}" ]]; then
    echo "[+] Found accessibility service: ${ACCESSIBILITY_SVC}"
    adb -s "${TARGET}" shell settings put secure enabled_accessibility_services "${ACCESSIBILITY_SVC}"
    adb -s "${TARGET}" shell settings put secure accessibility_enabled 1
fi

echo "[*] 5. Restarting FreeKiosk..."
adb -s "${TARGET}" shell am force-stop "${KIOSK_PKG}"
# Wake display if sleeping (KEYCODE_WAKEUP = 224)
adb -s "${TARGET}" shell input keyevent 224
adb -s "${TARGET}" shell am start -n "${KIOSK_ACTIVITY}"

echo "[*] 6. Verifying process status..."
sleep 2
if adb -s "${TARGET}" shell pidof "${KIOSK_PKG}" >/dev/null 2>&1; then
    PID=$(adb -s "${TARGET}" shell pidof "${KIOSK_PKG}")
    echo "[+] ${KIOSK_PKG} is running as primary UI (PID: ${PID})."
else
    echo "[!] Process not detected via pidof, sending Home key event..."
    adb -s "${TARGET}" shell input keyevent 3
fi

echo "[+] Default kiosk configuration complete."