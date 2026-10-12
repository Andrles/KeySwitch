#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
mkdir -p "$project_dir/build/tests"
export CLANG_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
sources=("$project_dir"/Sources/*.swift)
sources=("${(@)sources:#*/main.swift}")
native_arch="$(uname -m)"
xcrun swiftc -D KEYSWITCH_TESTING -target "${native_arch}-apple-macos13.0" -framework AppKit -framework ApplicationServices -framework Carbon -framework ServiceManagement \
  "${sources[@]}" "$project_dir/Tests/PopupUI/main.swift" -o "$project_dir/build/tests/PopupUI"
"$project_dir/build/tests/PopupUI" --ui-preview "$@"
