from pathlib import Path
import hashlib
import subprocess
import shutil
import uuid

def archive_and_remove(bundle, archive, stamp, registration_tool, name=None):
    """Archive each generated app to its own verified ZIP before removing it."""
    bundle = Path(bundle)
    identity = hashlib.sha256(str(bundle.resolve()).encode()).hexdigest()[:10]
    prefix = name or bundle.stem
    output = Path(archive) / (prefix + '-' + stamp + '-' + identity + '-' + uuid.uuid4().hex[:8] + '.zip')
    # Reserve exclusively; an existing recovery archive is never overwritten.
    with output.open('xb'):
        pass
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(bundle), str(output)], check=True)
    subprocess.run(['/usr/bin/unzip', '-tq', str(output)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([registration_tool, '-u', str(bundle)], check=False, stdout=subprocess.DEVNULL)
    shutil.rmtree(bundle)
    return output
