#!/usr/bin/env bash
# ==========================================================================
#  memory_dump.sh  —  วิเคราะห์ไฟล์ memory dump ด้วย Volatility 3
#  ทำอะไร: บอกว่าระบบเป็นอะไร, ดูโปรเซสที่รัน, คำสั่งที่ถูกเรียก,
#           การเชื่อมต่อเครือข่าย, และรายชื่อไฟล์ใน memory
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash memory_dump.sh
#  หมายเหตุ: ไฟล์ dump มักใหญ่หลาย GB สคริปต์อาจใช้เวลาหลายนาที
# =============================================================================

FILE="${1:-memory.raw}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลองต่อด้วย plugin อื่น เช่น windows.dumpfiles, windows.registry.printkey"
  fi
}

line "เริ่มวิเคราะห์ memory dump: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
ls -lh "$FILE" | tee "$OUT/file_info.txt"

# ---------- หาคำสั่ง vol ให้เจอก่อน ----------
# Volatility 3 อาจถูกติดตั้งในชื่อ vol / vol.py / volatility3
VOL=""
if command -v vol >/dev/null 2>&1; then
  VOL="vol"
elif command -v vol.py >/dev/null 2>&1; then
  VOL="vol.py"
elif command -v volatility3 >/dev/null 2>&1; then
  VOL="volatility3"
elif python3 -c "import volatility3" >/dev/null 2>&1; then
  VOL="python3 -m volatility3"
fi

if [ -z "$VOL" ]; then
  warn "ไม่พบ Volatility 3 — ติดตั้งด้วย:  python3 -m pip install --break-system-packages volatility3"
  warn "(หรือ  sudo apt install -y volatility3)  แล้วรันสคริปต์นี้อีกครั้ง"
  exit 1
fi
ok "ใช้คำสั่ง: $VOL"

# ---------- 1) ระบบคืออะไร ----------
step "1) ข้อมูลระบบ (imageinfo)"
$VOL -f "$FILE" imageinfo > "$OUT/vol_imageinfo.txt" 2>&1
if ! grep -q -i "windows\|linux\|mac" "$OUT/vol_imageinfo.txt"; then
  # Volatility 3 รุ่นใหม่ใช้ชื่อ windows.info
  $VOL -f "$FILE" windows.info > "$OUT/vol_imageinfo.txt" 2>&1
fi
head -n 25 "$OUT/vol_imageinfo.txt"

# ---------- 2) โปรเซสที่รันอยู่ ----------
step "2) โปรเซส (pslist / pstree)"
$VOL -f "$FILE" windows.pslist > "$OUT/vol_pslist.txt" 2>&1
head -n 30 "$OUT/vol_pslist.txt"
$VOL -f "$FILE" windows.pstree > "$OUT/vol_pstree.txt" 2>&1

# ---------- 3) คำสั่งที่ถูกเรียก (มีประโยชน์มากในโจทย์ malware) ----------
step "3) คำสั่งที่รันอยู่ (cmdline)"
$VOL -f "$FILE" windows.cmdline > "$OUT/vol_cmdline.txt" 2>&1
head -n 30 "$OUT/vol_cmdline.txt"

# ---------- 4) การเชื่อมต่อเครือข่าย ----------
step "4) การเชื่อมต่อเครือข่าย (netscan)"
$VOL -f "$FILE" windows.netscan > "$OUT/vol_netscan.txt" 2>&1
head -n 30 "$OUT/vol_netscan.txt"

# ---------- 5) ไฟล์ที่อยู่ใน memory ----------
step "5) ไฟล์ใน memory (filescan) — อาจมีไฟล์ชื่อ flag"
$VOL -f "$FILE" windows.filescan > "$OUT/vol_filescan.txt" 2>&1
head -n 30 "$OUT/vol_filescan.txt"

# ---------- 6) ค้นคำว่า flag ในผลลัพธ์ ----------
step "6) ค้นคำว่า flag ในผลลัพธ์"
grep -a -i -E 'flag|csg' "$OUT"/vol_*.txt | head -n 30

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ระบบ      : $(head -n 3 "$OUT/vol_imageinfo.txt" | tr '\n' ' ')"
echo "- โปรเซส    : $(wc -l < "$OUT/vol_pslist.txt" 2>/dev/null) บรรทัด"
echo "- คำสั่ง     : $OUT/vol_cmdline.txt"
echo "- เครือข่าย  : $OUT/vol_netscan.txt"
echo "- ไฟล์       : $OUT/vol_filescan.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
