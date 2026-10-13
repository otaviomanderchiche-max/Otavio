from PIL import Image, ImageDraw, ImageOps, ImageFont
from pathlib import Path
root = Path(__file__).parent / 'src' / 'assets'
image = Image.open(root/'forest.jpg').convert('RGB')
icon = ImageOps.fit(image, (1024,1024), method=Image.Resampling.LANCZOS).convert('RGBA')
shade = Image.new('RGBA', (1024,1024), (1,38,19,88))
icon = Image.alpha_composite(icon, shade)
draw=ImageDraw.Draw(icon)
draw.rounded_rectangle((116,147,911,870),radius=200,fill=(7,59,34,90),outline=(255,255,255,165),width=9)
try:
    font = ImageFont.truetype('arialbd.ttf', 270)
    little = ImageFont.truetype('arialbd.ttf', 60)
except OSError:
    font = ImageFont.load_default()
    little = font
for text, size, y in [('EM',font,300),('EcoMonitor',little,630)]:
    box=draw.textbbox((0,0),text,font=size)
    draw.text(((1024-(box[2]-box[0]))/2,y),text,font=size,fill='white')
icon=icon.convert('RGBA')
icon.save(root/'ecomonitor.ico',format='ICO',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
print('Icone Windows criado:',root/'ecomonitor.ico')