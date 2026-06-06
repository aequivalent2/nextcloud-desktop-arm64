"""
icotool shim - creates .ico files from PNGs using Pillow.
Usage (mirrors icotool): icotool-shim.py -c -o output.ico [-r hires.png] input1.png input2.png ...
The -r (raw/uncompressed) flag is accepted but ignored (Pillow handles sizing automatically).
"""
import sys
from PIL import Image

output = None
inputs = []
hires = None  # -r <file>: high-res source, scaled to 256x256 for ICO

args = sys.argv[1:]
i = 0
while i < len(args):
    arg = args[i]
    if arg in ('-c', '--create'):
        pass
    elif arg in ('-r', '--raw'):
        i += 1
        hires = args[i]  # capture the high-res PNG (e.g. 1024px)
    elif arg in ('-o', '--output'):
        i += 1
        output = args[i]
    else:
        inputs.append(arg)
    i += 1

if not output or not inputs:
    print("Usage: icotool-shim.py -c -o output.ico [-r hires.png] input.png ...", file=sys.stderr)
    sys.exit(1)

images = [Image.open(p).convert('RGBA') for p in inputs]

# Add 256x256 version from high-res source (ICO max size = 256px)
if hires:
    hi = Image.open(hires).convert('RGBA')
    images.append(hi.resize((256, 256), Image.LANCZOS))

sizes = [(img.width, img.height) for img in images]
images[0].save(output, format='ICO', append_images=images[1:], sizes=sizes)
print(f"Created {output} with sizes {sizes}")
