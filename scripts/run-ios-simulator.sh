#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Run this script on a Mac with Xcode installed.' >&2
  exit 1
fi
if ! xcrun --find simctl >/dev/null 2>&1 || ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo 'Select Xcode in Xcode → Settings → Locations → Command Line Tools, then try again.' >&2
  exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
device_id="${1:-}"
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
devices = []
for runtime, entries in json.load(sys.stdin)["devices"].items():
    match = re.search(r"\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    if not match or int(match[1]) < 17:
        continue
    version = tuple(int(part or 0) for part in match.groups())
    for device in entries:
        if device.get("isAvailable") and "iPhone" in device["name"]:
            devices.append((device["state"] == "Booted", version, device["udid"]))
if devices:
    print(max(devices)[2])
')"
fi
if [[ -z "$device_id" ]]; then
  echo 'Install an iPhone simulator with iOS 17 or later in Xcode → Settings → Components.' >&2
  exit 1
fi

# A dedicated build folder avoids touching an existing Xcode build or its caches.
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/adit-simulator.XXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
echo "Building Adit for simulator $device_id…"
xcodebuild -quiet -project "$project_root/Adit.xcodeproj" -scheme Adit \
  -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$build_dir" build CODE_SIGNING_ALLOWED=NO

if ! xcrun simctl list devices booted | /usr/bin/grep -Fq "$device_id"; then
  xcrun simctl boot "$device_id"
fi
open -a Simulator --args -CurrentDeviceUDID "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$build_dir/Build/Products/Debug-iphonesimulator/Adit.app"
xcrun simctl launch --terminate-running-process "$device_id" studio.adit.transit
echo 'Adit is running in Simulator.'
