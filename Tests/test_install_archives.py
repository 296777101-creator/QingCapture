import importlib.util
from pathlib import Path
import tempfile
import unittest
import subprocess
spec = importlib.util.spec_from_file_location('install_helpers', Path(__file__).resolve().parents[1] / 'scripts/install_helpers.py')
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
class ArchiveTests(unittest.TestCase):
    def test_same_named_apps_are_both_recoverable(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            archive = root / 'archive'
            archive.mkdir()
            for location, content in [('first', 'first version'), ('second', 'second version')]:
                bundle = root / location / '轻截.app'
                bundle.mkdir(parents=True)
                (bundle / 'payload.txt').write_text(content)
                helpers.archive_and_remove(bundle, archive, 'same-time', '/usr/bin/true')
                self.assertFalse(bundle.exists())
            archives = list(archive.glob('*.zip'))
            self.assertEqual(len(archives), 2)
            recovered = []
            for index, item in enumerate(archives):
                target = root / ('recovered-' + str(index))
                subprocess.run(['/usr/bin/ditto', '-x', '-k', str(item), str(target)], check=True)
                recovered.append((target / '轻截.app/payload.txt').read_text())
            self.assertEqual(set(recovered), {'first version', 'second version'})
if __name__ == '__main__': unittest.main()
