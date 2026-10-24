#!/usr/bin/env python3
# ==========================================================================
#  rsa_helper.py  —  ช่วยแก้โจทย์ RSA (คีย์เล็ก / คีย์อ่อน)
#  ทำอะไร: รับค่า n, e, c แล้วลองวิธีโจมตีที่พบบ่อยที่สุด
#     1) e เล็ก (e=3) และข้อความไม่ถูกแพด -> ถอดรากที่ e
#     2) แยกตัวประกอบ n ด้วยวิธีง่าย ๆ (หารตัวเลขเล็ก, Fermat, sympy)
#     3) Wiener attack (ใช้เมื่อ d เล็ก)
#     4) ถ้าแยกตัวประกอบได้ -> คำนวณ d แล้วถอดรหัส
#
#  วิธีใช้: แก้บรรทัด N, E, C ด้านล่าง แล้วรัน   python3 rsa_helper.py
#  ค่าใส่เป็นเลขฐานสิบ หรือ hex (ขึ้นต้นด้วย 0x) ก็ได้
# ==========================================================================

N = 0x00a1b2c3d4e5f6          # <<< แก้บรรทัดนี้ (ค่า n)
E = 3                          # <<< แก้บรรทัดนี้ (ค่า e)
C = 0x0123456789               # <<< แก้บรรทัดนี้ (ค่า c)

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import math
import re
import sys
from pathlib import Path

FLAG_RE = re.compile(rb"CSG_FLAG\{[^}]*\}")


def section(title):
    print("\n" + "=" * 12 + f" {title} " + "=" * 12)


def to_int(value):
    """รับได้ทั้ง int, สตริงเลขฐานสิบ, สตริง hex"""
    if isinstance(value, int):
        return value
    s = str(value).strip()
    return int(s, 16) if s.lower().startswith("0x") else int(s)


def int_to_bytes(x):
    """แปลงจำนวนเต็มเป็นไบต์ (ตัด leading zero ที่ไม่จำเป็นออก)"""
    if x == 0:
        return b"\x00"
    return x.to_bytes((x.bit_length() + 7) // 8, "big")


def iroot(x, n):
    """รากที่ n ของจำนวนเต็ม (คืนค่า (root, exact?))"""
    if x < 0:
        return 0, False
    if x in (0, 1):
        return x, True
    try:
        import gmpy2                     # ใช้ gmpy2 ถ้ามี (เร็วและแม่นกว่า)
        r, exact = gmpy2.iroot(x, n)
        return int(r), bool(exact)
    except ImportError:
        pass
    # วิธีNewton สำหรับจำนวนเต็ม
    lo, hi = 0, 1 << ((x.bit_length() + n - 1) // n + 1)
    while lo < hi:
        mid = (lo + hi) // 2
        if mid ** n < x:
            lo = mid + 1
        else:
            hi = mid
    return lo, lo ** n == x


def is_prime(n):
    """Miller-Rabin แบบเร็ว"""
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for a in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def fermat(n, rounds=20000):
    """Fermat: ใช้เมื่อ p กับ q ใกล้กันมาก"""
    a = math.isqrt(n)
    if a * a < n:
        a += 1
    for _ in range(rounds):
        b2 = a * a - n
        b = math.isqrt(b2)
        if b * b == b2:
            return a - b, a + b
        a += 1
    return None


def trial_division(n, limit=1000000):
    """หารด้วยจำนวนเฉพาะเล็ก ๆ ก่อน (เร็วและได้ผลบ่อยในโจทย์)"""
    if n % 2 == 0:
        return 2, n // 2
    f = 3
    while f < limit and f * f <= n:
        if n % f == 0:
            return f, n // f
        f += 2
    return None


def pollard_rho(n, max_steps=100000):
    """Pollard rho — หาตัวประกอบ (จำกัดจำนวนรอบ ไม่ให้ค้าง)"""
    if n % 2 == 0:
        return 2, n // 2
    for c in (1, 3, 5, 7, 11):
        x, y, d = 2, 2, 1
        steps = 0
        while d == 1 and steps < max_steps:
            x = (x * x + c) % n
            y = (y * y + c) % n
            y = (y * y + c) % n
            d = math.gcd(abs(x - y), n)
            steps += 1
        if 1 < d < n:
            return d, n // d
    return None


def wiener(n, e):
    """Wiener attack: ใช้เมื่อ d เล็กมาก (d < n^0.25)"""
    # คำนวณเศษส่วนต่อเนื่องของ e/n
    cf = []
    num, den = e, n
    while den:
        q = num // den
        cf.append(q)
        num, den = den, num - q * den

    # สร้าง convergent ทีละตัว
    h0, h1 = 0, 1
    k0, k1 = 1, 0
    for q in cf:
        h0, h1 = h1, q * h1 + h0     # h = ตัวเศษ (k ในสูตร)
        k0, k1 = k1, q * k1 + k0     # k = ตัวส่วน (d ในสูตร)
        k, d = h1, k1
        if k == 0:
            continue
        if (e * d - 1) % k != 0:
            continue
        phi = (e * d - 1) // k
        # จาก phi = n - p - q + 1 จะได้ p+q
        s = n - phi + 1
        disc = s * s - 4 * n
        if disc < 0:
            continue
        r = math.isqrt(disc)
        if r * r != disc:
            continue
        if (s + r) % 2:
            continue
        p = (s + r) // 2
        q = (s - r) // 2
        if p * q == n:
            return d, p, q
    return None


def show_bytes(label, data):
    print(f"  {label}: {data[:200]!r}")


def try_decrypt(n, e, c, p=None, q=None, d=None):
    """ถอดรหัสแล้วแสดงผล"""
    if d is None:
        if p is None:
            return None
        # ถ้า n เป็นจำนวนเฉพาะ จะมีตัวประกอบตัวเดียว (q = 1)
        if q is None or q == 1:
            phi = p - 1
        else:
            phi = (p - 1) * (q - 1)
        if math.gcd(e, phi) != 1:
            print("  [!] gcd(e, phi) != 1 — ถอดรหัสแบบปกติไม่ได้")
            return None
        d = pow(e, -1, phi)

    # ตรวจความสอดคล้องของคีย์ก่อน (กันกรณีแยกตัวประกอบได้ไม่ครบ → ได้ตัวเลขขยะ)
    if pow(pow(2, e, n), d, n) != 2 % n:
        print("  [!] ตรวจคีย์ไม่ผ่าน: p/q หรือ d ไม่สอดคล้องกับ n")
        print("      (ตัวประกอบอาจไม่ครบ หรือโจทย์เข้ารหัสด้วยวิธีพิเศษ)")
        return None

    m = pow(c, d, n)
    data = int_to_bytes(m)
    show_bytes("ข้อความที่ถอดได้", data)

    # ลองถอดเป็นตัวเลข (บางโจทย์เข้ารหัสเลขแทนตัวอักษร)
    print(f"  ค่า m (ฐานสิบ): {m}")
    return data


def main():
    outdir = Path(f"output_{Path(__file__).stem}")
    outdir.mkdir(exist_ok=True)

    n, e, c = to_int(N), to_int(E), to_int(C)

    section("1) ค่าที่ได้รับ")
    print(f"n = {n}")
    print(f"e = {e}")
    print(f"c = {c}")
    print(f"ขนาด n = {n.bit_length()} บิต")

    flags = set()
    report_lines = [f"n={n}", f"e={e}", f"c={c}"]

    # ---------- 2) e เล็ก ----------
    section("2) ลองโจมตีแบบ e เล็ก (small exponent)")
    if e <= 11:
        root, exact = iroot(c, e)
        if exact:
            print(f"  [+] c เป็นกำลัง {e} พอดี -> m = {root}")
            data = int_to_bytes(root)
            show_bytes("ข้อความ", data)
            flags |= set(FLAG_RE.findall(data))
            report_lines.append(f"small-e m={root}")
        else:
            print(f"  [-] c ไม่ใช่กำลัง {e} พอดี (แปลว่ามีการแพด หรือข้อความใหญ่เกิน)")
    else:
        print(f"  [-] e = {e} ใหญ่เกินกว่าจะเป็น small-e attack")

    # ---------- 3) แยกตัวประกอบ ----------
    section("3) แยกตัวประกอบ n (ทำในเครื่องนี้เท่านั้น)")
    pq = None
    if is_prime(n):
        print("  [!] n เป็นจำนวนเฉพาะ — โจทย์นี้น่าจะตั้งใจให้แบบพิเศษ (phi = n-1)")
        p, q = n, 1
        pq = (p, q)
    else:
        print("  ลองหารด้วยจำนวนเฉพาะเล็ก ๆ ...")
        pq = trial_division(n)
        if pq:
            print(f"  [+] เจอตัวประกอบด้วยการหาร: p = {pq[0]}")

    if not pq:
        print("  ลอง Fermat (กรณี p กับ q ใกล้กัน) ...")
        pq = fermat(n)
        if pq:
            print(f"  [+] เจอด้วย Fermat: p = {pq[0]}")

    if not pq:
        if n.bit_length() <= 256:
            print("  ลอง Pollard rho ...")
            pq = pollard_rho(n)
            if pq:
                print(f"  [+] เจอด้วย Pollard rho: p = {pq[0]}")
        else:
            print("  ข้าม Pollard rho (n ใหญ่เกินไป — จะใช้เวลานานมาก)")

    if not pq and n.bit_length() <= 256:
        print("  ลอง sympy.factorint (ถ้าติดตั้งไว้) ...")
        try:
            import sympy
            factors = sympy.factorint(n)
            print(f"  ผลแยกตัวประกอบ: {factors}")
            keys = list(factors.keys())
            if len(keys) >= 2:
                pq = (keys[0], keys[1])
            elif len(keys) == 1 and factors[keys[0]] >= 2:
                pq = (keys[0], keys[0])
        except ImportError:
            print("  [-] ไม่มี sympy (ติดตั้งด้วย: pip install --break-system-packages sympy)")
    elif not pq:
        print("  ข้าม sympy (n ใหญ่เกินกว่าจะแยกในเครื่องได้)")

    # ---------- 4) ถอดรหัส ----------
    if pq:
        p, q = pq[0], pq[1]
        print(f"\n  p = {p}")
        print(f"  q = {q}")
        print(f"  ตรวจ p*q == n : {p * q == n}")
        section("4) ถอดรหัสด้วย p, q ที่เจอ")
        data = try_decrypt(n, e, c, p=p, q=q)
        if data:
            flags |= set(FLAG_RE.findall(data))
            report_lines.append(f"p={p}\nq={q}\nplain={data!r}")
    else:
        print("\n  [-] แยกตัวประกอบ n ไม่ได้ด้วยวิธีง่าย ๆ")

    # ---------- 5) Wiener ----------
    section("5) Wiener attack (กรณี d เล็ก)")
    w = wiener(n, e)
    if w:
        d, p, q = w
        print(f"  [+] สำเร็จ! d = {d}")
        print(f"      p = {p}, q = {q}")
        data = try_decrypt(n, e, c, d=d)
        if data:
            flags |= set(FLAG_RE.findall(data))
            report_lines.append(f"wiener d={d}\nplain={data!r}")
    else:
        print("  [-] ไม่เข้าเงื่อนไข Wiener (d ไม่ได้เล็กพอ)")

    # ---------- 6) บันทึกและสรุป ----------
    section("6) สรุป: ค้นหา CSG_FLAG{")
    if flags:
        for f in sorted(flags):
            print(f"[+] {f.decode('utf-8', 'replace')}")
        (outdir / "_FLAGS.txt").write_bytes(b"\n".join(sorted(flags)))
    else:
        print("[!] ยังไม่พบ CSG_FLAG{")
        print("    ถ้า n ยาวมาก (>512 บิต) การแยกตัวประกอบในเครื่องอาจทำไม่ได้")
        print("    ให้ดูโจทย์ว่ามีเบาะแสอื่นไหม: p กับ q ใกล้กัน, e=3, d เล็ก, หรือให้ p มาเลย")
        print("    (ไม่ต้องส่งค่าออกอินเทอร์เน็ต — ใช้เครื่องตัวเองเท่านั้น)")

    (outdir / "results.txt").write_text("\n".join(report_lines), encoding="utf-8")
    print(f"\n[+] บันทึกผลไว้ที่ {outdir}/results.txt")


if __name__ == "__main__":
    # ถ้าพิมพ์ค่าต่อท้ายตอนรัน:  python3 rsa_helper.py <n> <e> <c>
    if len(sys.argv) == 4:
        N, E, C = sys.argv[1], sys.argv[2], sys.argv[3]
    main()
