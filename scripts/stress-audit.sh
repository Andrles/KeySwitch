#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
mkdir -p "$project_dir/build/stress-audit"
python3 "$project_dir/Tests/StressAudit/generate.py"
export CLANG_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
export SWIFT_MODULE_CACHE_PATH="$project_dir/build/module-cache-keyswitch"
xcrun swiftc -O -framework AppKit "$project_dir/Sources/SystemDictionary.swift" "$project_dir/Sources/LocalLexicon.swift" "$project_dir/Sources/LanguageEngine.swift" "$project_dir/Sources/KeyboardTokenClassifier.swift" "$project_dir/Tests/StressAudit/main.swift" -o "$project_dir/build/stress-audit/audit"
KEYSWITCH_DISABLE_SYSTEM_DICTIONARY=1 "$project_dir/build/stress-audit/audit" fallback "$project_dir/Tests/StressAudit/cases.json" "$project_dir/build/stress-audit/fallback.json"
KEYSWITCH_DISABLE_SYSTEM_DICTIONARY=0 "$project_dir/build/stress-audit/audit" system "$project_dir/Tests/StressAudit/cases.json" "$project_dir/build/stress-audit/system.json"
