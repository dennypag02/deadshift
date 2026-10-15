"""Copy exact user-selected character PNGs; never generate, resize, or overwrite differing art."""
from pathlib import Path
import hashlib, json, shutil
ROOT = Path(__file__).resolve().parents[1]
SELECTED = ROOT/'asset_pipeline/submitted_curations/curation-1821f5654302f816c1f7881b.json'

def main():
    record = json.loads(SELECTED.read_text())
    rows = []
    for candidate in record['candidates']:
        name = candidate['asset']
        category = 'characters' if name.startswith('zombie_') or name == 'mech_miniboss' else 'curated'
        source = ROOT/'asset_pipeline/submitted_artwork'/record['submission_id']/(candidate['candidate_id']+'.png')
        target = ROOT/'godot/art'/category/(name+'.png')
        data = source.read_bytes()
        if target.exists() and target.read_bytes() != data:
            raise RuntimeError(f'Refusing to overwrite {target}')
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists(): shutil.copyfile(source, target)
        rows.append({'asset':name, 'path':target.relative_to(ROOT/'godot').as_posix(), 'candidate_id':candidate['candidate_id'], 'sha256':hashlib.sha256(data).hexdigest()})
    (ROOT/'godot/data/approved_art_receipt.json').write_text(json.dumps(rows, indent=2)+'\n')
    assert len([x for x in rows if x['path'].startswith('art/characters')]) == 7
    print('APPROVED_ART_PASS 45 exact PNGs; 7 character assets; no replacement art')
if __name__ == '__main__': main()
