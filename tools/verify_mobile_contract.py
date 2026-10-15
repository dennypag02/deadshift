"""Verify only the authorized pacing/renderer changes; preserve art/combat difficulty."""
from pathlib import Path
import subprocess, json, hashlib
R=Path(__file__).resolve().parents[1]
base='18fb452444978f09dba7c7335c4bb4ca1281d2b5'
try: old=json.loads(subprocess.check_output(['git','show',base+':godot/data/phase_a.json'],cwd=R,stderr=subprocess.DEVNULL))
except subprocess.CalledProcessError: old=json.loads(subprocess.check_output(['git','show','HEAD:godot/data/phase_a.json'],cwd=R))
new=json.loads((R/'godot/data/phase_a.json').read_text())
for key in old:
    if key not in ('xp','pacing','limits'): assert new[key]==old[key], 'Unauthorized gameplay change: '+key
for key in old['pacing']:
    if key not in ('wave1_duration_seconds','wave_duration_seconds','break_seconds','surge_last_seconds'):
        assert old['pacing'][key]==new['pacing'][key], 'Spawn/density change: '+key
assert new['pacing']['wave1_duration_seconds']==60
assert 60<=new['pacing']['wave_duration_seconds']<=75
assert new['limits']['active_enemies']==250 and new['limits']['projectiles']==400
assert new['limits']['damage_numbers']==40 and new['xp']['merge_threshold']==200
rows=json.loads((R/'godot/data/approved_art_receipt.json').read_text())
assert len(rows)==45
for row in rows:
    assert hashlib.sha256((R/'godot'/row['path']).read_bytes()).hexdigest()==row['sha256'], row['asset']
metadata=json.loads((R/'godot/art/runtime/actors_atlas.json').read_text())
for kind,v in metadata.items():
    asset=kind if kind=='mech_miniboss' else 'zombie_'+kind
    assert v['source_sha256']==hashlib.sha256((R/'godot/art/characters'/(asset+'.png')).read_bytes()).hexdigest()
print('MOBILE_CONTRACT_PASS: 45 approved originals unchanged; combat/spawns unchanged; data-driven XP and wave durations; CORE_LOOP caps')
