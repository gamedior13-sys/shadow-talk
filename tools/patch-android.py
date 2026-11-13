# Patch config Android do flutter create sinh ra: nang minSdk len 24
# (record/just_audio can minSdk >= 23; khoi nao khong ton tai thi bo qua).
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

candidates = [
    os.path.join(ROOT, "app", "android", "app", "build.gradle.kts"),
    os.path.join(ROOT, "app", "android", "app", "build.gradle"),
]

patched = 0
for f in candidates:
    if not os.path.isfile(f):
        continue
    s = open(f, encoding="utf-8").read()
    s2, n1 = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", s)
    s2, n2 = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", s2)
    if n1 + n2:
        open(f, "w", encoding="utf-8").write(s2)
    patched += n1 + n2
    print("patched %s: %d" % (os.path.basename(f), n1 + n2))

if not any(os.path.isfile(f) for f in candidates):
    print("KHONG tim thay build.gradle — flutter create chua chay?")
    sys.exit(1)
print("minSdk patched total:", patched)
