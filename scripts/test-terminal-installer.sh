#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/bin"
cat > "$fixture/bin/curl" <<'MOCK'
#!/bin/zsh
set -eu
print -r -- "$*" >> "$TEST_LOG"
[[ "$*" != *api.github.com* ]] || exit 91
if [[ "$*" == *url_effective* ]]; then
  [[ "$TEST_MODE" != resolver_failure ]] || exit 22
  if [[ "$TEST_MODE" == wrong_repository ]]; then print -rn -- 'https://github.com/Other/Repository/releases/tag/v3.5.0'
  elif [[ "$TEST_MODE" == bad_tag ]]; then print -rn -- 'https://github.com/Andrles/KeySwitch/releases/tag/vbad'
  else print -rn -- 'https://github.com/Andrles/KeySwitch/releases/tag/v3.5.0'; fi
else
  [[ "$TEST_MODE" != download_failure ]] || exit 22
  [[ "$*" == *'/releases/download/v3.5.0/KeySwitch-3.5.0.pkg'* ]] || exit 92
  while (( $# )); do
    if [[ "$1" == --output ]]; then print -r -- fixture > "$2"; break; fi
    shift
  done
fi
MOCK
cat > "$fixture/bin/sudo" <<'MOCK'
#!/bin/zsh
print -r -- "INSTALL $*" >> "$TEST_LOG"
MOCK
cat > "$fixture/bin/open" <<'MOCK'
#!/bin/zsh
print -r -- "OPEN $*" >> "$TEST_LOG"
MOCK
chmod +x "$fixture/bin/"*
for mode in success resolver_failure wrong_repository bad_tag download_failure; do
  export TEST_MODE="$mode" TEST_LOG="$fixture/$mode.log"
  touch "$TEST_LOG"
  if PATH="$fixture/bin:$PATH" /bin/zsh "$project_dir/scripts/install.sh" > "$fixture/$mode.output" 2>&1; then
    [[ "$mode" == success ]] || { print -u2 -- "Unexpected success: $mode"; exit 1; }
    /usr/bin/grep -q '^INSTALL ' "$TEST_LOG"
    /usr/bin/grep -q '^OPEN /Applications/KeySwitch.app' "$TEST_LOG"
  else
    [[ "$mode" != success ]] || { cat "$fixture/$mode.output"; exit 1; }
    ! /usr/bin/grep -q '^INSTALL\|^OPEN' "$TEST_LOG"
  fi
  print -r -- "Terminal installer: $mode OK"
done
