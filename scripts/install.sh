#!/bin/zsh
set -euo pipefail

repository="Andrles/KeySwitch"
# The public release redirect avoids the anonymous GitHub API rate limit.
release_url="$(curl --fail --silent --show-error --location --head --proto '=https' --proto-redir '=https' --tlsv1.2 --output /dev/null --write-out '%{url_effective}' "https://github.com/$repository/releases/latest")"
[[ "$release_url" == "https://github.com/$repository/releases/tag/"* ]] || { echo "Не удалось определить стабильную версию KeySwitch" >&2; exit 1; }
tag="${release_url##*/}"
version="${tag#v}"
[[ "$tag" == v* && "$version" =~ '^[0-9]+[.][0-9]+[.][0-9]+$' ]] || { echo "Некорректная версия KeySwitch" >&2; exit 1; }
download_url="https://github.com/$repository/releases/download/$tag/KeySwitch-$version.pkg"
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
