#!/usr/bin/env python3
# ==========================================================================
#  vigenere_solver.py — ถอด Vigenere/Caesar ที่ flag ยังเข้ารหัสอยู่ (เช่น OST_RLNS{...})
#  ทำอะไร:
#    1) ใช้ "CSG_FLAG" เป็นเบาะแส คำนวณว่าแต่ละตัวถูกเลื่อนไปกี่ตำแหน่ง -> หาคีย์ที่วนซ้ำ
#    2) ลองคีย์จากรายการ EXTRA_KEYS (คำที่ได้จากโจทย์ เช่น รหัสผ่าน zip, คำในรูป/ชื่อไฟล์)
#    3) ลอง Caesar ทุก shift (กรณีคีย์ยาว 1 ตัว)
#  วิธีใช้: แก้ DATA (ข้อความที่เข้ารหัส หรือชื่อไฟล์ .txt) แล้วรัน  python3 vigenere_solver.py
# ==========================================================================
DATA = "OST_RLNS{Ynk!==Ybg-aeq-shocressglyk-drooqqd-Iugrzeeq-cvbhrd-iaeiqq-pvothdef!-Ooasuemthdagguoae!!}"  # <<< แก้บรรทัดนี้
EXTRA_KEYS = ["man", "password", "key", "secret", "cyberseagame", "csg"]   # คำที่คิดว่าเป็นคีย์ (เพิ่มได้)
CRIB = "CSG_FLAG"                                                          # ไม่ต้องแก้

import os, re, sys
if len(sys.argv) > 1: DATA = sys.argv[1]
if os.path.isfile(DATA): DATA = open(DATA, encoding="utf-8", errors="replace").read().strip()

def dec(ct, key):
    out, i = [], 0
    for c in ct:
        if c.isalpha():
            b = 65 if c.isupper() else 97
            out.append(chr((ord(c) - b - (ord(key[i % len(key)].upper()) - 65)) % 26 + b)); i += 1
        else:
            out.append(c)
    return "".join(out)

def key_from_crib(ct):
    """ตัวอักษรของ CRIB ต้องอยู่ต้นข้อความ (key ขยับเฉพาะตัวอักษร) -> คำนวณ shift"""
    letters = [c for c in ct if c.isalpha()]
    cr = [c for c in CRIB if c.isalpha()]
    if len(letters) < len(cr): return None
    sh = [(ord(letters[i].upper()) - ord(cr[i])) % 26 for i in range(len(cr))]
    for L in range(1, len(sh) // 2 + 1):          # หาคาบที่สั้นที่สุดที่ซ้ำกันจริง
        if all(sh[i] == sh[i % L] for i in range(len(sh))):
            return "".join(chr(65 + x) for x in sh[:L])
    return "".join(chr(65 + x) for x in sh)       # ไม่เจอคาบ = คีย์ยาว >= ความยาว crib

found = []
print("ข้อความ:", DATA[:120])
k = key_from_crib(DATA)
if k:
    print(f"\n[1] คีย์จากเบาะแส CSG_FLAG = {k}")
    r = dec(DATA, k); print("    ->", r)
    if r.startswith("CSG_FLAG"): found.append(r)
print("\n[2] ลองคีย์จากรายการ EXTRA_KEYS")
for kk in EXTRA_KEYS:
    r = dec(DATA, kk)
    if "CSG_FLAG" in r: print(f"    คีย์ {kk} ->", r); found.append(r)
print("\n[3] ลอง Caesar ทุก shift")
for s in range(1, 26):
    r = dec(DATA, chr(65 + s))
    if "CSG_FLAG" in r: print(f"    shift {s} ->", r); found.append(r)
print("\n===== สรุป =====")
if found:
    for f in dict.fromkeys(found): print("[+]", re.search(r"CSG_FLAG\{.*\}", f).group(0) if re.search(r"CSG_FLAG\{.*\}", f) else f)
else:
    print("[!] ไม่พบ — flag อาจไม่ได้เข้ารหัสด้วย Vigenere/Caesar หรือคีย์ยาวกว่าเบาะแส (ลองใส่คำจากโจทย์ใน EXTRA_KEYS)")
