"""
icotool shim - creates .ico files from PNGs using Pillow.
Usage (mirrors icotool): icotool-shim.py -c -o output.ico [-r hires.png] input1.png input2.png ...
The -r (raw/uncompressed) flag is accepted but ignored (Pillow handles sizing automatically).
"""
import sys
from PIL import Image

output = None
inputs = []
skip_next = False

args = sys.argv[1:]
i = 0
while i < len(args):
    arg = args[i]
    if skip_next:
        skip_next = False
        i += 1
        continue
    if arg in ('-c', '--create'):
        pass
    elif arg in ('-r', '--raw'):
        skip_next = True  # skip the following filename (it's the raw/hires source)
    elif arg == '-o' or arg == '--output':
        i += 1
        output = args[i]
    else:
        inputs.append(arg)
    i += 1

if not output or not inputs:
    print("Usage: icotool-shim.py -c -o output.ico input1.png ...", file=sys.stderr)
    sys.exit(1)

images = [Image.open(p).convert('RGBA') for p in inputs]
sizes = [(img.width, img.height) for img in images]

images[0].save(output, format='ICO', append_images=images[1:], sizes=sizes)
print(f"Created {output} with sizes {sizes}")
