#!/usr/bin/env python3
# ==========================================================================
#  carve_zip.py — หา zip ที่ซ่อนต่อท้ายไฟล์อื่น (jpg/png/pdf ฯลฯ) แล้วแตกออกมา
#                 ถ้ามีรหัสผ่านจะเดาให้: (1) รายการคำใน PASSWORDS (2) ตัวอักษร a-z สั้น ๆ
#                 (3) rockyou.txt ถ้ามีในเครื่อง   จากนั้นสแกนหา flag ในไฟล์ที่แตกออกมา
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   python3 carve_zip.py
# ==========================================================================
FILE = "Plato.jpg"                                        # <<< แก้บรรทัดนี้บรรทัดเดียว
PASSWORDS = ["password", "CyberSeaGame", "novirus", "infected", "man"]   # คำที่คิดว่าเป็นรหัส (เพิ่มได้)
MAX_BRUTE_LEN = 4                                         # เดา a-z ยาวไม่เกินกี่ตัว (4 = ~460k ครั้ง ไม่กี่นาที)

import io, itertools, os, re, string, sys, zipfile, zlib
if len(sys.argv) > 1: FILE = sys.argv[1]
ROCKYOU = "/usr/share/wordlists/rockyou.txt"
OUT = "output_carve_zip"; os.makedirs(OUT, exist_ok=True)

data = open(FILE, "rb").read()
starts = [m.start() for m in re.finditer(b"PK\x03\x04", data)]
print(f"ไฟล์ {FILE} ({len(data):,} ไบต์) — เจอ signature zip (PK) {len(starts)} จุด: {starts[:5]}")
if not starts:
    print("[!] ไม่พบ zip ที่ซ่อนอยู่ — ลอง binwalk -e หรือดู rar/7z (Rar!, 7z)"); sys.exit()

z = zipfile.ZipFile(io.BytesIO(data[starts[0]:]))
names = [n for n in z.namelist() if not n.endswith("/")]
print(f"ในซิปมี {len(names)} ไฟล์: {names[:8]}{' ...' if len(names) > 8 else ''}")
test = names[0]

def ok(pw):
    try:
        z.read(test, pwd=pw.encode() if pw else None); return True
    except (RuntimeError, zlib.error, zipfile.BadZipFile, ValueError):   # รหัสผิด (บางครั้งรู้ตอน decompress)
        return False

pw = None
if ok(""): pw = ""; print("ซิปไม่มีรหัสผ่าน")
if pw is None:
    print("ซิปมีรหัสผ่าน — เดา...")
    for w in PASSWORDS:
        if ok(w): pw = w; break
if pw is None:
    for n in range(1, MAX_BRUTE_LEN + 1):
        for t in itertools.product(string.ascii_lowercase, repeat=n):
            if ok("".join(t)): pw = "".join(t); break
        if pw is not None: break
if pw is None and os.path.exists(ROCKYOU):
    print("ลอง rockyou.txt ...")
    for line in open(ROCKYOU, "rb"):
        w = line.rstrip(b"\r\n").decode("latin1")
        if ok(w): pw = w; break
if pw is None:
    print("[!] เดารหัสไม่ได้ — ลอง: zip2john + john --wordlist=rockyou.txt, หรือหาใบ้ในโจทย์/รูป"); sys.exit()
print(f"[+] รหัสผ่านซิป = {pw!r}")
for n in names:
    dest = os.path.join(OUT, n.replace("..", "_")); os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    open(dest, "wb").write(z.read(n, pwd=pw.encode() if pw else None))
print(f"[+] แตกไฟล์ไปที่ {OUT}/ แล้ว")
print("\nต่อไป: python3 ../misc/flagscan.py", OUT, "  (หา flag)  — ถ้าเป็นรูปจิ๊กซอว์/ไฟล์หลายชิ้น ดู solve_plato.py")
