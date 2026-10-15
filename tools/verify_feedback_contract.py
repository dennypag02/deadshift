"""Offline evidence checks; no claimed Android device performance."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
base='30d13cd4435911dfca2a80ab669b61cc905546b2'
try:
    prior=json.loads(subprocess.check_output(['git','show',base+':godot/data/phase_a.json'],cwd=ROOT,stderr=subprocess.DEVNULL))
except subprocess.CalledProcessError:
    prior=json.loads(subprocess.check_output(['git','show','HEAD:godot/data/phase_a.json'],cwd=ROOT,stderr=subprocess.DEVNULL))
current=json.loads((ROOT/'godot/data/phase_a.json').read_text())
assert current['xp'].pop('collection_multiplier')==0.60
assert current==prior, 'Difficulty configuration changed outside XP collection multiplier'
rows=json.loads((ROOT/'godot/data/approved_art_receipt.json').read_text())
assert len(rows)==45
for row in rows:
    path=ROOT/'godot'/row['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'], row['asset']
assert len([r for r in rows if r['path'].startswith('art/characters/')])==7
source=(ROOT/'godot/scripts/outskirts.gd').read_text()
assert '"trucker": "res://art/curated/zombie_elite.png"' not in source
assert 'WAVE 1: THE HORDE IS HERE' not in source
assert 'player_hp = 100\n\t\t\tplayer_hit_invulnerability' not in source
print('FEEDBACK_CONTRACT_PASS: 45 exact selected PNGs; all enemy combat/density settings unchanged; XP-only balance adjustment')
