#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if [ $# -ne 1 ]; then
  echo "Usage: bash scripts/test-on-mac.sh SIMULATOR_UDID" >&2
  echo "Find an installed simulator with: xcrun simctl list devices available" >&2
  exit 1
fi
xcodebuild -project iOS26Legacy.xcodeproj -scheme iOS26Legacy \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath build/TestDerivedData \
  -resultBundlePath "build/Tests-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
