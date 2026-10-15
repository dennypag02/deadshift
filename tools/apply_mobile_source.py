"""Apply the exact locally validated performance source; fail on any mismatch."""
from pathlib import Path
import base64
import hashlib
import lzma
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PART_HASHES = [
    '121a587104c543b37c86d8149c5bb270f620bc25c6297596f1f2e9e804b3cb4e',
    '5bba7f80a1ded64388b1a12468625596f5c1438e0d7107cbb6618058eca1bbc3',
    '91e97a0a28a657dd09e8f9daccd23c5e1f0b6e23a3ea61598ef32e33bd455e77',
]
parts = []
for index, expected in enumerate(PART_HASHES, 1):
    text = (ROOT / 'tools' / f'mobile_source_{index:02d}.b64').read_text(encoding='ascii').strip()
    actual = hashlib.sha256(text.encode('ascii')).hexdigest()
    if actual != expected:
        raise ValueError(f'Source transfer part {index} mismatch: {actual}')
    parts.append(text)
patch = lzma.decompress(base64.b64decode(''.join(parts), validate=True))
expected = '3c066c03b10ef4c327a1f789791b42638a9b6945622debd678d9c10389f734ee'
if hashlib.sha256(patch).hexdigest() != expected:
    raise ValueError('Validated source patch digest mismatch')
subprocess.run(['git', 'apply', '--check', '-'], input=patch, cwd=ROOT, check=True)
subprocess.run(['git', 'apply', '-'], input=patch, cwd=ROOT, check=True)
print('MOBILE_TESTED_SOURCE_APPLIED sha256=' + expected)
