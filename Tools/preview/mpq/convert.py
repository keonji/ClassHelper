import os
import sys
from PIL import Image

source, target = sys.argv[1], sys.argv[2]
converted = failed = 0
for folder, _, files in os.walk(source):
    for name in files:
        if not name.lower().endswith(".blp"):
            continue
        relative = os.path.relpath(os.path.join(folder, name), source)
        output = os.path.join(target, relative[:-4] + ".png").lower()
        if os.path.exists(output):
            continue
        os.makedirs(os.path.dirname(output), exist_ok=True)
        try:
            with Image.open(os.path.join(folder, name)) as image:
                image.convert("RGBA").save(output)
            converted += 1
        except Exception as error:
            failed += 1
            print("FAILED", relative, error)
print("converted", converted, "failed", failed)
