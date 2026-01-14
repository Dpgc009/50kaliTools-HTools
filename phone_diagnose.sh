#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="phone_diagnose"
REPORT_DIR="${REPORT_DIR:-./reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "${REPORT_DIR}"

print_header() {
  printf "\n==== %s ====\n" "$1"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

write_section() {
  local title="$1"
  local content="$2"
  {
    echo "## ${title}"
    echo "${content}"
    echo
  } >>"${REPORT_FILE}"
}

start_report() {
  REPORT_FILE="${REPORT_DIR}/${SCRIPT_NAME}_${DEVICE_ID}_${TIMESTAMP}.md"
  {
    echo "# Phone Diagnostics Report"
    echo
    echo "- Timestamp: ${TIMESTAMP}"
    echo "- Device ID: ${DEVICE_ID}"
    echo "- Connection: ${CONNECTION_TYPE}"
    echo "- Platform: ${PLATFORM}"
    echo
  } >"${REPORT_FILE}"
}

adb_shell() {
  adb -s "${DEVICE_ID}" shell "$@" 2>/dev/null || true
}

adb_cmd() {
  adb -s "${DEVICE_ID}" "$@" 2>/dev/null || true
}

ios_cmd() {
  "$@" 2>/dev/null || true
}

summarize_health() {
  local summary=""

  if [[ "${PLATFORM}" == "Android" ]]; then
    local battery health temp level
    health="$(adb_shell dumpsys battery | awk -F': ' '/health/{print $2}' | head -n1)"
    temp="$(adb_shell dumpsys battery | awk -F': ' '/temperature/{print $2}' | head -n1)"
    level="$(adb_shell dumpsys battery | awk -F': ' '/level/{print $2}' | head -n1)"

    summary+="Battery health: ${health:-unknown}\n"
    if [[ -n "${temp}" ]]; then
      summary+="Battery temperature: $((temp / 10)).${temp: -1}°C\n"
    else
      summary+="Battery temperature: unknown\n"
    fi
    summary+="Battery level: ${level:-unknown}%\n"
  else
    local battery_health battery_level
    battery_health="$(ios_cmd ideviceinfo -k BatteryCurrentCapacity)"
    battery_level="$(ios_cmd ideviceinfo -k BatteryIsCharging)"

    summary+="Battery capacity (current): ${battery_health:-unknown}%\n"
    summary+="Charging status: ${battery_level:-unknown}\n"
  fi

  write_section "Quick Health Summary" "$summary"
}

check_android() {
  CONNECTION_TYPE="USB"
  PLATFORM="Android"
  start_report

  print_header "Android device detected: ${DEVICE_ID}"

  local build props storage mem
  build="$(adb_shell getprop ro.build.fingerprint)"
  props="$(adb_shell getprop)"
  storage="$(adb_shell df -h)"
  mem="$(adb_shell cat /proc/meminfo)"

  write_section "Build Fingerprint" "${build:-unavailable}"
  write_section "System Properties" "${props:-unavailable}"
  write_section "Storage (df -h)" "${storage:-unavailable}"
  write_section "Memory (/proc/meminfo)" "${mem:-unavailable}"

  local battery
  battery="$(adb_shell dumpsys battery)"
  write_section "Battery Status" "${battery:-unavailable}"

  local thermal
  thermal="$(adb_shell dumpsys thermalservice)"
  write_section "Thermal Status" "${thermal:-unavailable}"

  local kernel
  kernel="$(adb_shell uname -a)"
  write_section "Kernel" "${kernel:-unavailable}"

  local logs
  logs="$(adb_shell logcat -d -t 200)"
  write_section "Recent Logs (last 200 lines)" "${logs:-unavailable}"

  summarize_health

  echo "Report saved to: ${REPORT_FILE}"
}

check_ios() {
  CONNECTION_TYPE="USB"
  PLATFORM="iOS"
  start_report

  print_header "iOS device detected: ${DEVICE_ID}"

  local info
  info="$(ios_cmd ideviceinfo)"
  write_section "Device Info" "${info:-unavailable}"

  local diagnostics
  diagnostics="$(ios_cmd idevicediagnostics diagnostics)"
  write_section "Diagnostics" "${diagnostics:-unavailable}"

  local battery
  battery="$(ios_cmd ideviceinfo -k BatteryCurrentCapacity)"
  write_section "Battery Current Capacity" "${battery:-unavailable}"

  summarize_health

  echo "Report saved to: ${REPORT_FILE}"
}

usage() {
  cat <<USAGE
Usage: ${SCRIPT_NAME} [--android|--ios]

This script checks connected phones for software and hardware signals using
available tools (adb for Android, libimobiledevice for iOS).

Examples:
  ${SCRIPT_NAME} --android
  ${SCRIPT_NAME} --ios
USAGE
}

main() {
  if [[ "${1:-}" == "--android" ]]; then
    if ! have_cmd adb; then
      echo "adb not found. Install Android platform tools." >&2
      exit 1
    fi
    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    if [[ -z "${DEVICE_ID}" ]]; then
      echo "No Android device detected via adb." >&2
      exit 1
    fi
    check_android
    exit 0
  fi

  if [[ "${1:-}" == "--ios" ]]; then
    if ! have_cmd ideviceinfo; then
      echo "ideviceinfo not found. Install libimobiledevice tools." >&2
      exit 1
    fi
    DEVICE_ID="$(ios_cmd ideviceinfo -k UniqueDeviceID)"
    if [[ -z "${DEVICE_ID}" ]]; then
      echo "No iOS device detected via libimobiledevice." >&2
      exit 1
    fi
    check_ios
    exit 0
  fi

  usage
  exit 1
}

main "$@"
