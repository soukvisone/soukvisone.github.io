#!/usr/bin/env python3
# ==========================================================================
#  run_pipeline.py — ตัวสั่งงานเดียว: ใส่ไฟล์หรือ URL แล้วมันเรียกสคริปต์ให้ครบ
#  ใช้เมื่อ: ไม่อยากเลือกเองว่าจะรันตัวไหน
#
#  วิธีใช้:
#     python3 run_pipeline.py challenge.bin
#     python3 run_pipeline.py ./folder
#     python3 run_pipeline.py http://target:8080
#     python3 run_pipeline.py            # ใช้ค่าเริ่มต้นด้านล่าง
# ==========================================================================

TARGET = "challenge.bin"          # <<< แก้บรรทัดนี้บรรทัดเดียว

# --------------------------------------------------------------------------
#  ตั้งแต่บรรทัดนี้ลงไปไม่ต้องแก้
# --------------------------------------------------------------------------
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FLAGS = re.compile(r"CSG_FLAG\{[^}]*\}")
ANYFLAG = re.compile(r"[A-Za-z0-9_]{2,16}\{[^}]{2,300}\}")


def section(t):
    print("\n" + "=" * 14 + f" {t} " + "=" * 14)


def run(script, arg):
    """เรียกสคริปต์ (bash หรือ python) โดยให้ output ไหลออกจอตามปกติ"""
    if script.endswith(".py"):
        cmd = [sys.executable, str(HERE / script), arg]
    else:
        bash = shutil.which("bash")
        if not bash:
            print(f"[!] ไม่พบ bash — ข้าม {script} (บน Windows ให้รันใน WSL/Kali)")
            return False
        cmd = [bash, str(HERE / script), arg]
    print(f"\n$ {' '.join(cmd)}")
    r = subprocess.run(cmd)
    return r.returncode == 0


def collect():
    """กวาด flag จากทุกโฟลเดอร์ output_* ที่สคริปต์สร้าง"""
    flags, others = set(), set()
    roots = [Path.cwd(), HERE, HERE.parent]
    for root in dict.fromkeys(roots):
        for p in root.glob("output_*/**/*"):
            if not p.is_file():
                continue
            try:
                if p.stat().st_size > 40 * 1024 * 1024:
                    continue
                blob = p.read_bytes()
            except OSError:
                continue
            text = blob.decode("utf-8", "replace")
            flags |= set(FLAGS.findall(text))
            if "hits" in p.name or "candidate" in p.name:
                others |= set(ANYFLAG.findall(text))
    return flags, others


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else TARGET
    print(f"เป้าหมาย: {target}")

    if re.match(r"^https?://", target):
        section("โหมดเว็บ")
        run("web_flag.sh", target)
    else:
        p = Path(target)
        if not p.exists():
            print(f"[!] ไม่พบ '{target}' — ตรวจชื่อไฟล์/โฟลเดอร์")
            return 1
        section("ขั้นที่ 1: ตรวจไฟล์ (auto_triage)")
        if p.is_file():
            run("auto_triage.sh", str(p))
        else:
            print("(เป็นโฟลเดอร์ — ข้าม auto_triage)")

        section("ขั้นที่ 2: ไล่หา flag ทั้งหมด (flag_hunt)")
        run("flag_hunt.sh", str(p))

        section("ขั้นที่ 3: ถอดรหัสข้อความที่เจอ (crypto_pipeline)")
        best = None
        for name in ("output_auto_triage/strings_interesting.txt",
                     "output_auto_triage/strings.txt"):
            cand = Path(name)
            if cand.exists() and cand.stat().st_size > 0:
                best = cand
                break
        if best:
            # ใช้บรรทัดที่ยาวที่สุดเป็นตัวแทน (มักเป็น base64 ก้อนใหญ่)
            lines = [l.strip() for l in best.read_text(errors="replace").splitlines() if len(l.strip()) > 16]
            if lines:
                run("crypto_pipeline.py", max(lines, key=len)[:500])
        else:
            print("(ไม่พบข้อความให้นำไปถอด — ข้ามขั้นนี้)")

    section("สรุปสุดท้าย: flag ทั้งหมด")
    flags, others = collect()
    if flags:
        for f in sorted(flags):
            print("[+]", f)
        Path("_ALL_FLAGS.txt").write_text("\n".join(sorted(flags)), encoding="utf-8")
        print(f"\nบันทึกไว้ที่: {Path.cwd() / '_ALL_FLAGS.txt'}")
    else:
        print("[!] ยังไม่พบ CSG_FLAG{...}")
        if others:
            print("\n[?] รูปแบบอื่น (อาจเป็น flag ที่ยังเข้ารหัส):")
            for o in sorted(others)[:10]:
                print("    ", o)
        print("\nขั้นต่อไป:")
        print("  - เปิด output_*/ แล้วอ่านทีละไฟล์")
        print("  - ถ้าเป็นเว็บ: อ่าน ../Web/web_cheatsheet.md")
        print("  - ถ้าเป็นไบนารี: ../Reverse/reversing_notes.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
