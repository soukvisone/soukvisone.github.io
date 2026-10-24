#!/usr/bin/env python3
# ==========================================================================
#  cookie_jwt_decode.py  —  ถอด JWT และอ่านคุกกี้ที่ได้จากเว็บ
#  ทำอะไร: แยก JWT เป็น 3 ส่วน (header / payload / signature) แล้วถอดให้อ่าน
#           พร้อมบอกจุดอ่อนที่พบบ่อย (alg=none, secret อ่อน)
#  ปลอดภัย: ถอดในเครื่องเท่านั้น ไม่ส่ง token ไปที่ไหน
#
#  วิธีใช้: แก้บรรทัด JWT ด้านล่าง แล้วรัน   python3 cookie_jwt_decode.py
# ==========================================================================

JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoiZ3Vlc3QifQ.xxxxxxxx"   # <<< แก้บรรทัดนี้
COOKIE = ""          # ถ้าโจทย์ให้คุกกี้มาแบบทั้งก้อน ให้วางที่นี่ (ไม่จำเป็น)

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import base64
import binascii
import hashlib
import hmac
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

FLAG_RE = re.compile(r"CSG_FLAG\{[^}]*\}")


def section(title):
    print("\n" + "=" * 12 + f" {title} " + "=" * 12)


def b64url_decode(part):
    """ถอด base64url (JWT ใช้ - และ _ แทน + และ / และตัด = ออก)"""
    part = part.strip()
    pad = "=" * (-len(part) % 4)
    try:
        return base64.urlsafe_b64decode(part + pad)
    except (binascii.Error, ValueError):
        return b""


def pretty(raw):
    """พยายามแปลงเป็น JSON สวย ๆ ถ้าไม่ได้ก็คืนข้อความธรรมดา"""
    text = raw.decode("utf-8", "replace")
    try:
        return json.dumps(json.loads(text), indent=2, ensure_ascii=False)
    except json.JSONDecodeError:
        return text


def human_time(value):
    """แปลงค่า exp/iat (วินาที) เป็นเวลาที่อ่านออก"""
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    except (ValueError, OSError, TypeError):
        return "?"


def main():
    global JWT

    outdir = Path(f"output_{Path(__file__).stem}")
    outdir.mkdir(exist_ok=True)

    # ถ้าพิมพ์ token ต่อท้ายตอนรัน ให้ใช้ค่านั้น
    if len(sys.argv) > 1:
        JWT = sys.argv[1]

    section("1) ข้อมูลที่ได้รับ")
    print(f"JWT : {JWT[:80]}{'...' if len(JWT) > 80 else ''}")
    if COOKIE:
        print(f"Cookie ทั้งก้อน: {COOKIE}")

    # ---------- 2) แยก 3 ส่วน ----------
    section("2) แยกส่วนของ JWT")
    parts = JWT.strip().split(".")
    if len(parts) != 3:
        print(f"[!] token นี้มี {len(parts)} ส่วน (JWT ปกติต้องมี 3 ส่วน)")
        # ลองหาค่าที่หน้าตาเป็น JWT ในคุกกี้ทั้งก้อน
        m = re.search(r"[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*", COOKIE or "")
        if m:
            print(f"[+] พบค่าที่เป็น JWT ในคุกกี้: {m.group(0)[:60]}...")
            parts = m.group(0).split(".")
        if len(parts) != 3:
            print("[!] หยุดตรงนี้ — ตรวจสอบว่าคัดลอก token มาครบ")
            sys.exit(0)

    header_raw, payload_raw, sig_raw = parts

    # ---------- 3) header ----------
    section("3) Header (บอกอัลกอริทึมที่ใช้เซ็น)")
    header_text = pretty(b64url_decode(header_raw))
    print(header_text)

    # ---------- 4) payload ----------
    section("4) Payload (ข้อมูลจริง — ส่วนนี้ไม่ได้เข้ารหัส)")
    payload_text = pretty(b64url_decode(payload_raw))
    print(payload_text)

    # ---------- 5) เวลาหมดอายุ ----------
    section("5) เวลาที่เกี่ยวข้อง")
    try:
        payload = json.loads(b64url_decode(payload_raw).decode("utf-8", "replace"))
    except Exception:
        payload = {}
    if "exp" in payload:
        print(f"exp (หมดอายุ) : {human_time(payload['exp'])}")
    else:
        print("exp : ไม่มี (token ไม่หมดอายุ — ปกติแปลว่าปลอมได้ง่าย)")
    if "iat" in payload:
        print(f"iat (ออกเมื่อ) : {human_time(payload['iat'])}")
    if "alg" in payload:
        print(f"alg ใน payload : {payload['alg']}")

    # ---------- 6) จุดอ่อนที่ควรลอง ----------
    section("6) จุดอ่อนที่ควรลอง (โจทย์ JWT มักออกแบบมาให้ลอง)")
    alg = ""
    try:
        alg = json.loads(b64url_decode(header_raw).decode("utf-8", "replace")).get("alg", "")
    except Exception:
        pass

    findings = []
    if alg.lower() == "none":
        findings.append("alg = none  -> ลองเปลี่ยน header เป็น {\"alg\":\"none\"} แล้วตัด signature ออก (เหลือ token..)")
    if alg.startswith("HS"):
        findings.append("alg = HS256/HS512 -> ถ้าเดา secret ได้ ให้เซ็นใหม่ด้วย secret นั้น")
        findings.append("   ลอง crack secret แบบ offline (ไม่ส่งออกเน็ต):")
        findings.append("   echo '<token>' > jwt.txt && hashcat -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt")
        findings.append("   หรือ:  john --format=HMAC-SHA256 --wordlist=/usr/share/wordlists/rockyou.txt jwt.txt")
    if alg.startswith("RS"):
        findings.append("alg = RS256 -> ลอง alg confusion (เปลี่ยนเป็น HS256 แล้วใช้ public key เป็น secret)")
    if alg.startswith("ES"):
        findings.append("alg = ES256 -> ตรวจว่า nonce/ข้อความซ้ำถูกใช้ซ้ำได้ไหม (replay)")
    if not findings:
        findings.append("ไม่พบรูปแบบที่รู้จัก — ดู payload ว่ามีช่อง role/admin/is_admin ที่แก้ได้ไหม")

    for f in findings:
        print(f"  - {f}")

    # ---------- 7) ตรวจ signature แบบคร่าว ๆ ----------
    section("7) ตรวจ signature (ต้องรู้ secret ถึงจะยืนยันได้)")
    if not sig_raw:
        print("[!] ไม่มี signature — token นี้น่าจะถูกแก้มาแล้ว (unsigned)")
    else:
        print(f"signature (base64url) : {sig_raw[:40]}...")
        print(f"ความยาว signature     : {len(b64url_decode(sig_raw))} bytes")
        print("(ถ้าอยากลอง secret ที่เดาได้ ให้รันโค้ดด้านล่างนี้ใน python3)")
        print("  import hmac, hashlib, base64")
        print("  signing_input = '<header>.<payload>'")
        print("  sig = base64.urlsafe_b64encode(")
        print("      hmac.new(b'secret', signing_input.encode(), hashlib.sha256).digest()")
        print("  ).rstrip(b'=').decode()")

    # ---------- 8) เขียนผลลงไฟล์ ----------
    report = outdir / "jwt_decoded.txt"
    report.write_text(
        f"JWT:\n{JWT}\n\n--- HEADER ---\n{header_text}\n\n--- PAYLOAD ---\n{payload_text}\n",
        encoding="utf-8",
    )
    print(f"\n[+] บันทึกผลไว้ที่: {report}")

    # ---------- 9) หาแฟล็ก ----------
    section("ค้นหา CSG_FLAG{")
    flags = set(FLAG_RE.findall(header_text)) | set(FLAG_RE.findall(payload_text))
    flags |= set(FLAG_RE.findall(JWT))
    if flags:
        for f in sorted(flags):
            print(f"[+] {f}")
        (outdir / "_FLAGS.txt").write_text("\n".join(sorted(flags)), encoding="utf-8")
    else:
        print("[!] ไม่พบแฟล็กใน token — แฟล็กมักอยู่ในช่อง admin/flag/role ของ payload")

    # ---------- 10) สรุป ----------
    section("สรุป")
    print(f"- alg      : {alg or '?'}")
    print(f"- จำนวนส่วน: {len(parts)}")
    print(f"- ผลลัพธ์   : {outdir}/jwt_decoded.txt")


if __name__ == "__main__":
    main()
