#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$project_dir/build/tests"
export CLANG_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export KEYSWITCH_DISABLE_SYSTEM_DICTIONARY=1
xcrun swiftc \
  -sdk "$sdk_path" \
  -framework AppKit \
  "$project_dir/Sources/SystemDictionary.swift" \
  "$project_dir/Sources/LanguageEngine.swift" \
  "$project_dir/Tests/main.swift" \
  -o "$project_dir/build/tests/LanguageEngineTests"
"$project_dir/build/tests/LanguageEngineTests"
