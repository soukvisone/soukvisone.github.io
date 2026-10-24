#!/usr/bin/env bash
# ==========================================================================
#  python_pyc_decompile.sh  —  แปลงไฟล์ .pyc (Python ที่คอมไพล์แล้ว) กลับเป็นโค้ด
#  ทำอะไร: ลองเครื่องมือถอดรหัสหลายตัวตามเวอร์ชัน Python ของไฟล์
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash python_pyc_decompile.sh
# ==========================================================================

FILE="${1:-challenge.pyc}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้ามขั้นนี้) — ติดตั้งด้วย: ${2:-sudo apt install -y $1}"
  return 1
}

find_flags() {
  line "ค้นหา CSG_FLAG{ ในผลลัพธ์ทั้งหมด"
  local hits
  hits=$(grep -a -r -h -o 'CSG_FLAG{[^}]*}' "$OUT" 2>/dev/null | sort -u)
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | tee "$OUT/_FLAGS.txt"
    ok "พบแฟล็ก! บันทึกไว้ที่ $OUT/_FLAGS.txt"
  else
    warn "ยังไม่เจอ CSG_FLAG{ — แฟล็กอาจถูกประกอบตอนรัน ให้รันไฟล์ดู หรือใช้ gdb"
  fi
}

line "เริ่มตรวจไฟล์: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi

# ---------- 1) ไฟล์นี้เป็น Python เวอร์ชันอะไร ----------
step "1) ชนิดไฟล์และเวอร์ชัน Python"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
if need xxd; then
  xxd -l 16 "$FILE" | tee "$OUT/magic.txt"
fi

# magic number ของ pyc บอกเวอร์ชัน เช่น 0d0d0a = 3.6, 550d0d0a = 3.8
MAGIC=$(head -c 4 "$FILE" | od -An -tx1 | tr -d ' \n')
echo "magic bytes: $MAGIC"
case "$MAGIC" in
  420d0d0a|330d0d0a) echo "-> น่าจะเป็น Python 3.3-3.5" ;;
  550d0d0a)          echo "-> Python 3.8" ;;
  610d0d0a)          echo "-> Python 3.9" ;;
  6f0d0d0a)          echo "-> Python 3.10" ;;
  750d0d0a)          echo "-> Python 3.11" ;;
  a70d0d0a)          echo "-> Python 3.12" ;;
  cb0d0d0a)          echo "-> Python 3.13 (เครื่องมือถอดรหัสส่วนใหญ่ยังไม่รองรับ)" ;;
  *)                 echo "-> ไม่ทราบเวอร์ชัน (จะลองทุกเครื่องมือ)" ;;
esac

# ---------- 2) strings ก่อนเลย (ง่ายและได้ผลบ่อย) ----------
step "2) strings — บางทีแฟล็กอยู่ในไฟล์ตรง ๆ"
if need strings binutils; then
  strings -n 4 "$FILE" > "$OUT/strings.txt" 2>&1
  grep -a -i -E 'flag|csg|pass|secret' "$OUT/strings.txt" | head -n 30
  echo "(strings ทั้งหมด -> $OUT/strings.txt)"
fi

# ---------- 3) ลองเครื่องมือถอดรหัสทีละตัว ----------
step "3) ลองถอดรหัสกลับเป็นโค้ด Python"
DECOMPILED="no"

# 3.1 uncompyle6 (รองรับ Python 2.x - 3.8)
if command -v uncompyle6 >/dev/null 2>&1; then
  ok "ลอง uncompyle6"
  uncompyle6 -o "$OUT/decompiled" "$FILE" > "$OUT/uncompyle6_log.txt" 2>&1
  if grep -q -E 'def |import ' "$OUT/uncompyle6_log.txt" 2>/dev/null; then
    DECOMPILED="yes"
    sed -n '1,80p' "$OUT/uncompyle6_log.txt"
  else
    warn "uncompyle6 ถอดไม่ได้ (เวอร์ชัน Python ไม่ตรง)"
  fi
else
  warn "ไม่พบ uncompyle6 — ติดตั้งด้วย:  python3 -m pip install --break-system-packages uncompyle6"
fi

# 3.2 decompyle3 (รองรับ 3.7 - 3.8)
if [ "$DECOMPILED" = "no" ] && command -v decompyle3 >/dev/null 2>&1; then
  ok "ลอง decompyle3"
  decompyle3 -o "$OUT/decompiled" "$FILE" > "$OUT/decompyle3_log.txt" 2>&1
  grep -q -E 'def |import ' "$OUT/decompyle3_log.txt" 2>/dev/null && DECOMPILED="yes"
fi

# 3.3 pycdc (รองรับหลายเวอร์ชัน รวมรุ่นใหม่)
if [ "$DECOMPILED" = "no" ] && command -v pycdc >/dev/null 2>&1; then
  ok "ลอง pycdc"
  pycdc "$FILE" > "$OUT/pycdc_output.py" 2>&1
  if grep -q -E 'def |import |exec' "$OUT/pycdc_output.py" 2>/dev/null; then
    DECOMPILED="yes"
    sed -n '1,80p' "$OUT/pycdc_output.py"
  fi
fi

# 3.4 สุดท้าย: ใช้ dis ของ Python เอง (ได้ bytecode อ่านยากแต่เห็น logic)
if [ "$DECOMPILED" = "no" ]; then
  warn "ยังถอดไม่ได้ — จะดัมป์ bytecode ให้ดูแทน (อ่านยากกว่าแต่เห็นลำดับคำสั่ง)"
  python3 - "$FILE" > "$OUT/bytecode_dis.txt" 2>&1 <<'PY'
import dis
import importlib.util
import sys

path = sys.argv[1]
# โหลดไฟล์ .pyc เป็นโมดูล (ต้องใช้ Python เวอร์ชันเดียวกับไฟล์)
spec = importlib.util.spec_from_file_location("target", path)
try:
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    dis.dis(mod)
except Exception as e:
    print(f"(โหลดไม่ได้: {e})")
    print("เคล็ดลับ: ถ้าไฟล์เป็น Python 3.13 ให้ใช้ pycdc หรือรันด้วย Python เวอร์ชันเดียวกัน")
PY
  head -n 40 "$OUT/bytecode_dis.txt"
fi

# ---------- 4) ค้นหาแฟล็กในโค้ดที่ถอดได้ ----------
step "4) ค้นคำว่า flag ในโค้ดที่ถอดได้"
grep -a -i -E 'flag|csg' "$OUT"/*.py "$OUT"/*.txt 2>/dev/null | head -n 20

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- แปลงเป็นโค้ดได้: $DECOMPILED"
echo "- ไฟล์ผลลัพธ์    : $OUT/decompiled/ (ถ้าถอดได้)"
echo "- bytecode       : $OUT/bytecode_dis.txt"
echo "- ทั้งหมดอยู่ที่  : $OUT/"
echo
echo "ถ้าถอดไม่ได้เพราะเวอร์ชันไม่ตรง ให้ติดตั้ง Python เวอร์ชันนั้นแล้วลองอีกครั้ง"
echo "  ตัวอย่าง:  pyenv install 3.8.0  (หรือใช้ docker: docker run -it python:3.8 bash)"
