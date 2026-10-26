"""Exercise the shipped installer with isolated release, download and install failures."""
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/install.sh"
with tempfile.TemporaryDirectory(prefix="keyswitch-download-", dir="/private/tmp") as temporary:
    root = Path(temporary)
    for name, body in {
        "curl": """#!/usr/bin/env python3
import os, sys
from pathlib import Path
assert not any('api.github.com' in arg for arg in sys.argv)
if '--write-out' in sys.argv:
 print(os.environ['FIXTURE_URL'], end='')
else:
 version=os.environ['FIXTURE_VERSION']
 assert sys.argv[-1] == f'https://github.com/Andrles/KeySwitch/releases/download/v{version}/KeySwitch-{version}.pkg'
 if os.environ['FIXTURE_MODE'] == 'missing_package': sys.exit(22)
 target=Path(sys.argv[sys.argv.index('--output')+1])
 target.write_text('fixture package')
 Path(os.environ['FIXTURE_PACKAGE']).write_text(str(target))
""",
        "sudo": """#!/bin/zsh
[[ -f $3 ]] || exit 1
[[ "$FIXTURE_MODE" != install_failure ]] || exit 1
print installed > "$FIXTURE_RESULT"
""",
        "open": "#!/bin/zsh\nprint opened > \"$FIXTURE_OPEN\"\n",
    }.items():
        target = root / name
        target.write_text(body)
        target.chmod(0o755)
    result, opened, package = (root / name for name in ['installed', 'opened', 'package-path'])
    environment = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       FIXTURE_RESULT=str(result), FIXTURE_OPEN=str(opened), FIXTURE_PACKAGE=str(package))
    for version, mode in [('3.2.0', 'success'), ('3.5.1', 'success'),
                          ('3.5.1', 'missing_package'), ('3.5.1', 'install_failure'),
                          ('3.5.1', 'wrong_host'), ('3.5.1', 'invalid_tag')]:
        for path in [result, opened, package]: path.unlink(missing_ok=True)
        url = f'https://github.com/Andrles/KeySwitch/releases/tag/v{version}'
        if mode == 'wrong_host': url = 'https://example.invalid/releases/tag/v3.5.1'
        if mode == 'invalid_tag': url += '/unexpected'
        run = subprocess.run(['/bin/zsh', str(script)], env=dict(environment,
            FIXTURE_URL=url, FIXTURE_MODE=mode, FIXTURE_VERSION=version), capture_output=True, text=True)
        succeeds = mode == 'success'
        assert (run.returncode == 0) == succeeds, (version, mode, run.stdout, run.stderr)
        assert result.exists() == succeeds and opened.exists() == succeeds, (version, mode)
        if package.exists():
            assert not Path(package.read_text()).parent.exists(), 'Temporary package directory not removed'
        print(f'Installer download: {version} / {mode}: OK')
