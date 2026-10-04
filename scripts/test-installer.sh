#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
fixture="$(mktemp -d /private/tmp/keyswitch-installer-test.XXXXXX)"
trap 'rm -rf "$fixture"' EXIT
apps="$fixture/Applications"
mkdir -p "$apps"
ditto "$project_dir/build/KeySwitch.app" "$apps/KeySwitch.app"
for name in 'KeySwitch 2' 'Other App' 'KeySwitch unrelated'; do
    mkdir -p "$apps/$name.app/Contents"
    cp "$project_dir/Resources/Info.plist" "$apps/$name.app/Contents/Info.plist"
done
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier other.app' "$apps/KeySwitch unrelated.app/Contents/Info.plist"
ln -s 'Other App.app' "$apps/Shortcut.app"
# Exercise the live-volume branch with isolated process and application fixtures.
# No real processes or /Applications entries are touched.
python3 - "$project_dir" "$fixture" <<'PYTEST'
from pathlib import Path
import subprocess
import sys
project, fixture = map(Path, sys.argv[1:])
mock_ps = fixture / 'process-list'
mock_ps.write_text('#!/bin/bash\ncat "$KEYSWITCH_TEST_PS"\n')
mock_ps.chmod(0o755)
original = (project / 'scripts/installer/preinstall').read_text()
copy = original.replace('/bin/ps -axo pid=,comm=', str(mock_ps))
copy = copy.replace("app='/Applications/KeySwitch.app'", f"app='{fixture}/Applications/KeySwitch.app'")
script = fixture / 'preinstall'
script.write_text(copy)
listing = fixture / 'processes.txt'
import os
env = dict(os.environ, KEYSWITCH_TEST_PS=str(listing))
for label, processes in [
    ('no processes', ''),
    ('unrelated process', '2147483647 /usr/bin/unrelated\n'),
    ('already exited KeySwitch', f'2147483647 {fixture}/Applications/KeySwitch.app/Contents/MacOS/KeySwitch\n'),
]:
    listing.write_text(processes)
    result = subprocess.run(['/bin/bash', str(script), 'ignored', 'ignored', '/'], env=env, capture_output=True, text=True)
    assert result.returncode == 0, (label, result.stderr)
    print(f'Preinstall regression: {label}: OK')
first_install = fixture / 'first-preinstall'
first_install.write_text(copy.replace(str(fixture / 'Applications/KeySwitch.app'), str(fixture / 'Applications/New KeySwitch.app')))
listing.write_text('')
result = subprocess.run(['/bin/bash', str(first_install), 'ignored', 'ignored', '/'], env=env, capture_output=True, text=True)
assert result.returncode == 0, result.stderr
print('Preinstall regression: first installation: OK')
# Stop a disposable running process through the same verified-bundle branch.
child = subprocess.Popen(['/bin/sleep', '30'])
import threading
reaper = threading.Thread(target=child.wait, daemon=True)
reaper.start()
try:
    listing.write_text(f'{child.pid} {fixture}/Applications/KeySwitch.app/Contents/MacOS/KeySwitch\n')
    result = subprocess.run(['/bin/bash', str(script), 'ignored', 'ignored', '/'], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert child.wait(timeout=2) != 0, 'Running fixture was not stopped'
    print('Preinstall regression: running instance stopped: OK')
finally:
    if child.poll() is None:
        child.terminate()
        child.wait(timeout=2)
# An unrelated bundle at the canonical path must still block replacement.
guard_script = fixture / 'guard-preinstall'
guard_script.write_text(copy.replace(str(fixture / 'Applications/KeySwitch.app'), str(fixture / 'Applications/KeySwitch unrelated.app')))
listing.write_text('')
result = subprocess.run(['/bin/bash', str(guard_script), 'ignored', 'ignored', '/'], env=env, capture_output=True, text=True)
assert result.returncode != 0, 'Unrelated canonical app was allowed'
print('Preinstall regression: unrelated canonical app blocked: OK')
PYTEST
/bin/bash "$project_dir/scripts/installer/preinstall" ignored ignored "$fixture"
/bin/bash "$project_dir/scripts/installer/postinstall" ignored ignored "$fixture"
[[ -d "$apps/KeySwitch.app" ]]
[[ ! -e "$apps/KeySwitch 2.app" && ! -e "$apps/Other App.app" ]]
[[ -d "$apps/KeySwitch unrelated.app" && -L "$apps/Shortcut.app" ]]
echo 'Installer cleanup tests: OK (verified identifiers, unrelated app and symlink preserved)'

python3 "$project_dir/Tests/InstallDownloadFixtures.py"
