"""Verify authorized starter/tuning changes while preserving all other art/combat difficulty."""
from pathlib import Path
import subprocess, json, hashlib
R=Path(__file__).resolve().parents[1]
base='18fb452444978f09dba7c7335c4bb4ca1281d2b5'
try: old=json.loads(subprocess.check_output(['git','show',base+':godot/data/phase_a.json'],cwd=R,stderr=subprocess.DEVNULL))
except subprocess.CalledProcessError: old=json.loads(subprocess.check_output(['git','show','HEAD:godot/data/phase_a.json'],cwd=R))
new=json.loads((R/'godot/data/phase_a.json').read_text())

# The only newly authorized opening-combat data is run.starting_weapon plus
# Boomstick's own starter-feel fields. Enemy pressure/damage and every other
# weapon/passive remain frozen by this contract.
assert new.get('run',{}).get('starting_weapon')=='boomstick', 'Starting weapon must be Boomstick'
for key in old:
    if key in ('xp','pacing','limits','weapons'):
        continue
    assert new[key]==old[key], 'Unauthorized gameplay change: '+key
for weapon_id, old_weapon in old['weapons'].items():
    assert weapon_id in new['weapons'], 'Missing weapon: '+weapon_id
    if weapon_id!='boomstick':
        assert new['weapons'][weapon_id]==old_weapon, 'Unauthorized weapon change: '+weapon_id
allowed_boomstick={'description','base_pellets','base_damage','base_knockback','base_cone_step','base_fire_period','base_range_pixels','aim_assist_degrees'}
for key,value in old['weapons']['boomstick'].items():
    if key not in allowed_boomstick:
        assert new['weapons']['boomstick'].get(key)==value, 'Unauthorized Boomstick progression change: '+key
assert 5<=int(new['weapons']['boomstick']['base_pellets'])<=6
assert 0.8<=float(new['weapons']['boomstick']['base_fire_period'])<=1.0
spread=float(new['weapons']['boomstick']['base_cone_step'])*(int(new['weapons']['boomstick']['base_pellets'])-1)
assert 0.45<=spread<=0.60, 'Boomstick spread no longer about 30 degrees'
assert 40<=float(new['weapons']['boomstick']['aim_assist_degrees'])<=50

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
print('MOBILE_CONTRACT_PASS: 45 approved originals unchanged; non-Boomstick combat/spawns unchanged; data-driven Boomstick starter authorized')
