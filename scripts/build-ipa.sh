#!/bin/bash
# macOS only. Produces an unsigned device IPA for Sideloadly to sign.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null; then
  echo "Xcode 15.x on a compatible Mac is required." >&2
  exit 1
fi
version="$(xcodebuild -version | head -n 1)"
case "$version" in
  "Xcode 15."*) ;;
  *) echo "Select Xcode 15.x (recommended: 15.4) to retain the iOS 12 toolchain. Found: $version" >&2; exit 1 ;;
esac
build_dir="$project_root/build"
mkdir -p "$build_dir"
work_dir="$(mktemp -d "$build_dir/ipa.XXXXXX")"
# The generated temporary directory is inside build; no other files are removed.
trap 'rm -rf -- "$work_dir"' EXIT
xcodebuild -project iOS26Legacy.xcodeproj -scheme iOS26Legacy \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$build_dir/DerivedData" \
  IPHONEOS_DEPLOYMENT_TARGET=12.0 CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
app_path="$build_dir/DerivedData/Build/Products/Release-iphoneos/iOS26Legacy.app"
test -d "$app_path"
minimum="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app_path/Info.plist")"
if [ "$minimum" != '12.0' ]; then
  echo "Unexpected MinimumOSVersion: $minimum; refusing to package." >&2
  exit 1
fi
mkdir -p "$work_dir/Payload"
ditto "$app_path" "$work_dir/Payload/iOS26Legacy.app"
temporary_ipa="$work_dir/iOS26Legacy-unsigned.ipa"
(cd "$work_dir" && /usr/bin/zip -qr "$temporary_ipa" Payload)
mv -f "$temporary_ipa" "$build_dir/iOS26Legacy-unsigned.ipa"
echo "Created $build_dir/iOS26Legacy-unsigned.ipa"
echo "This IPA must be signed by Sideloadly before installation."
