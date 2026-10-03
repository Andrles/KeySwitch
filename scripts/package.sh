#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/build/KeySwitch.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
output="$project_dir/build/KeySwitch-$version.dmg"
pkg_output="$project_dir/build/KeySwitch-$version.pkg"
zip_output="$project_dir/build/KeySwitch-$version.zip"
stage_dir="$(mktemp -d /private/tmp/keyswitch-package.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
payload_root="$stage_dir/payload"
stage_app="$payload_root/KeySwitch.app"
dmg_root="$stage_dir/dmg"

shasum "$project_dir"/Sources/*.swift "$project_dir/Resources/Info.plist" "$project_dir/scripts/IconGenerator.swift" "$project_dir/scripts/build.sh" "$project_dir/scripts/make-icon.sh" > "$stage_dir/current.source.sha1"
if [[ ! -d "$app_dir" ]] || ! cmp -s "$stage_dir/current.source.sha1" "$project_dir/build/KeySwitch.source.sha1"; then
  "$project_dir/scripts/build.sh"
fi
mkdir -p "$payload_root" "$dmg_root"
ditto --norsrc --noextattr "$app_dir" "$stage_app"
xattr -cr "$stage_app"
codesign --force --sign "${KEYSWITCH_SIGN_IDENTITY:--}" --identifier local.keyswitch.app "$stage_app"
xattr -cr "$stage_app"
codesign --verify --deep --strict "$stage_app"
rm -f "$zip_output"
ditto -c -k --sequesterRsrc --keepParent "$stage_app" "$zip_output"
ditto --norsrc --noextattr "$stage_app" "$dmg_root/KeySwitch.app"
ln -sfn /Applications "$dmg_root/Applications"
rm -f "$output"
rm -f "$pkg_output"
pkgbuild \
  --root "$payload_root" \
  --component-plist "$project_dir/Resources/PackageComponents.plist" \
  --scripts "$project_dir/scripts/installer" \
  --identifier local.keyswitch.installer \
  --version "$version" \
  --install-location /Applications \
  "$pkg_output"
echo "$pkg_output"

if [[ "${KEYSWITCH_BUILD_DMG:-0}" == 1 ]] && hdiutil create -volname "KeySwitch" -srcfolder "$dmg_root" -ov -format UDZO "$output"; then
  echo "$output"
else
  rm -f "$output"
fi
