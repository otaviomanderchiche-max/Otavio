from PIL import Image,ImageOps,ImageDraw,ImageFont
from pathlib import Path
import sys
base=Path(sys.argv[1])
image=Image.open(base/'assets'/'forest.jpg').convert('RGB')
photo=ImageOps.fit(image,(1024,1024),Image.Resampling.LANCZOS).convert('RGBA')
tint=Image.new('RGBA',(1024,1024),(4,38,24,92))
photo=Image.alpha_composite(photo,tint)
draw=ImageDraw.Draw(photo)
draw.rounded_rectangle((112,150,912,876),radius=198,fill=(0,55,25,90),outline=(255,255,255,180),width=9)
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',240)
s=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',62)
for txt,ft,y in [('EM',f,310),('EcoMonitor',s,620)]:
    b=draw.textbbox((0,0),txt,font=ft)
    draw.text(((1024-b[2]+b[0])/2,y),txt,font=ft,fill='white')
for scale,sz in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    output=base/'android'/'app'/'src'/'main'/'res'/('mipmap-'+scale)
    output.mkdir(parents=True,exist_ok=True)
    img=photo.resize((sz,sz),Image.Resampling.LANCZOS).convert('RGB')
    img.save(output/'ic_launcher_custom.png')
    img.save(output/'ic_launcher_custom_round.png')
print('EcoMonitor: icone de floresta criado')
