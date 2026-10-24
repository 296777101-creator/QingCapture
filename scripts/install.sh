#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
python3 - <<'PY'
from pathlib import Path
import shutil, datetime, os, subprocess, plistlib, signal, time, re
from scripts.install_helpers import archive_and_remove as archive_saved_bundle
root = Path.cwd()
source = root / 'build/Artifacts.noindex/轻截.app'
destination = Path('/Applications/轻截.app')
desktop = Path.home() / 'Desktop/轻截.app'
lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
archive = root / 'build/Archives.noindex'
archive.mkdir(parents=True, exist_ok=True)
def is_ours(bundle):
    try:
        with (bundle / 'Contents/Info.plist').open('rb') as file:
            return plistlib.load(file).get('CFBundleIdentifier') == 'local.qingcapture.app'
    except (OSError, ValueError): return False
# Stop only this application's executables, including historical build copies.
for line in subprocess.check_output(['ps','-axo','pid=,comm='], text=True).splitlines():
    parts = line.strip().split(None, 1)
    if len(parts) != 2: continue
    binary = Path(parts[1]).resolve()
    if binary.name == 'QingCapture' and is_ours(binary.parent.parent.parent):
        os.kill(int(parts[0]), signal.SIGTERM)
time.sleep(0.3)
def archive_and_remove(bundle, name):
    return archive_saved_bundle(bundle, archive, stamp, lsregister, name=name)

if destination.exists():
    if not is_ours(destination): raise SystemExit('安装目标属于其他应用，未覆盖。')
    archive_and_remove(destination, '轻截-installed')
shutil.copytree(source, destination, symlinks=True)
subprocess.run(['/usr/bin/codesign','--verify','--strict',str(destination)], check=True)
# Old developer applications are the source of duplicate App search entries.
for bundle in sorted((root / 'build').rglob('*.app')):
    if bundle == source or not is_ours(bundle): continue
    archive_and_remove(bundle, '轻截-legacy-' + bundle.stem)
archive_and_remove(source, '轻截-release')
if desktop.is_symlink() and desktop.resolve() == destination: pass
elif not desktop.exists() and not desktop.is_symlink(): os.symlink(destination, desktop)
else: raise SystemExit('应用已安装；桌面存在其他同名文件，未覆盖。')
# Other copies may be attachments or user archives outside this project.
# Preserve their files and unregister only their duplicate application entries.
dump = subprocess.check_output([lsregister, '-dump'], text=True)
for block in dump.split('--------------------------------------------------------------------------------'):
    if not re.search(r'^identifier:\s+local\.qingcapture\.app\s*$', block, re.M): continue
    match = re.search(r'^path:\s+(.+?)\s+\(0x', block, re.M)
    if match and Path(match.group(1)).resolve() != destination:
        subprocess.run([lsregister, '-u', match.group(1)], check=True)
subprocess.run([lsregister, '-f', str(destination)], check=True)
print('已安装：' + str(destination))
print('桌面入口：' + str(desktop))
print('旧版本与构建产物已压缩归档，不再保留可搜索的开发应用。')
PY
codesign --verify --strict '/Applications/轻截.app'
