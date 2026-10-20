# Isolated WebKit replacement lab

This is a native test application, not an installer or production mode. It owns three local HTML fields: a plain input, an input whose state is updated on `input`, and a contenteditable message editor. It loads no external pages, installs no event tap. The AX suite never selects an input source; the separate, explicit “Подготовить ввод — English” button selects English and clears/focuses its own plain field for keyboard testing. AX writes are restricted to its own process. It uses the production `AXSuffixEditor` and `SuffixReplacement`.

Build with `/bin/zsh scripts/build-browser-lab.sh`. Run `build/browser-replacement/BrowserLab.app/Contents/MacOS/BrowserLab build/browser-replacement/results.json` from the repository root, then click the test button in its window. The output includes the AX outcome and DOM snapshots immediately after the operation, after 150 ms, and after an explicit controlled-state rerender. Those fixture timings are observations, not a proposed production delay.

Accessibility permission must already be available; the lab never prompts for or grants it. Missing permission/focus is a setup failure, not a passing replacement test. On the first run, the plain input's self-process AX query can report `cannotComplete` (-25204) while the other fields proceed. Rerun using the button after initialization, and require all three rows to contain actual transaction results. Input-source APIs and the production context checks run on the main queue; moving these Carbon calls to a background queue crashed the initial fixture on this macOS.

## Reproduced on 20 October 2026

Before the fix, a WebKit AX write could report success while the DOM retained the original `lbhtrnjh`. `SuffixReplacement` returned `unverified`, but left the original selected. A following Space key sent through the computer-use tool replaced the entire word. This reproduced a deletion mechanism independently of language detection or source switching.

After restoring the caret on an exact unchanged original, all three initialized fields retained `lbhtrnjh` without a dangerous selection. In the contenteditable field a following Space preserved the word as `lbhtrnjh `.

This is a safe refusal, **not successful layout correction**. It does not reproduce Safari's native address bar or establish the cause of `lbректор`. The AX suite itself uses no keyboard event tap, and its separator check used tool-generated input rather than a physical keyboard. Component tests and this lab do not establish compatibility with every browser/editor.

Local evidence: `build/browser-replacement/before-fix.json` and `after-fix.json`. These generated artifacts are ignored by Git. The rejected automatic AX path remains removed. For a separate keyboard-path check, run KeySwitch with `--runtime-browser-check --input-diagnostics`: its target is fixed to this lab, with isolated preferences. Stop the normal instance first, and stop the diagnostic instance and restore the installed normal app when finished. Other applications are intentionally excluded during this check. Tool-generated keypresses produced `lbhtrnjh ` without a replacement receipt; that is not evidence that physical input was processed by the monitor. The lab does not cover Safari’s upper address/search bar.

Physical keyboard follow-up: the user typed `lbhtrnjh` + Space in the plain input and confirmed `директор`. Diagnostic receipt 1 recorded preflight, posting, source confirmation, and matching readbacks at 20/80/200 ms. The restricted monitor and lab were then stopped; the current build was started in normal mode with read-only diagnostics. This result does not cover Safari’s native address bar.
