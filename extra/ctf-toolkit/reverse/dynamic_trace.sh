#!/usr/bin/env bash
# ==========================================================================
#  dynamic_trace.sh  —  รันโปรแกรมและดักดูว่ามันเรียกอะไรบ้าง
#  ทำอะไร: ใช้ ltrace/strace บันทึกการเรียกฟังก์ชันไลบรารีและ system call
#           ทำให้เห็นว่าโปรแกรมเทียบรหัสผ่านอย่างไร หรืออ่านไฟล์อะไร
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash dynamic_trace.sh
#  ถ้าโปรแกรมต้องใส่ argument ให้เขียนต่อท้ายได้เลย เช่น:
#      FILE="./challenge AAAA"
#  ถ้าโปรแกรมรอรับค่าจากคีย์บอร์ด สคริปต์จะป้อน "test" ให้ก่อน 1 ครั้ง
# ==========================================================================

FILE="${1:-./challenge}"          # <<< แก้บรรทัดนี้บรรทัดเดียว
INPUT="test"                      # ข้อความที่จะป้อนให้โปรแกรม (ถ้ามันถาม)

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้ามขั้นนี้) — ติดตั้งด้วย:  sudo apt install -y ${2:-$1}"
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
    warn "ยังไม่เจอ CSG_FLAG{ — ลองรันโปรแกรมเองด้วย input ที่ถูกต้อง แล้วดู strace อีกครั้ง"
  fi
}

# ---------- แยก FILE กับ argument ออกจากกัน ----------
# shellcheck disable=SC2086
set -- $FILE
BIN="$1"
shift
ARGS="$*"          # argument ที่เหลือ (ถ้าไม่มีจะเป็นค่าว่าง)

line "เริ่มทดสอบ: $BIN ${ARGS:+(argument: $ARGS)}"
if [ ! -x "$BIN" ]; then
  if [ -f "$BIN" ]; then
    chmod +x "$BIN" 2>/dev/null
  else
    warn "ไม่พบไฟล์ '$BIN' หรือไฟล์ไม่สามารถรันได้ — ตรวจชื่อไฟล์อีกครั้ง"
    exit 1
  fi
fi

# ---------- 1) รันตรง ๆ ดูผลลัพธ์ ----------
step "1) รันโปรแกรมตรง ๆ (ป้อน '$INPUT' ให้ 1 บรรทัด)"
printf '%s\n' "$INPUT" | timeout 10 "$BIN" $ARGS > "$OUT/run_stdout.txt" 2>&1
echo "exit code: $?"
head -n 30 "$OUT/run_stdout.txt"

# ---------- 2) ltrace — ดูการเรียกฟังก์ชันไลบรารี ----------
step "2) ltrace — โปรแกรมเรียกฟังก์ชันอะไร (เช่น strcmp, malloc)"
if need ltrace; then
  printf '%s\n' "$INPUT" | timeout 15 ltrace -f -s 200 "$BIN" $ARGS \
        > "$OUT/ltrace.txt" 2>&1
  echo "(ได้ $(wc -l < "$OUT/ltrace.txt") บรรทัด)"
  # ฟังก์ชันที่เกี่ยวกับการเทียบข้อความ มักเผยรหัสผ่าน
  grep -a -E 'strcmp|strncmp|memcmp|strcpy|strlen|printf|puts' "$OUT/ltrace.txt" | head -n 30
else
  warn "ติดตั้ง ltrace ได้ด้วย:  sudo apt install -y ltrace"
fi

# ---------- 3) strace — ดู system call ----------
step "3) strace — โปรแกรมคุยกับระบบปฏิบัติการอย่างไร"
if need strace; then
  printf '%s\n' "$INPUT" | timeout 15 strace -f -s 200 -o "$OUT/strace.txt" "$BIN" $ARGS \
        > /dev/null 2>&1
  echo "(ได้ $(wc -l < "$OUT/strace.txt") บรรทัด)"
  # ดูว่าเปิดไฟล์อะไร อ่านอะไร
  grep -a -E 'open|openat|read|write|execve' "$OUT/strace.txt" | head -n 30
else
  warn "ติดตั้ง strace ได้ด้วย:  sudo apt install -y strace"
fi

# ---------- 4) ค้นหาแฟล็กใน trace ----------
step "4) ค้นคำว่า flag / CSG ใน trace"
grep -a -i -E 'flag|csg' "$OUT"/ltrace.txt "$OUT"/strace.txt 2>/dev/null | head -n 20

# ---------- 5) ถ้าโปรแกรมอ่านไฟล์ ให้ลองวางไฟล์ปลอม ----------
step "5) เบาะแส: ไฟล์ที่โปรแกรมเปิด"
if [ -s "$OUT/strace.txt" ]; then
  grep -a -o '"[^"]*"' "$OUT/strace.txt" | grep -a -v -E '/lib|/usr/lib|/etc/ld|/proc|/sys' \
    | sort -u | head -n 20
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ผลการรัน  : $OUT/run_stdout.txt"
echo "- ltrace     : $OUT/ltrace.txt  (ดูการเทียบสตริง)"
echo "- strace     : $OUT/strace.txt  (ดูไฟล์/เครือข่าย)"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
echo
echo "เคล็ดลับ: ถ้า ltrace เห็น strcmp(\"test\", \"XXXX\") แปลว่า XXXX คือรหัสผ่าน"
