"""Deterministically bake the approved outlines once, not nine samples per actor/pixel.
The approved source PNGs remain byte-identical. No generation or model involved.
"""
from pathlib import Path
from PIL import Image, ImageFilter
import hashlib, json
R=Path(__file__).resolve().parents[1]
KINDS={'shambler':.65,'runner':.60,'spitter':.65,'elite':.845,'bloater':.975,'brute':.975,'mech_miniboss':.975}
atlas=Image.new('RGBA',(2048,1024)); rows={}
for n,(kind,ratio) in enumerate(KINDS.items()):
    source=R/'godot/art/characters'/((kind if kind=='mech_miniboss' else 'zombie_'+kind)+'.png')
    im=Image.open(source).convert('RGBA'); w,h=im.size
    radius=max(1,round(1.5*h/(96*ratio))); pad=radius+2
    canvas=Image.new('RGBA',(w+pad*2,h+pad*2)); canvas.paste(im,(pad,pad))
    a=canvas.getchannel('A'); ring=a.filter(ImageFilter.MaxFilter(2*radius+1))
    inside=a.filter(ImageFilter.MinFilter(2*radius+1))
    import numpy as np
    pixels=np.array(canvas); fringe=((np.array(inside)/255)<.05)&(pixels[:,:,:3].min(axis=2)>=204)
    pixels[fringe,:3]=[14,12,9]
    canvas=Image.fromarray(pixels)
    outline=Image.new('RGBA',canvas.size,(14,12,9,255)); outline.putalpha(ring)
    result=Image.alpha_composite(outline,canvas)
    x,y=(n%4)*512,(n//4)*512
    atlas.paste(result,(x,y))
    rows[kind]={'uv':[x/2048,y/1024,result.width/2048,result.height/1024], 'size':[result.width*96*ratio/h,result.height*96*ratio/h], 'body_width':w*96*ratio/h,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
out=R/'godot/art/runtime';out.mkdir(exist_ok=True)
atlas.save(out/'actors_atlas.png')
(out/'actors_atlas.json').write_text(json.dumps(rows,indent=2)+'\n')
print('ATLAS_BUILT',len(rows),'exact-source derivatives, no source overwritten')
