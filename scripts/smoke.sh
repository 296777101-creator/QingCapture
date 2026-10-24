#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
'build/Artifacts.noindex/轻截.app/Contents/MacOS/QingCapture' --smoke-test "$PWD/build/smoke.json"
python3 - <<'PY'
import json
from pathlib import Path
report=json.loads(Path('build/smoke.json').read_text())
for name, passed in report['checks'].items():
    print(('PASS ' if passed else 'FAIL ') + name)
assert report['passed'], 'Integration checks failed'
print(str(len(report['checks'])) + ' integration checks passed')
PY
