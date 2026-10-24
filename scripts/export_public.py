#!/usr/bin/env python3
"""Export the complete publishable source tree, excluding local development history/data."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = ['README.md', 'README.en.md', 'Package.swift', 'LICENSE', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md', '.gitignore', '.gitattributes']
DIRECTORIES = ['Sources', 'Tests', 'Resources', 'scripts', '.github']
DOCS = ['ARCHITECTURE.md', 'DEVELOPMENT.md', 'PRIVACY.md']

def export(destination):
    destination = Path(destination).resolve()
    if destination.exists(): raise FileExistsError('Choose a new export directory; existing files are not overwritten.')
    files = []
    for name in ROOT_FILES:
        if (ROOT / name).is_file(): files.append(ROOT / name)
    for directory in DIRECTORIES:
        files.extend(p for p in (ROOT / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store')
    files.extend(ROOT / 'docs' / name for name in DOCS)
    if (ROOT / 'docs/assets').exists(): files.extend(p for p in (ROOT / 'docs/assets').rglob('*') if p.is_file())
    suspicious = re.compile(rb'/Users/|/home/|github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----')
    for file in files:
        if file.suffix in {'.swift', '.py', '.sh', '.md', '.yml', '.yaml', '.json', '.plist'} and file.name != 'export_public.py':
            if suspicious.search(file.read_bytes()): raise ValueError('Potential private data in ' + str(file.relative_to(ROOT)))
    destination.mkdir(parents=True)
    manifest = {}
    for file in sorted(set(files)):
        relative = file.relative_to(ROOT)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)
        manifest[str(relative)] = hashlib.sha256(target.read_bytes()).hexdigest()
    (destination / 'SOURCE_MANIFEST.json').write_text(json.dumps({'version': '1.2.0', 'files': manifest}, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    print(json.dumps({'directory': str(destination), 'files': len(manifest)}, ensure_ascii=False))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('destination')
    export(parser.parse_args().destination)
