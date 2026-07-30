#!/bin/zsh
set -euo pipefail

output="${1:?output png path required}"
script_dir="${0:A:h}"
project_dir="${script_dir:h}"
generator="$project_dir/build/icon-generator"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
export CLANG_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"

xcrun swiftc \
  -sdk "$sdk_path" \
  -framework AppKit \
  "$project_dir/scripts/IconGenerator.swift" \
  -o "$generator"
"$generator" "$output"
