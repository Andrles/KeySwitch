"""Run the shipped installer under zsh with isolated network/install fixtures."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/install.sh"
with tempfile.TemporaryDirectory(prefix="keyswitch-download-", dir="/private/tmp") as temporary:
    root = Path(temporary)
    for name, body in {
        "curl": """#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
if 'api.github.com' in sys.argv[-1]:
 print(Path(os.environ['FIXTURE_RELEASE']).read_text())
else:
 Path(sys.argv[sys.argv.index('--output')+1]).write_text('fixture package')
""",
        "sudo": "#!/bin/zsh\n[[ -f $3 ]] || exit 1\nprint installed > \"$FIXTURE_RESULT\"\n",
        "open": "#!/bin/zsh\nexit 0\n",
    }.items():
        target = root / name
        target.write_text(body)
        target.chmod(0o755)
    release = root / "release.json"
    result = root / "installed"
    environment = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       FIXTURE_RELEASE=str(release), FIXTURE_RESULT=str(result))
    for label, assets, succeeds in [
        ("versioned package after ZIP", [
            {"name": "KeySwitch-3.2.0.zip", "browser_download_url": "https://example.invalid/zip"},
            {"name": "KeySwitch-3.2.0.pkg", "browser_download_url": "https://github.com/Andrles/KeySwitch/releases/download/v3.2.0/KeySwitch-3.2.0.pkg"}], True),
        ("legacy stable package", [{"name": "KeySwitch.pkg", "browser_download_url": "https://github.com/Andrles/KeySwitch/releases/download/v3.0.0/KeySwitch.pkg"}], True),
        ("no installer", [], False),
        ("unexpected download host", [{"name": "KeySwitch.pkg", "browser_download_url": "https://example.invalid/KeySwitch.pkg"}], False),
    ]:
        result.unlink(missing_ok=True)
        release.write_text(json.dumps({"assets": assets}))
        run = subprocess.run(["/bin/zsh", str(script)], env=environment, capture_output=True, text=True)
        assert (run.returncode == 0) == succeeds, (label, run.stdout, run.stderr)
        assert result.exists() == succeeds, label
        print(f"Installer download: {label}: OK")
