#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
mkdir -p "$project_dir/build/browser-replacement"
app_dir="$project_dir/build/browser-replacement/BrowserLab.app"
mkdir -p "$app_dir/Contents/MacOS"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.keyswitch.browserlab</string>
<key>CFBundleName</key><string>KeySwitch Browser Lab</string>
<key>CFBundleExecutable</key><string>BrowserLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
export CLANG_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
sources=("$project_dir"/Sources/*.swift)
sources=("${(@)sources:#*/main.swift}")
xcrun swiftc -O -framework AppKit -framework ApplicationServices -framework Carbon -framework ServiceManagement -framework WebKit \
  "${sources[@]}" "$project_dir/Tests/BrowserReplacement/main.swift" \
  -o "$app_dir/Contents/MacOS/BrowserLab"
codesign --force --sign - "$app_dir"
