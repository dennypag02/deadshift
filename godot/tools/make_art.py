from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import random
out=Path(__file__).resolve().parent.parent/'art'
out.mkdir(exist_ok=True)
rng=random.Random(20261010)
def save(name,im): im.save(out/name)
def sprite(name,size,paint):
 im=Image.new('RGBA',size,(0,0,0,0)); d=ImageDraw.Draw(im); paint(d); save(name,im)
def road(d):
 d.rectangle((0,0,256,256),fill='#282c2d')
 for _ in range(160):
  x=rng.randrange(256);y=rng.randrange(256);v=rng.randrange(30,65);d.ellipse((x,y,x+2,y+2),fill=(v,v,v,70))
sprite('asphalt.png',(256,256),road)
sprite('sidewalk.png',(128,256),lambda d:(d.rectangle((0,0,128,256),fill='#686359'),[d.line((0,y,128,y),fill='#827b6b',width=2) for y in range(0,256,48)]))
sprite('lane.png',(24,96),lambda d:d.rounded_rectangle((4,4,20,90),radius=2,fill='#baa36c'))
def car(d,body,glass):
 d.ellipse((16,74,196,121),fill=(0,0,0,90))
 d.rounded_rectangle((12,38,196,107),radius=15,fill=body,outline='#161b1d',width=4)
 d.polygon([(45,42),(66,12),(142,12),(166,42)],fill=glass)
 d.line((105,14,105,42),fill='#111c20',width=4)
 for x in (36,172):
  d.ellipse((x-15,97,x+15,127),fill='#151717')
  d.ellipse((x-7,105,x+7,119),fill='#67645b')
 d.line((24,81,184,81),fill='#d1b69b',width=3)
for n,b,g in [('car_sedan.png','#81796a','#344b52'),('car_rust.png','#76533f','#283d42'),('car_olive.png','#536057','#31434a')]:
 sprite(n,(210,140),lambda d,b=b,g=g:car(d,b,g))
def facade(d,c):
 d.rounded_rectangle((4,4,252,318),radius=5,fill=c,outline='#282a29',width=7)
 for row in range(3):
  for col in range(3):
   x=26+col*77;y=27+row*86
   d.rectangle((x,y,x+46,y+58),fill='#25363a',outline='#aaa18b',width=4)
   d.line((x+23,y,x+23,y+58),fill='#74796e',width=2)
 d.rectangle((80,252,170,316),fill='#272e30',outline='#6c5a4b',width=5)
for n,c in [('building_01.png','#6e6055'),('building_02.png','#5d615b'),('building_03.png','#866b59')]:
 sprite(n,(256,324),lambda d,c=c:facade(d,c))
def debris(d):
 for _ in range(12):
  x=rng.randrange(10,112);y=rng.randrange(10,82);s=rng.randrange(3,17)
  d.polygon([(x,y),(x+s,y-2),(x+s+4,y+s//2),(x-2,y+s)],fill=rng.choice(['#5a5448','#817568','#343d3c','#716b5e']))
for n in range(3):sprite(f'debris_{n}.png',(128,96),debris)
def vignette():
 im=Image.new('RGBA',(432,960),(0,0,0,0));pix=im.load()
 for y in range(960):
  for x in range(432):
   nx=(x-216)/216;ny=(y-480)/480
   a=int(max(0,min(115,(nx*nx*.58+ny*ny*.55-.19)*135)))
   pix[x,y]=(8,10,13,a)
 save('vignette.png',im)
vignette()
