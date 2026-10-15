"""Apply the reviewed Stage 2 delta; validate all inputs before writing any file.

The legacy stage2_source_01.b64 is intentionally NOT used. The three v2
transport chunks contain line edits plus before/after SHA-256 for 14 files.
The resulting source is committed normally and remains the source of truth.
No art, fonts, checkpoints, collision footprints, or core tuning is changed.
"""
from pathlib import Path
import base64
import hashlib
import json
import lzma

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = 'cf08e3dc67996fd2e7cddbab2e80557bdd1e053942f477655698aa0a86cef3cb'
ALLOWED = {
    'godot/scripts/feedback_tests.gd',
    'godot/scripts/objective_guidance.gd',
    'godot/scripts/outskirts.gd',
    'godot/scripts/pacing_telemetry.gd',
    'godot/scripts/performance_capture.gd',
    'godot/scripts/performance_tests.gd',
    'godot/scripts/polish_hud.gd',
    'godot/scripts/survivability_ui_check.gd',
    'godot/data/stage2_events.json',
    'godot/scripts/stage2_events.gd',
    'godot/scripts/run_telemetry.gd',
    'godot/scripts/event_countdown.gd',
    'godot/scripts/stage2_tests.gd',
    'godot/scripts/stage2_visual_check.gd',
}

def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()

def main() -> None:
    encoded = ''.join((ROOT / f'tools/stage2_patch_v2_{i:02}.b64').read_text().strip() for i in range(1, 4))
    assert digest(encoded.encode()) == EXPECTED, 'Transfer checksum mismatch; no source changed'
    raw = lzma.decompress(base64.b64decode(encoded, validate=True))
    assert len(raw) < 100000, 'Unexpected payload size'
    payload = json.loads(raw)
    assert set(payload) == ALLOWED, 'Unexpected source path set'
    pending = {}
    receipt = {}
    for name, delta in payload.items():
        target = ROOT / name
        original = target.read_bytes() if target.exists() else b''
        if digest(original) == delta['result']:
            receipt[name] = delta['result']
            continue
        assert digest(original) == delta['base'], f'Source has changed: {name}; inspect before retrying'
        lines = original.decode('utf-8').splitlines(keepends=True)
        previous_end = 0
        for start, end, replacement in delta['edits']:
            assert 0 <= previous_end <= start <= end <= len(lines), name
            assert isinstance(replacement, str), name
            previous_end = end
        for start, end, replacement in reversed(delta['edits']):
            lines[start:end] = replacement.splitlines(keepends=True)
        result = ''.join(lines).encode('utf-8')
        assert digest(result) == delta['result'], f'Result checksum mismatch: {name}'
        pending[target] = result
        receipt[name] = delta['result']
    for target, content in pending.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    evidence = ROOT / 'stage2-evidence'
    evidence.mkdir(exist_ok=True)
    (evidence / 'applied-source-hashes.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'STAGE2_SOURCE_VERIFIED files={len(receipt)} changed={len(pending)} payload_sha256={EXPECTED}')

if __name__ == '__main__':
    main()
