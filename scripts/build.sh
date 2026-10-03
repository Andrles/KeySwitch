#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/build"
app_dir="$build_dir/KeySwitch.app"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
export CLANG_MODULE_CACHE_PATH="$build_dir/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$build_dir/module-cache-keyswitch"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$build_dir/arch"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/PkgInfo" "$app_dir/Contents/PkgInfo"

sources=("$project_dir"/Sources/*.swift)
for arch in arm64 x86_64; do
  xcrun swiftc \
    -sdk "$sdk_path" \
    -target "${arch}-apple-macos13.0" \
    -O \
    -framework AppKit \
    -framework ApplicationServices \
    -framework Carbon \
    -framework ServiceManagement \
    "${sources[@]}" \
    -o "$build_dir/arch/KeySwitch-$arch"
done

lipo -create \
  "$build_dir/arch/KeySwitch-arm64" \
  "$build_dir/arch/KeySwitch-x86_64" \
  -output "$app_dir/Contents/MacOS/KeySwitch"

"$project_dir/scripts/make-icon.sh" "$app_dir/Contents/Resources/AppIcon.png"
# Seal the bundle, including Info.plist/resources, with the bundle identifier.
# A real Apple signing identity can be supplied for distributed updates. Ad-hoc
# development builds can require Accessibility reauthorization after changes.
sign_identity="${KEYSWITCH_SIGN_IDENTITY:--}"
codesign --force --sign "$sign_identity" --identifier local.keyswitch.app "$app_dir"
codesign --verify --deep --strict "$app_dir"
shasum "$project_dir"/Sources/*.swift "$project_dir/Resources/Info.plist" "$project_dir/scripts/IconGenerator.swift" "$project_dir/scripts/build.sh" "$project_dir/scripts/make-icon.sh" > "$build_dir/KeySwitch.source.sha1"
echo "$app_dir"
