# Dong bo content/ (bai hoc + audio) vao app/assets/ cho Flutter bundle.
# Chay lai moi khi them/sua bai hoc. Idempotent.
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")
APP = os.path.join(ROOT, "app")
ASSETS = os.path.join(APP, "assets", "lessons")

os.makedirs(ASSETS, exist_ok=True)
shutil.copy(os.path.join(CONTENT, "lessons.json"),
            os.path.join(ASSETS, "lessons.json"))

audio_src = os.path.join(CONTENT, "audio")
dirs = []
if os.path.isdir(audio_src):
    for d in sorted(os.listdir(audio_src)):
        src = os.path.join(audio_src, d)
        if not os.path.isdir(src):
            continue
        dst = os.path.join(ASSETS, "audio", d)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            if f.endswith(".mp3"):
                shutil.copy2(os.path.join(src, f), dst)
        dirs.append("assets/lessons/audio/%s/" % d)

pubspec = os.path.join(APP, "pubspec.yaml")
with open(pubspec, encoding="utf-8") as fh:
    text = fh.read()

block = "  assets:\n    - assets/lessons/lessons.json\n"
block += "".join("    - %s\n" % d for d in dirs)
text = re.sub(r"  assets:\n(?:    - .*\n)*", block, text)

with open(pubspec, "w", encoding="utf-8") as fh:
    fh.write(text)

print("synced: 1 lessons.json + %d audio dirs" % len(dirs))
