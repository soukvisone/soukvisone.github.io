#!/usr/bin/env python3
# ==========================================================================
#  crypto_pipeline.py — ถอดรหัสอัตโนมัติหลายชั้น + XOR + เก็บ flag
#  ใช้เมื่อ: ได้ข้อความ/ไฟล์ที่ดูถูกเข้ารหัส แล้วอยากให้ไล่ถอดให้หมด
#
#  วิธีใช้:
#     python3 crypto_pipeline.py                       # ใช้ค่า DATA ด้านล่าง
#     python3 crypto_pipeline.py "UTFO{qrs123}"
#     python3 crypto_pipeline.py cipher.bin            # อ่านจากไฟล์
# ==========================================================================

DATA = "Q1NHX0ZMQUd7dGhpc19pc19hX3Rlc3R9"      # <<< แก้บรรทัดนี้บรรทัดเดียว
MAX_DEPTH = 3                                   # ถอดซ้อนได้กี่ชั้น

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import base64
import binascii
import math
import re
import string
import sys
import urllib.parse
from collections import Counter
from pathlib import Path

FLAG_STRICT = re.compile(rb"CSG_FLAG\{[^}]{1,300}\}")
FLAG_ANY = re.compile(rb"[A-Za-z0-9_]{2,16}\{[^}]{2,300}\}")
B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
MORSE = {
    ".-": "A", "-...": "B", "-.-.": "C", "-..": "D", ".": "E", "..-.": "F",
    "--.": "G", "....": "H", "..": "I", ".---": "J", "-.-": "K", ".-..": "L",
    "--": "M", "-.": "N", "---": "O", ".--.": "P", "--.-": "Q", ".-.": "R",
    "...": "S", "-": "T", "..-": "U", "...-": "V", ".--": "W", "-..-": "X",
    "-.--": "Y", "--..": "Z", "-----": "0", ".----": "1", "..---": "2",
    "...--": "3", "....-": "4", ".....": "5", "-....": "6", "--...": "7",
    "---..": "8", "----.": "9", "..--.-": "_",
}


def section(t):
    print("\n" + "=" * 12 + f" {t} " + "=" * 12)


def printable_ratio(b):
    if not b:
        return 0.0
    return sum(1 for c in b if 32 <= c < 127 or c in (9, 10, 13)) / len(b)


# ตัวอักษรที่ยอมให้อยู่ในเนื้อ flag (กันผลลัพธ์ขยะจาก XOR)
BODY_OK = re.compile(rb"^[A-Za-z0-9_!?.,:+=/@#$%^&*()\- ]{2,200}$")

def plausible(token: bytes) -> bool:
    """ตรวจว่า token หน้าตาเป็น flag จริงไหม (prefix ตัวใหญ่ + เนื้อในไม่ใช่ขยะ)"""
    m = re.match(rb"^([A-Z0-9_]{2,16})\{([^}]*)\}$", token)
    if not m:
        return False
    prefix, body = m.group(1), m.group(2)
    if not BODY_OK.match(body):
        return False
    # ต้องมีตัวอักษรอย่างน้อย 2 ตัว และไม่มีตัวพิมพ์ผสมมั่ว ๆ ยาว ๆ
    if sum(chr(c).isalnum() for c in body) < 2:
        return False
    return True


def good_flags(blob: bytes):
    return {m.group(0) for m in FLAG_STRICT.finditer(blob) if plausible(m.group(0))}



def okay(text):
    if not text or len(text) < 4:
        return False
    return sum(c.isprintable() or c in "\r\n\t" for c in text) / len(text) >= 0.9


# ---------------- ตัวถอดรหัส ----------------
def caesar(s, k):
    out = []
    for c in s:
        if c.isupper():
            out.append(chr((ord(c) - 65 + k) % 26 + 65))
        elif c.islower():
            out.append(chr((ord(c) - 97 + k) % 26 + 97))
        else:
            out.append(c)
    return "".join(out)


def atbash(s):
    out = []
    for c in s:
        if c.isupper():
            out.append(chr(90 - (ord(c) - 65)))
        elif c.islower():
            out.append(chr(122 - (ord(c) - 97)))
        else:
            out.append(c)
    return "".join(out)


def rot47(s):
    return "".join(chr(33 + ((ord(c) - 33 + 47) % 94)) if 33 <= ord(c) <= 126 else c for c in s)


def b64(s):
    t = s.strip()
    pad = "=" * (-len(t) % 4)
    try:
        raw = base64.b64decode(t + pad, validate=True)
    except (binascii.Error, ValueError):
        return None
    for enc in ("utf-8", "utf-16-le", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return None


def b32(s):
    t = "".join(c for c in s.strip().upper() if c in string.ascii_uppercase + "234567=")
    t += "=" * (-len(t) % 8)
    try:
        return base64.b32decode(t).decode("utf-8")
    except (binascii.Error, ValueError):
        return None


def b58(s):
    t = s.strip()
    if not t or any(c not in B58 for c in t):
        return None
    n = 0
    for c in t:
        n = n * 58 + B58.index(c)
    raw = (n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b"")
    raw = b"\x00" * (len(t) - len(t.lstrip("1"))) + raw
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return None


def unhex(s):
    t = s.strip().replace(" ", "").replace("\\x", "")
    if len(t) % 2 or not re.fullmatch(r"[0-9a-fA-F]+", t or "z"):
        return None
    try:
        return bytes.fromhex(t).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        return None


def url_dec(s):
    if "%" not in s and "+" not in s:
        return None
    out = urllib.parse.unquote_plus(s)
    return out if out != s else None


def morse(s):
    t = s.strip()
    if not re.fullmatch(r"[.\-/\s|]+", t or "x"):
        return None
    words = re.split(r"\s*[/|]\s*|\s{2,}", t)
    res = []
    for w in words:
        letters = [MORSE.get(x, "") for x in w.split()]
        if not letters or "" in letters:
            return None
        res.append("".join(letters))
    return " ".join(res)


def binary(s):
    t = re.sub(r"[^01]", "", s)
    if len(t) < 16 or len(t) % 8 or len(t) == len(s.strip()) and " " not in s:
        # ต้องมีช่องว่างหรือคั่นให้เห็นว่าเป็น binary จริง
        if " " not in s:
            return None
    try:
        return "".join(chr(int(t[i:i + 8], 2)) for i in range(0, len(t), 8))
    except ValueError:
        return None


def caesar_all(s):
    """ลอง Caesar ทุก shift แต่เก็บเฉพาะ 2 อันที่คะแนนดีสุด (กัน noise)"""
    scored = []
    for k in range(1, 26):
        r = caesar(s, k)
        sc = 0
        if re.search(r"[A-Z0-9_]{2,16}\{[^}]{2,300}\}", r):
            sc += 40
        sc += sum(6 for w in ("flag", "csg", "the", "and", "secret") if w in r.lower())
        if sc:
            scored.append((sc, f"caesar+{k}", r))
    scored.sort(reverse=True)
    return [(n, v) for _, n, v in scored[:2]]


def apply_all(s):
    res = []
    for name, fn in (("base64", b64), ("base32", b32), ("base58", b58), ("hex", unhex),
                     ("rot13", lambda x: caesar(x, 13)), ("rot47", rot47),
                     ("url", url_dec), ("atbash", atbash), ("morse", morse),
                     ("binary", binary)):
        try:
            v = fn(s)
        except Exception:
            v = None
        if v and v != s:
            res.append((name, v))
    res.extend(caesar_all(s))
    return res


# ---------------- XOR ----------------
def xor_single(data):
    """ลอง XOR 1 ไบต์ทั้ง 256 ค่า — คืนรายการที่เจอ flag"""
    hits = []
    for k in range(256):
        out = bytes(b ^ k for b in data)
        if FLAG_STRICT.search(out):
            hits.append((k, out))
    return hits


def xor_crib(data, crib=b"CSG_FLAG{"):
    """เดาคีย์ซ้ำโดยใช้เบาะแส (คีย์ยาว 1..8 ไบต์)"""
    hits = []
    for keylen in range(1, len(crib) + 1):
        for off in range(max(1, len(data) - len(crib) + 1)):
            km = {}
            ok = True
            for i, cb in enumerate(crib):
                pos = (off + i) % keylen
                kb = data[off + i] ^ cb
                if pos in km and km[pos] != kb:
                    ok = False
                    break
                km[pos] = kb
            if not ok or len(km) != keylen:
                continue
            key = bytes(km[i] for i in range(keylen))
            plain = bytes(a ^ b for a, b in zip(data, (key[i % keylen] for i in range(len(data)))))
            if printable_ratio(plain) > 0.95 and good_flags(plain):
                hits.append((key, plain))
    # ตัดซ้ำ
    seen, uniq = set(), []
    for k, p in hits:
        if p not in seen:
            seen.add(p)
            uniq.append((k, p))
    return uniq[:5]


# ---------------- main ----------------
def load():
    raw = sys.argv[1] if len(sys.argv) > 1 else DATA
    p = Path(raw)
    if len(raw) < 260 and p.is_file():
        return p.read_bytes(), f"ไฟล์ {raw}"
    if re.fullmatch(r"[0-9a-fA-F]+", raw or "z") and len(raw) % 2 == 0 and len(raw) >= 16:
        return bytes.fromhex(raw), "hex string"
    return raw.encode("utf-8", "replace"), "ข้อความ"


def main():
    outdir = Path(f"output_{Path(__file__).stem}")
    outdir.mkdir(exist_ok=True)

    data, source = load()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("latin-1")

    section("1) ข้อมูลตั้งต้น")
    print(f"ที่มา   : {source}")
    print(f"ไบต์    : {len(data)}")
    print(f"ตัวอย่าง: {text[:160]}")

    strict, anyflags, results = set(), set(), []
    strict |= good_flags(data)
    anyflags |= {m.group(0) for m in FLAG_ANY.finditer(data) if plausible(m.group(0))}

    # ---------- 2) ถอดเป็นชั้น ๆ ----------
    seen = {text}
    frontier = [(text, "input")]
    for depth in range(1, MAX_DEPTH + 1):
        section(f"2.{depth}) ถอดชั้นที่ {depth}")
        nxt, shown = [], 0
        for cur, chain in frontier:
            for name, val in apply_all(cur):
                if val in seen or not okay(val):
                    continue
                seen.add(val)
                path = f"{chain} → {name}"
                results.append((depth, path, val))
                if shown < 30:
                    print(f"  [{name}] {val.replace(chr(10), ' ')[:100]}")
                    shown += 1
                for m in FLAG_STRICT.finditer(val.encode("utf-8", "replace")):
                    strict.add(m.group(0))
                if depth <= 2:      # รูปแบบที่ไม่ตรงเป๊ะ: เก็บแค่ชั้นตื้น (กัน noise จาก chain ยาว)
                    for m in FLAG_ANY.finditer(val.encode("utf-8", "replace")):
                        if plausible(m.group(0)):
                            anyflags.add(m.group(0))
                if len(nxt) < 300:
                    nxt.append((val, path))
        if not nxt:
            print("  (ถอดต่อไม่ได้แล้ว — หยุด)")
            break
        frontier = nxt

    # ---------- 3) XOR ----------
    section("3) ลอง XOR (1 ไบต์ + คีย์ซ้ำจากเบาะแส)")
    xor_hits = xor_single(data)
    for k, out in xor_hits[:5]:
        print(f"  key=0x{k:02x} → {out[:80]!r}")
        strict |= {m.group(0) for m in FLAG_STRICT.finditer(out)}
        anyflags |= {m.group(0) for m in FLAG_ANY.finditer(out)}

    crib = xor_crib(data)
    for key, out in crib:
        print(f"  key={key!r} → {out[:80]!r}")
        strict |= {m.group(0) for m in FLAG_STRICT.finditer(out)}
        anyflags |= {m.group(0) for m in FLAG_ANY.finditer(out)}
    if not xor_hits and not crib:
        print("  (ไม่พบรูปแบบ XOR ที่อ่านออก)")

    # ---------- 4) บันทึกผล ----------
    with (outdir / "results.txt").open("w", encoding="utf-8", errors="replace") as fh:
        fh.write(f"source: {source}\n\n")
        for depth, path, val in results:
            fh.write(f"### depth {depth}: {path}\n{val}\n\n")
        for k, out in xor_hits:
            fh.write(f"### xor 1 byte key=0x{k:02x}\n{out!r}\n\n")
        for key, out in crib:
            fh.write(f"### xor key={key!r}\n{out!r}\n\n")

    # ---------- 5) สรุป ----------
    section("4) สรุป: flag ที่เจอ")
    if strict:
        for f in sorted(strict):
            print("[+] " + f.decode("utf-8", "replace"))
        (outdir / "_FLAGS.txt").write_bytes(b"\n".join(sorted(strict)))
    else:
        print("[!] ไม่พบรูปแบบ CSG_FLAG{...}")
    others = {a for a in anyflags if not a.startswith(b"CSG_FLAG{")}
    if others:
        print("\n[?] รูปแบบอื่น (อาจเป็น flag ที่ยังเข้ารหัส — เอาไปถอดต่อ):")
        for a in sorted(others)[:10]:
            print("    " + a.decode("utf-8", "replace"))

    section("5) สรุปการทำงาน")
    print(f"- ตัวเลือกที่ถอดได้ : {len(results)}")
    print(f"- XOR ที่เจอ        : {len(xor_hits) + len(crib)}")
    print(f"- ผลลัพธ์           : {outdir}/results.txt")
    print(f"- flag              : {outdir}/_FLAGS.txt" if strict else "- flag              : (ยังไม่มี)")


if __name__ == "__main__":
    main()
