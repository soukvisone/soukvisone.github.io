#!/usr/bin/env python3
# ==========================================================================
#  flagscan.py — สแกนหา "flag" ในโฟลเดอร์/ไฟล์ แบบครอบคลุมกว่า grep ธรรมดา
#  ทำอะไร:
#    ชั้น 1 (แน่นอน)   : CSG_FLAG{...}
#    ชั้น 2 (น่าจะใช่)  : คำนำหน้าอะไรก็ได้ตามด้วย {...}  เช่น OST_RLNS{...} (flag ที่ยังเข้ารหัส)
#    ชั้น 3 (เผื่อไว้)   : {...} เปล่า ๆ ไม่มีคำนำหน้า  (บางโจทย์ให้ตอบแค่ข้างใน ต้องเติม CSG_FLAG{} เอง)
#    + ลองถอด base64 / hex / rot13 / กลับตัวอักษร ของ token ที่เจอแล้วหาซ้ำ
#  วิธีใช้: แก้บรรทัด TARGET แล้วรัน   python3 flagscan.py
#           หรือ   python3 flagscan.py output_xxx
# ==========================================================================
TARGET = "output_auto_decode"      # <<< แก้บรรทัดนี้บรรทัดเดียว (โฟลเดอร์หรือไฟล์)

import base64, binascii, codecs, os, re, sys
if len(sys.argv) > 1: TARGET = sys.argv[1]

STRICT = re.compile(rb"CSG_FLAG\{[^{}\r\n\[\]]{1,300}\}")
PREFIXED = re.compile(rb"[A-Za-z0-9_]{2,16}\{[^{}\r\n]{3,300}\}")
BARE = re.compile(rb"\{[^{}\r\n$;\\\"'`<>|]{4,120}\}")
TOKEN = re.compile(rb"[A-Za-z0-9+/=_\-]{16,}")

def variants(blob):
    """คืน (ชื่อวิธี, ข้อมูลที่ถอดแล้ว) ของ token ยาว ๆ"""
    out = []
    for t in list(set(TOKEN.findall(blob)))[:2000]:
        try: out.append(("base64", base64.b64decode(t + b"=" * (-len(t) % 4))))
        except Exception: pass
        if re.fullmatch(rb"[0-9a-fA-F]+", t) and len(t) % 2 == 0:
            try: out.append(("hex", binascii.unhexlify(t)))
            except Exception: pass
    out.append(("rot13", codecs.encode(blob.decode("latin1"), "rot13").encode("latin1")))
    out.append(("reversed", blob[::-1]))
    return out

def files(p):
    if os.path.isfile(p): yield p; return
    for r, _, fs in os.walk(p):
        for f in fs: yield os.path.join(r, f)

found = {1: {}, 2: {}, 3: {}}
def add(level, val, where):
    found[level].setdefault(val.decode("latin1"), where)

def scan(blob, where):
    for lv, rx in ((1, STRICT), (2, PREFIXED), (3, BARE)):
        for m in rx.findall(blob): add(lv, m, where)

n = 0
for f in files(TARGET):
    try: blob = open(f, "rb").read(50_000_000)
    except OSError: continue
    n += 1
    scan(blob, f)
    for name, v in variants(blob[:2_000_000]):
        scan(v, f"{f} [{name}]")

print(f"สแกน {n} ไฟล์ใน {TARGET}\n")
print("=== ชั้น 1: CSG_FLAG{...} (แฟล็กจริง) ===")
for v, w in found[1].items(): print(f"[+] {v}    <- {w}")
if not found[1]: print("(ไม่พบ)")
p2 = {k: w for k, w in found[2].items() if k not in found[1]}
print("\n=== ชั้น 2: คำนำหน้าแปลก ๆ + {...} (อาจเป็น flag ที่ยังเข้ารหัส เช่น Vigenere/Caesar) ===")
for v, w in list(p2.items())[:30]: print(f"[?] {v}    <- {w}")
if not p2: print("(ไม่พบ)")
p3 = {k: w for k, w in found[3].items() if not any(k in x for x in list(found[1]) + list(p2))}
print("\n=== ชั้น 3: {...} เปล่า ๆ (ถ้าโจทย์ให้ตอบข้างใน ให้เติม CSG_FLAG ข้างหน้าเอง) ===")
for v, w in list(p3.items())[:30]: print(f"[?] {v}    -> CSG_FLAG{v}    <- {w}")
if not p3: print("(ไม่พบ)")
if found[1]:
    open("_FLAGS.txt", "w").write("\n".join(found[1]) + "\n")
    print("\n[+] บันทึกแฟล็กจริงไว้ที่ _FLAGS.txt")
