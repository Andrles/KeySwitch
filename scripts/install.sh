#!/bin/zsh
set -euo pipefail

repository="Andrles/KeySwitch"
# Resolve the actual asset name; releases use versioned packages.
release_json="$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "https://api.github.com/repos/$repository/releases/latest")"
download_url="$(printf '%s' "$release_json" | /usr/bin/plutil -extract assets json -o - - | /usr/bin/osascript -l JavaScript -e 'ObjC.import("Foundation"); function run() { var data = JSON.parse($.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile, $.NSUTF8StringEncoding).js); var asset = data.find(function(a) { return /^KeySwitch(?:-[0-9.]+)?\.pkg$/.test(a.name); }); if (!asset) throw new Error("Установщик не найден в последнем Release"); return asset.browser_download_url; }')"
[[ "$download_url" == "https://github.com/$repository/releases/download/"* ]] || { echo "Некорректная ссылка установщика" >&2; exit 1; }
temporary_dir="$(mktemp -d /private/tmp/keyswitch-install.XXXXXX)"
package_path="$temporary_dir/KeySwitch.pkg"

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

echo "Загрузка последней версии KeySwitch…"
curl \
  --fail \
  --location \
  --proto '=https' \
  --tlsv1.2 \
  --output "$package_path" \
  "$download_url"

echo "Установка KeySwitch в /Applications…"
sudo /usr/sbin/installer -pkg "$package_path" -target /

echo "KeySwitch установлен."
open /Applications/KeySwitch.app
