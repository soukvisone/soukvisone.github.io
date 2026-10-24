#!/usr/bin/env python3
# ==========================================================================
#  matryoshka.py — แกะไฟล์ PHP/สคริปต์ที่ห่อหลายชั้น eval(gzinflate(base64_decode("..."))) ทีละชั้น
#  ปลอดภัย: "ถอดอย่างเดียว ไม่รันโค้ด" (ไม่เรียก PHP เลย)
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   python3 matryoshka.py
#  ไฟล์ใหญ่ (เช่น 137 MB) ใช้ RAM ~2 GB และใช้เวลาหลายนาที
# ==========================================================================
FILE = "round_1.php"                       # <<< แก้บรรทัดนี้บรรทัดเดียว

import base64, binascii, codecs, re, sys, urllib.parse, zlib
if len(sys.argv) > 1: FILE = sys.argv[1]

def unescape(d):                           # "\x41\x42" -> "AB"  และ "\/" -> "/"
    if b'\\x' in d:
        return bytes.fromhex(d.replace(b'\\', b'').replace(b'x', b'').decode())
    return d.replace(b'\\/', b'/')

def inflate_any(d):                        # gzinflate / gzuncompress / gzdecode ลองให้หมด
    for wbits in (-15, 15, 31):
        try: return zlib.decompress(d, wbits)
        except zlib.error: pass
    raise ValueError("inflate ไม่ได้")

TOOLS = {  # ชื่อฟังก์ชัน PHP -> วิธีถอดใน Python (เพิ่มได้เองถ้าเจอฟังก์ชันใหม่)
    b'hex2bin': binascii.unhexlify, b'base64_decode': base64.b64decode,
    b'gzinflate': inflate_any, b'gzuncompress': inflate_any, b'gzdecode': inflate_any,
    b'stripcslashes': unescape, b'strrev': lambda d: d[::-1],
    b'str_rot13': lambda d: codecs.encode(d.decode('latin1'), 'rot13').encode('latin1'),
    b'urldecode': lambda d: urllib.parse.unquote_to_bytes(d), b'rawurldecode': lambda d: urllib.parse.unquote_to_bytes(d),
    b'bzdecompress': lambda d: __import__('bz2').decompress(d),
}
WRAP_ONLY = {b'eval', b'assert', b'json_decode', b'unserialize', b'trim', b'create_function', b'php', b'if', b'return'}

text = open(FILE, 'rb').read()
print(f"อ่านไฟล์ {FILE} ({len(text):,} ไบต์)")
layers = 0
for n in range(1, 2000):
    names = re.findall(rb'\w+(?=\s*\()', text[:300])             # 1. ฟังก์ชันที่ห่ออยู่
    blob = re.search(rb'[A-Za-z0-9+/=\\]{100,}', text)           # 2. ข้อมูล = ก้อนยาว ๆ
    if not blob: break
    data = blob.group().replace(b'\\/', b'/')
    known = [x for x in names if x in TOOLS]
    unknown = [x for x in names if x not in TOOLS and x not in WRAP_ONLY]
    try:
        for name in reversed(known): data = TOOLS[name](data)    # 3. ถอดจากในสุดออกมา
        if not known: data = unescape(data)
    except Exception as e:
        print(f"[!] ชั้น {n}: ถอดไม่ได้ ({e}) ฟังก์ชัน={[x.decode() for x in names]}")
        print("    ต้นข้อความชั้นนี้:", text[:300])
        break
    if unknown: print(f"[!] ชั้น {n}: เจอฟังก์ชันที่ยังไม่รู้จัก {[x.decode() for x in unknown]} -> เพิ่มใน TOOLS ถ้าผลผิดปกติ")
    if n <= 5 or n % 10 == 0: print(n, [x.decode() for x in names], len(data))
    text = data
    layers = n
print(f"\nถอดครบ {layers} ชั้น — ข้อความชั้นสุดท้าย:\n")
final = text.decode('latin1')
print(final[:3000])
open("matryoshka_final.txt", "wb").write(text)
flags = re.findall(r"CSG_FLAG\{[^}]*\}", final)
print("\n===== สรุป =====")
if flags:
    for f in dict.fromkeys(flags): print("[+]", f)
else:
    print("[!] ไม่พบ CSG_FLAG{ ในชั้นสุดท้าย — ดูไฟล์ matryoshka_final.txt (flag อาจอยู่ใน comment หรือถูกตัดด้วย substr)")
