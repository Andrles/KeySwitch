#!/bin/zsh
set -euo pipefail

repository="Andrles/KeySwitch"
download_url="https://github.com/$repository/releases/latest/download/KeySwitch.pkg"
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
