#!/usr/bin/env python3
# ==========================================================================
#  auto_decode.py  —  ลองถอดรหัสอัตโนมัติหลายชั้น (ตัวช่วยที่ใช้บ่อยที่สุด)
#  ทำอะไร: เอาข้อความที่ได้มา ลองถอดด้วยวิธีต่าง ๆ ตามลำดับ
#           base64 / base32 / base58 / hex / rot13 / rot47 / url / caesar /
#           atbash / morse  แล้วถ้าผลลัพธ์ยังดูเข้ารหัสอยู่ ก็ถอดซ้ำได้ถึง 3 ชั้น
#
#  วิธีใช้: แก้บรรทัด DATA ด้านล่าง แล้วรัน   python3 auto_decode.py
#  (ใส่เป็นข้อความ หรือใส่เป็นชื่อไฟล์ที่เก็บข้อความไว้ก็ได้)
# ==========================================================================

DATA = "Q1NHX0ZMQUd7dGhpc19pc19hX3Rlc3R9"          # <<< แก้บรรทัดนี้บรรทัดเดียว
MAX_DEPTH = 3                                        # ถอดซ้อนได้กี่ชั้น (ไม่ต้องแก้)

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import base64
import binascii
import re
import string
import sys
import urllib.parse
from pathlib import Path

FLAG_RE = re.compile(r"CSG_FLAG\{[^}]*\}")
B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

MORSE = {
    ".-": "A", "-...": "B", "-.-.": "C", "-..": "D", ".": "E", "..-.": "F",
    "--.": "G", "....": "H", "..": "I", ".---": "J", "-.-": "K", ".-..": "L",
    "--": "M", "-.": "N", "---": "O", ".--.": "P", "--.-": "Q", ".-.": "R",
    "...": "S", "-": "T", "..-": "U", "...-": "V", ".--": "W", "-..-": "X",
    "-.--": "Y", "--..": "Z", "-----": "0", ".----": "1", "..---": "2",
    "...--": "3", "....-": "4", ".....": "5", "-....": "6", "--...": "7",
    "---..": "8", "----.": "9", ".-.-.-": ".", "--..--": ",", "..--..": "?",
    "..--.-": "_", "-..-.": "/", ".--.-.": "@", ".----.": "'", "-....-": "-",
}


def section(title):
    print("\n" + "=" * 12 + f" {title} " + "=" * 12)


def okay(text):
    """ตัดสินว่าข้อความนี้ 'อ่านออก' พอจะเก็บไว้ดูไหม"""
    if not text or len(text) < 4:
        return False
    printable = sum(c.isprintable() or c in "\r\n\t" for c in text)
    return printable / len(text) >= 0.90


def caesar(text, shift):
    out = []
    for c in text:
        if c.isupper():
            out.append(chr((ord(c) - 65 + shift) % 26 + 65))
        elif c.islower():
            out.append(chr((ord(c) - 97 + shift) % 26 + 97))
        else:
            out.append(c)
    return "".join(out)


def atbash(text):
    out = []
    for c in text:
        if c.isupper():
            out.append(chr(90 - (ord(c) - 65)))
        elif c.islower():
            out.append(chr(122 - (ord(c) - 97)))
        else:
            out.append(c)
    return "".join(out)


def rot47(text):
    return "".join(
        chr(33 + ((ord(c) - 33 + 47) % 94)) if 33 <= ord(c) <= 126 else c for c in text
    )


def rot13(text):
    return caesar(text, 13)


def b64(text):
    s = text.strip()
    pad = "=" * (-len(s) % 4)
    try:
        raw = base64.b64decode(s + pad, validate=True)
    except (binascii.Error, ValueError):
        return None
    for enc in ("utf-8", "utf-16-le", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return None


def b32(text):
    s = text.strip().upper()
    s = "".join(c for c in s if c in string.ascii_uppercase + "234567=")
    s += "=" * (-len(s) % 8)
    try:
        return base64.b32decode(s).decode("utf-8")
    except (binascii.Error, ValueError):
        return None


def b58(text):
    s = text.strip()
    if not s or any(c not in B58 for c in s):
        return None
    n = 0
    for c in s:
        n = n * 58 + B58.index(c)
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    raw = b"\x00" * (len(s) - len(s.lstrip("1"))) + raw
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return None


def unhex(text):
    s = text.strip().replace(" ", "").replace("\\x", "")
    if len(s) % 2 or not re.fullmatch(r"[0-9a-fA-F]+", s or "z"):
        return None
    try:
        return bytes.fromhex(s).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        return None


def url_decode(text):
    if "%" not in text and "+" not in text:
        return None
    out = urllib.parse.unquote_plus(text)
    return out if out != text else None


def morse(text):
    """ถอดรหัสมอร์ส — คำคั่นด้วย / หรือ | หรือช่องว่าง"""
    s = text.strip()
    if not re.fullmatch(r"[.\-/\s|]+", s or "x"):
        return None
    words = re.split(r"\s*[/|]\s*|\s{2,}", s.strip())
    out_words = []
    for w in words:
        letters = [MORSE.get(tok, "") for tok in w.split()]
        if not letters or "" in letters:
            return None
        out_words.append("".join(letters))
    return " ".join(out_words)


def try_caesar_all(text):
    """ลอง Caesar ทุก shift แต่เก็บเฉพาะอันที่ดูมีภาษาหรือมีแฟล็ก"""
    results = []
    for shift in range(1, 26):
        out = caesar(text, shift)
        if "{" in out or "flag" in out.lower() or "csg" in out.lower() or out.count(" ") >= 2:
            results.append((f"caesar+{shift}", out))
    return results


def apply_all(text):
    """ลองทุกวิธีกับข้อความหนึ่งก้อน คืนรายการ (ชื่อวิธี, ผลลัพธ์)"""
    out = []

    # แต่ละฟังก์ชันอาจคืน None (ถอดไม่ได้) จึงต้องเช็กก่อน
    for name, fn in (
        ("base64", b64),
        ("base32", b32),
        ("base58", b58),
        ("hex", unhex),
        ("rot13", rot13),
        ("rot47", rot47),
        ("url-decode", url_decode),
        ("atbash", atbash),
        ("morse", morse),
    ):
        try:
            val = fn(text)
        except Exception:
            val = None
        if val and val != text:
            out.append((name, val))

    out.extend(try_caesar_all(text))
    return out


def load_input():
    """อ่านข้อมูล: ถ้าเป็นชื่อไฟล์ที่มีอยู่จริงก็อ่านไฟล์นั้น"""
    if len(sys.argv) > 1:
        raw = sys.argv[1]
    else:
        raw = DATA

    p = Path(raw)
    if p.is_file() and len(raw) < 260:
        try:
            return p.read_text(encoding="utf-8", errors="replace").strip(), str(p)
        except OSError:
            pass
    return raw, "ข้อความที่พิมพ์ในสคริปต์"


def main():
    outdir = Path(f"output_{Path(__file__).stem}")
    outdir.mkdir(exist_ok=True)

    text, source = load_input()

    section("1) ข้อมูลตั้งต้น")
    print(f"ที่มา : {source}")
    print(f"ความยาว: {len(text)} ตัวอักษร")
    print(f"ข้อมูล : {text[:300]}{'...' if len(text) > 300 else ''}")

    flags = set(FLAG_RE.findall(text))
    if flags:
        section("พบแฟล็กตั้งแต่ข้อมูลตั้งต้น!")
        for f in sorted(flags):
            print(f"[+] {f}")

    # ---------- ไล่ถอดทีละชั้น ----------
    results = []                      # (chain, value, depth)
    seen = {text}
    frontier = [(text, "input")]

    for depth in range(1, MAX_DEPTH + 1):
        section(f"2.{depth}) ถอดชั้นที่ {depth}")
        next_frontier = []
        layer_count = 0

        for current, path in frontier:
            for name, value in apply_all(current):
                if value in seen:
                    continue
                seen.add(value)
                if not okay(value):
                    continue

                chain = f"{path} -> {name}"
                results.append((chain, value, depth))
                layer_count += 1

                # แสดงผลสั้น ๆ ไม่ให้จอเต็ม
                if layer_count <= 40:
                    preview = value.replace("\n", " ")[:100]
                    print(f"  [{name}] {preview}")

                # ถ้าเจอแฟล็ก ให้พิมพ์ทันที
                for f in FLAG_RE.findall(value):
                    flags.add(f)

                if len(next_frontier) < 400:      # กันระเบิดจำนวน
                    next_frontier.append((value, chain))

        if layer_count == 0:
            print("  (ไม่มีอะไรถอดออกมาอ่านได้แล้ว — หยุด)")
            break
        if layer_count > 40:
            print(f"  ... อีก {layer_count - 40} รายการ (ดูทั้งหมดในไฟล์ decoded_results.txt)")
        frontier = next_frontier

    # ---------- เขียนผลทั้งหมดลงไฟล์ ----------
    report = outdir / "decoded_results.txt"
    with report.open("w", encoding="utf-8", errors="replace") as fh:
        for chain, value, depth in results:
            fh.write(f"### depth {depth}: {chain}\n{value}\n\n")
    print(f"\n[+] ผลลัพธ์ทั้งหมด ({len(results)} รายการ) -> {report}")

    # ---------- สรุปแฟล็ก ----------
    section("3) สรุป: ค้นหา CSG_FLAG{")
    if flags:
        for f in sorted(flags):
            print(f"[+] {f}")
        (outdir / "_FLAGS.txt").write_text("\n".join(sorted(flags)), encoding="utf-8")
        print(f"\n[+] บันทึกแฟล็กไว้ที่ {outdir / '_FLAGS.txt'}")
    else:
        print("[!] ยังไม่พบ CSG_FLAG{")
        print("    ลอง: เพิ่ม MAX_DEPTH เป็น 4, หรือเอา output ไปเข้า xor_bruteforce.py")
        print("    หรือถ้าเป็นข้อความยาว ๆ ที่ดูสุ่ม ให้ลอง rsa_helper.py / classic_cipher_notes.txt")

    # ---------- สรุป ----------
    section("4) สรุปการทำงาน")
    print(f"- ข้อมูลตั้งต้น : {source}")
    print(f"- จำนวนผลลัพธ์ : {len(results)}")
    print(f"- โฟลเดอร์ผลลัพธ์: {outdir}/")


if __name__ == "__main__":
    main()
