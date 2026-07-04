"""
icotool shim - creates .ico files from PNGs using Pillow.
Usage (mirrors icotool): icotool-shim.py -c -o output.ico [-r hires.png] input1.png input2.png ...

Wichtig: Pillow's ICO-Writer skaliert beim Schreiben mehrerer Groessen IMMER vom
Basisbild (erstes Bild) herunter und ignoriert dabei die in append_images
uebergebenen Bilder fuer's Resizing. Daher MUSS das hochaufgeloesteste Bild als
Basisbild verwendet werden - sonst werden alle Groessen aus einer kleinen
Vorlage hochskaliert -> verpixelt.
"""
import sys
from PIL import Image

output = None
inputs = []
hires = None  # -r <file>: high-res source (z.B. 1024px)

args = sys.argv[1:]
i = 0
while i < len(args):
    arg = args[i]
    if arg in ('-c', '--create'):
        pass
    elif arg in ('-r', '--raw'):
        i += 1
        hires = args[i]
    elif arg in ('-o', '--output'):
        i += 1
        output = args[i]
    else:
        inputs.append(arg)
    i += 1

if not output or not inputs:
    print("Usage: icotool-shim.py -c -o output.ico [-r hires.png] input.png ...", file=sys.stderr)
    sys.exit(1)

# Standard-ICO-Groessen (Windows Explorer nutzt u.a. 16/32/48/256)
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

# Hoechstaufgeloeste verfuegbare Quelle ermitteln und als Basis nehmen,
# damit Pillow von DORT herunterskaliert statt von einem kleinen Input hochzuskalieren.
print(f"icotool-shim: output={output}", file=sys.stderr)
candidates = []
for p in inputs:
    im = Image.open(p).convert('RGBA')
    print(f"  input:  {p} -> {im.width}x{im.height}", file=sys.stderr)
    candidates.append(im)
if hires:
    im = Image.open(hires).convert('RGBA')
    print(f"  -r/raw: {hires} -> {im.width}x{im.height}", file=sys.stderr)
    candidates.append(im)

base = max(candidates, key=lambda im: im.width * im.height)
print(f"  -> using {base.width}x{base.height} as base for downscaling", file=sys.stderr)

# Nur Groessen verwenden, die <= Basisbildgroesse sind (kein Hochskalieren)
sizes = [s for s in ICO_SIZES if s[0] <= base.width and s[1] <= base.height]
if not sizes:
    sizes = [(base.width, base.height)]

base.save(output, format='ICO', sizes=sizes)
print(f"Created {output} from {base.width}x{base.height} base with sizes {sizes}")
