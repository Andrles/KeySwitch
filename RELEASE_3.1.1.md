# KeySwitch 3.1.1 — verification and delivery

2026-10-03. This update includes the previously reviewed macOS UI, window/accessibility/installer fixes and the spelling/layout safeguards from the stress audit. Voice, AI and other platforms remain in ROADMAP.md.

## Behavior

Correct vocabulary and known names take priority over layout guesses. Layout conversion no longer approximates names and preserves brand spelling/case instead of expanding identifiers. Model recognition is restricted to X/Q/CX/GLE families; ordinary Russian abbreviations and numbers are protected. A local offline vocabulary supplements macOS dictionaries.

Automatic spelling applies curated common typo fixes only. Ambiguous guesses are shown as suggestions, including in automatic mode. Double Shift accepts a suggestion or restores a recent automatic correction. Case-neutral suggestion caching preserves the case of each new request. Shared punctuation parsing handles quotes/brackets; Tab completes a word. Technical separators, drive prefixes and identifiers are conservative. Unicode event extraction rejects an oversized reported length.

## Verification

- Existing language, preferences, context/suffix, retry and replacement-plan tests: passed.
- New strict regressions: passed with system dictionaries disabled and enabled. Cases include Chen/Petr, ещё/из-за, Russian model abbreviations, correct names/terms, park/dark/aria, quoted typos, ambiguous guesses and fresh request capitalization.
- Expanded audit: 12,936 scenarios/observations per mode; preserved 4,346/4,346 supplied correct tokens, 728/728 spellings, 3,000/3,000 sampled English words and 6/6 correct phrases in both modes. Keyboard stream model: 141/141 with explicit conservative slash/@ expectations. Mapping roundtrip: 3,000/3,000 per mode; long-input cases: 16/16.
- Exact layout restoration: 1,466/1,658 offline; 1,594/1,658 with system dictionaries. Remaining mismatches are left unchanged for language collisions, identifiers, foreign characters, punctuation-only/mixed tokens or unsupported lexical candidates. These are not silently approximated. Full recognition of arbitrary words is not claimed.
- Actual executable: window created, hide/menu reopen and Dock mode toggle passed. The local UI example produced `зфкл → park` and left `Chen` unchanged. The final packaged executable passed its launch/reopen check.
- Installer fixtures under Bash 3.2: first install, upgrade/cleanup, no process, unrelated process, exited process, running process, unrelated canonical bundle and symlink preservation passed. Preferences and accessibility permissions are not deleted.
- PKG expanded: version 3.1.1/build 31, install location /Applications, x86_64 + arm64, strict bundle signature verification, embedded scripts equal source.
- Build/package shell syntax and Git whitespace checks: passed. Package creation compares a source fingerprint and rebuilds a stale application.

## Limits

Input decisions and token flow were tested with production engine/classifier and a stream model. Global keyboard delivery, fast typing/caret races and double Shift across external editors were not verified in this run: the preview copy had no Accessibility permission. No permission was granted or reset. The launch diagnostic disables input monitoring/network and is not proof of global interception.

Intel code compiled, but Intel hardware was not exercised. The local Command Line Tools linker warned that its compatibility archive lacks x86_64; the final universal executable was produced, signed and inspected. Arm64 launch passed. An isolated full OS installation was unavailable; installer fixtures and payload checks are not a full macOS installation test.

Signing is ad-hoc; no Developer ID identity was available and the package is not notarized. A new binary may need Accessibility reauthorization. GitHub source publication uses the authorized connector; browser policy prevented accessing the release form, so no GitHub Release or release asset upload is claimed.

## Artifact

`build/KeySwitch-3.1.1.pkg`

SHA-256: `e979f31b56ba0f7d78461e70cf22a65291d4c4ec448b614db45df964b54be7d4`.

The installer replaces the identified KeySwitch app and removes same-bundle-ID duplicates under Applications. It preserves preferences and unrelated apps. Run the installer, then open KeySwitch from Applications. If macOS asks for Accessibility again, authorize that installed copy.
