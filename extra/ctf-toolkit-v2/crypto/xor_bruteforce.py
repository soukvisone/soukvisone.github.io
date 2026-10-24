#!/usr/bin/env python3
# ==========================================================================
#  xor_bruteforce.py  —  ถอดรหัส XOR (ทั้งแบบคีย์ 1 ไบต์ และคีย์ซ้ำหลายไบต์)
#  ทำอะไร:
#    1) ลองคีย์ 1 ไบต์ทั้ง 256 ค่า แล้วจัดอันดับข้อความที่ "ดูเป็นภาษาคน"
#    2) ใช้คำว่า "CSG_FLAG{" เป็นเบาะแส (known plaintext) เพื่อหาคีย์ที่ยาวขึ้น
#
#  วิธีใช้: แก้บรรทัด DATA ด้านล่าง แล้วรัน   python3 xor_bruteforce.py
#  DATA ใส่ได้ 3 แบบ:
#     - hex          : "1b37373331363f78151c1b"
#     - ข้อความปกติ   : "Khoor Zruog"
#     - ชื่อไฟล์       : "cipher.bin"  (จะอ่านไบต์จากไฟล์)
# ==========================================================================

DATA = "1b37373331363f78151c1b"          # <<< แก้บรรทัดนี้บรรทัดเดียว
CRIB = "CSG_FLAG{"                       # คำที่รู้ว่าอยู่ในข้อความจริง (ไม่ต้องแก้)

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import re
import sys
from pathlib import Path

FLAG_RE = re.compile(rb"CSG_FLAG\{[^}]*\}")
COMMON_WORDS = [b"the", b"and", b"that", b"flag", b"this", b"you", b"for", b"not"]


def section(title):
    print("\n" + "=" * 12 + f" {title} " + "=" * 12)


def printable_ratio(data):
    """สัดส่วนไบต์ที่พิมพ์ออกจอได้ (1.0 = พิมพ์ได้ทั้งหมด)"""
    if not data:
        return 0.0
    good = sum(1 for b in data if 32 <= b < 127 or b in (9, 10, 13))
    return good / len(data)


def score(data):
    """ให้คะแนนว่าข้อมูลนี้ 'เหมือนข้อความภาษาคน' แค่ไหน (ยิ่งมากยิ่งดี)"""
    if not data:
        return -1e9
    printable = sum(1 for b in data if 32 <= b < 127 or b in (9, 10, 13))
    letters = sum(1 for b in data if chr(b).isalpha())
    spaces = data.count(b" ")
    sc = printable * 2 + letters + spaces * 3
    low = data.lower()
    sc += sum(40 for w in COMMON_WORDS if w in low)
    if b"{" in data and b"}" in data:
        sc += 60
    return sc / len(data) + sc / 100.0


def load_data():
    """แปลง DATA เป็น bytes"""
    if len(sys.argv) > 1:
        raw = sys.argv[1]
    else:
        raw = DATA

    p = Path(raw)
    if p.is_file() and len(raw) < 260:
        b = p.read_bytes()
        t = b.strip()
        # ถ้าเนื้อในไฟล์เป็นตัวอักษร hex ล้วน (เช่น cipher.hex) ให้แปลงเป็นไบต์ก่อน
        if t and re.fullmatch(rb"[0-9a-fA-F\s]+", t) and len(re.sub(rb"\s", b"", t)) % 2 == 0:
            return bytes.fromhex(re.sub(rb"\s", b"", t).decode()), f"ไฟล์ {raw} (เนื้อในเป็น hex)"
        return b, f"ไฟล์ {raw}"

    # ถ้าเป็น hex ล้วนและยาวเป็นคู่ ให้ถือว่าเป็น hex
    if re.fullmatch(r"[0-9a-fA-F]+", raw or "z") and len(raw) % 2 == 0:
        return bytes.fromhex(raw), "hex string"

    return raw.encode("utf-8", "replace"), "ข้อความ"


def show(label, data):
    """พิมพ์ตัวอย่างข้อความ (ตัดบรรทัดให้อ่านง่าย)"""
    text = data.decode("utf-8", "replace").replace("\n", " / ")
    print(f"  {label:<22} {text[:120]}")


def single_byte(data):
    """ลอง XOR ด้วยคีย์ 1 ไบต์ทั้ง 256 ค่า"""
    section("1) คีย์ 1 ไบต์ (ลองทั้ง 256 ค่า)")
    scored = []
    for key in range(256):
        out = bytes(b ^ key for b in data)
        scored.append((score(out), key, out))
    scored.sort(reverse=True)

    for sc, key, out in scored[:5]:
        show(f"key=0x{key:02x} ({key:3d})", out)

    best = scored[0]
    print(f"\n-> คีย์ที่น่าจะใช่ที่สุด: 0x{best[1]:02x} ({best[1]})")
    return best


def repeating_key(data):
    """ใช้คำว่า CSG_FLAG{ เป็นเบาะแสหาคีย์ที่วนซ้ำ"""
    section("2) คีย์หลายไบต์ (ใช้เบาะแส CSG_FLAG{)")
    crib = CRIB.encode()
    cands = []

    # ลองความยาวคีย์ 1..8 ไบต์ (เท่าความยาวเบาะแส) และเลื่อนตำแหน่งไปเรื่อย ๆ
    for keylen in range(1, len(crib) + 1):
        for offset in range(0, max(1, len(data) - len(crib) + 1)):
            keymap = {}          # ตำแหน่งไบต์ในคีย์ -> ค่าไบต์
            ok = True
            for i, cb in enumerate(crib):
                pos = (offset + i) % keylen
                kb = data[offset + i] ^ cb
                if pos in keymap:
                    if keymap[pos] != kb:   # ขัดแย้งกัน = คีย์นี้เป็นไปไม่ได้
                        ok = False
                        break
                else:
                    keymap[pos] = kb
            # ต้องรู้ครบทุกตำแหน่งของคีย์ ถึงจะถอดได้
            if not ok or len(keymap) != keylen:
                continue
            key = bytes(keymap[i] for i in range(keylen))

            # ถอดทั้งข้อความด้วยคีย์ที่อนุมานได้
            full = bytes(key[i % keylen] for i in range(len(data)))
            plain = bytes(a ^ b for a, b in zip(data, full))

            # ข้อความจริงต้องพิมพ์ออกจอได้เกือบทั้งหมด — ตัวกรองนี้ตัดของหลอกออก
            ratio = printable_ratio(plain)
            if ratio < 0.95:
                continue
            cands.append((ratio, score(plain), key, offset, plain))

    if not cands:
        print("  (ไม่พบคีย์ที่ทำให้ข้อความอ่านออก — คีย์อาจยาวกว่า 8 ไบต์")
        print("   หรือข้อความจริงไม่มีคำว่า CSG_FLAG{)")
        return None

    # เรียงจากที่ printable มากที่สุด แล้วตัดตัวซ้ำ
    cands.sort(key=lambda t: (t[0], t[1]), reverse=True)
    seen = set()
    unique = []
    for item in cands:
        if item[4] in seen:
            continue
        seen.add(item[4])
        unique.append(item)
        if len(unique) >= 5:
            break

    for ratio, sc, key, offset, plain in unique:
        printable_key = key.decode("latin-1")
        print(f"\n  คีย์ = {printable_key!r}  (hex: {key.hex()})  "
              f"ความยาว {len(key)} ไบต์  เบาะแสอยู่ที่ตำแหน่ง {offset}")
        show("ข้อความที่ได้", plain)

    best = unique[0]
    return best


def main():
    outdir = Path(f"output_{Path(__file__).stem}")
    outdir.mkdir(exist_ok=True)

    data, source = load_data()

    section("ข้อมูลตั้งต้น")
    print(f"ที่มา      : {source}")
    print(f"จำนวนไบต์ : {len(data)}")
    print(f"ตัวอย่าง   : {data[:60]!r}")

    flags = set(FLAG_RE.findall(data))

    # ---------- 1) คีย์ 1 ไบต์ ----------
    best_single = single_byte(data)

    # ---------- 2) คีย์ซ้ำ ----------
    best_repeat = repeating_key(data)

    # ---------- 3) เก็บผลลัพธ์ ----------
    results = [("single-byte", best_single[2])]
    if best_repeat:
        results.append(("repeating-key", best_repeat[4]))

    report = outdir / "results.txt"
    with report.open("wb") as fh:
        for name, val in results:
            fh.write(f"### {name}\n".encode())
            fh.write(val + b"\n\n")
            for m in FLAG_RE.finditer(val):
                flags.add(m.group(0))
    print(f"\n[+] บันทึกผลลัพธ์ไว้ที่ {report}")

    # ---------- 4) สรุป ----------
    section("สรุป: ค้นหา CSG_FLAG{")
    if flags:
        for f in sorted(flags):
            print(f"[+] {f.decode('utf-8', 'replace')}")
        (outdir / "_FLAGS.txt").write_bytes(b"\n".join(sorted(flags)))
    else:
        print("[!] ยังไม่พบ CSG_FLAG{")
        print("    ลอง: แก้ CRIB ให้ตรงรูปแบบโจทย์ เช่น 'flag{' หรือ 'CSG{'")
        print("    หรือถ้าคีย์ยาวเกิน 8 ไบต์ ให้ขยายช่วง keylen ในฟังก์ชัน repeating_key")

    section("ข้อมูลอื่น")
    print(f"- คีย์ 1 ไบต์ที่ดีที่สุด: 0x{best_single[1]:02x}")
    if best_repeat:
        print(f"- คีย์ซ้ำที่ดีที่สุด    : {best_repeat[2]!r}")
    print(f"- โฟลเดอร์ผลลัพธ์        : {outdir}/")


if __name__ == "__main__":
    main()
