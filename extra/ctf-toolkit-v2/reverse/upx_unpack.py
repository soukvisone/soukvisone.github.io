#!/usr/bin/env python3
# ==========================================================================
#  upx_unpack.py — แกะไฟล์ .exe/ELF ที่ถูกอัดด้วย UPX (รวมถึงแบบที่ผู้ออกโจทย์ "เปลี่ยนชื่อ section" หลอก)
#  ทำอะไร:
#    1) เช็กว่ามี UPX หรือไม่ (ข้อความ "UPX!" หรือ section ชื่อ UPX0/UPX1 หรือ section แรก raw size = 0)
#    2) ถ้า section ถูกเปลี่ยนชื่อ -> แก้ชื่อกลับเป็น UPX0/UPX1 ในไฟล์สำเนา
#    3) รัน  upx -d  แล้วเก็บไฟล์ที่แกะแล้วไว้ output_upx_unpack/unpacked.bin
#    4) รัน strings หา flag / ข้อความน่าสนใจให้เลย
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   python3 upx_unpack.py     (ต้องมี upx: sudo apt install upx-ucl)
# ==========================================================================
FILE = "ReverseMe.exe"                  # <<< แก้บรรทัดนี้บรรทัดเดียว

import os, re, shutil, struct, subprocess, sys
if len(sys.argv) > 1: FILE = sys.argv[1]
OUT = "output_upx_unpack"; os.makedirs(OUT, exist_ok=True)
d = bytearray(open(FILE, "rb").read())

secs = []
if d[:2] == b"MZ":
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    if d[pe:pe + 4] == b"PE\0\0":
        nsec = struct.unpack_from("<H", d, pe + 6)[0]
        optsz = struct.unpack_from("<H", d, pe + 20)[0]
        off = pe + 24 + optsz
        for i in range(nsec):
            o = off + i * 40
            name = bytes(d[o:o + 8]).rstrip(b"\0").decode("latin1")
            vsz, va, rsz, rptr = struct.unpack_from("<IIII", d, o + 8)
            secs.append((o, name, vsz, rsz))
        print("sections:", [(s[1], hex(s[2]), hex(s[3])) for s in secs])

has_magic = b"UPX!" in d
packed_shape = len(secs) >= 2 and secs[0][3] == 0 and secs[0][2] > 0 and secs[1][3] > 0
names = [s[1] for s in secs]
print(f"เจอข้อความ 'UPX!': {has_magic} | section แรกว่างบนดิสก์แต่ใหญ่ในหน่วยความจำ (ลักษณะ UPX): {packed_shape}")
if not (has_magic or packed_shape or "UPX0" in names):
    print("[!] ไม่ใช่ UPX ชัด ๆ — ลอง Detect It Easy (diec) / binwalk -E  หรือถ้า upx -d ผ่านเองก็ได้")

work = os.path.join(OUT, "work.bin")
if secs and packed_shape and "UPX0" not in names:
    print(f"[*] section ถูกเปลี่ยนชื่อ ({names[0]}, {names[1]}) -> แก้กลับเป็น UPX0/UPX1 ในสำเนา")
    for (o, _, _, _), new in zip(secs[:2], (b"UPX0", b"UPX1")):
        d[o:o + 8] = new + b"\0" * 4
open(work, "wb").write(d)

if not shutil.which("upx"):
    print("[!] ไม่พบคำสั่ง upx — ติดตั้ง:  sudo apt install -y upx-ucl"); sys.exit(1)
dst = os.path.join(OUT, "unpacked.bin")
if os.path.exists(dst): os.remove(dst)
r = subprocess.run(["upx", "-d", work, "-o", dst], capture_output=True, text=True)
print(r.stdout.strip()[-500:], r.stderr.strip()[-500:])
if not os.path.exists(dst):
    print("[!] upx -d ไม่สำเร็จ — อาจเป็น UPX เวอร์ชันแก้ไข ต้องแกะด้วย debugger (หยุดหลัง stub แล้ว dump memory)"); sys.exit(1)
print(f"[+] แกะแล้ว -> {dst} ({os.path.getsize(dst):,} ไบต์) ใช้ไฟล์นี้กับ reverse/bin_info.sh / Ghidra ต่อ")

s = subprocess.run(["strings", "-n", "4", dst], capture_output=True, text=True).stdout
flags = re.findall(r"CSG_FLAG\{[^}]*\}", s)
print("\n===== สรุป =====")
if flags: [print("[+]", f) for f in dict.fromkeys(flags)]
else:
    print("[!] ไม่มี CSG_FLAG{ ตรง ๆ ใน strings (flag มักถูกประกอบ/XOR ตอนรัน)")
    print("    ข้อความที่น่าสนใจ:"); [print("   ", l) for l in s.splitlines() if re.search(r"(?i)flag|key|pass|usage|correct|wrong|CSG", l)][:20]
