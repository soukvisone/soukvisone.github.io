#!/usr/bin/env bash
# ==========================================================================
#  windows_logs.sh  —  อ่านไฟล์ Windows Event Log (.evtx)
#  ทำอะไร: แปลง log เป็นข้อความอ่านง่าย แล้วค้นหาเหตุการณ์สำคัญ
#           (ล็อกอิน, รันโปรแกรม, ติดตั้ง service, ลบ log)
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash windows_logs.sh
#  หมายเหตุ: FILE เป็นได้ทั้งไฟล์ .evtx ไฟล์เดียว หรือโฟลเดอร์ที่มี .evtx หลายไฟล์
# =============================================================================

FILE="${1:-Security.evtx}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลองดู event 4624/4625/4688/7045 ในไฟล์ event_interesting.txt"
  fi
}

line "เริ่มอ่าน event log: $FILE"
if [ ! -e "$FILE" ]; then
  warn "ไม่พบไฟล์/โฟลเดอร์ '$FILE' — ตรวจชื่ออีกครั้ง"
  exit 1
fi

# ---------- 1) แปลง evtx เป็นข้อความ ----------
step "1) แปลง .evtx เป็นข้อความ"
DUMPED="no"
# แบบที่ 1: evtx_dump.py (จาก python-evtx)
if command -v evtx_dump.py >/dev/null 2>&1; then
  ok "ใช้ evtx_dump.py"
  if [ -d "$FILE" ]; then
    for f in "$FILE"/*.evtx; do
      [ -f "$f" ] || continue
      echo "### $f" >> "$OUT/evtx_dump.txt"
      evtx_dump.py "$f" >> "$OUT/evtx_dump.txt" 2>&1
    done
  else
    evtx_dump.py "$FILE" > "$OUT/evtx_dump.txt" 2>&1
  fi
  DUMPED="yes"
# แบบที่ 2: evtx_dump (ตัว rust) — สั่งให้ออกเป็น jsonl
elif command -v evtx_dump >/dev/null 2>&1; then
  ok "ใช้ evtx_dump (rust)"
  if [ -d "$FILE" ]; then
    for f in "$FILE"/*.evtx; do
      [ -f "$f" ] || continue
      evtx_dump -o jsonl "$f" >> "$OUT/evtx_dump.txt" 2>&1
    done
  else
    evtx_dump -o jsonl "$FILE" > "$OUT/evtx_dump.txt" 2>&1
  fi
  DUMPED="yes"
else
  warn "ไม่พบ evtx_dump.py — ติดตั้งด้วย:  sudo apt install -y python3-evtx"
  warn "หรือ:  python3 -m pip install --break-system-packages evtx"
fi

if [ "$DUMPED" = "yes" ] && [ -s "$OUT/evtx_dump.txt" ]; then
  echo "(แปลงได้ $(wc -l < "$OUT/evtx_dump.txt") บรรทัด -> $OUT/evtx_dump.txt)"
  head -n 15 "$OUT/evtx_dump.txt"
fi

# ---------- 2) ค้นหาเหตุการณ์สำคัญด้วย Event ID ----------
# 4624 ล็อกอินสำเร็จ | 4625 ล็อกอินผิด | 4672 สิทธิ์ผู้ดูแล
# 4688 รันโปรแกรม | 4720 สร้างผู้ใช้ | 7045 ติดตั้ง service | 1102 ลบ log
step "2) เหตุการณ์สำคัญ (ค้นตาม Event ID)"
if [ -s "$OUT/evtx_dump.txt" ]; then
  grep -a -E '4624|4625|4672|4688|4720|7045|1102|4104' "$OUT/evtx_dump.txt" \
       > "$OUT/event_interesting.txt" 2>/dev/null
  echo "(เจอ $(wc -l < "$OUT/event_interesting.txt") บรรทัด -> $OUT/event_interesting.txt)"
  head -n 20 "$OUT/event_interesting.txt"
fi

# ---------- 3) chainsaw (ถ้าติดตั้งไว้) ----------
step "3) สแกนด้วย chainsaw (ถ้ามี)"
if need chainsaw "sudo apt install -y chainsaw  # หรือโหลดจาก GitHub release"; then
  chainsaw dump "$FILE" > "$OUT/chainsaw_dump.txt" 2>&1
  echo "(ผลลัพธ์ -> $OUT/chainsaw_dump.txt)"
  # ถ้ามีชุด rule sigma ในเครื่อง ให้สแกนเพิ่ม
  if [ -d /usr/share/chainsaw/sigma ]; then
    chainsaw hunt "$FILE" -s /usr/share/chainsaw/sigma \
             --mapping /usr/share/chainsaw/mappings/sigma-event-logs-all.yml \
             > "$OUT/chainsaw_hunt.txt" 2>&1
    echo "(สแกน rule sigma -> $OUT/chainsaw_hunt.txt)"
  fi
fi

# ---------- 4) hayabusa (ถ้าติดตั้งไว้) ----------
step "4) สแกนด้วย hayabusa (ถ้ามี)"
if need hayabusa "โหลดจาก https://github.com/Yamato-Security/hayabusa/releases"; then
  if [ -d "$FILE" ]; then
    hayabusa csv-timber -d "$FILE" -o "$OUT/hayabusa.csv" --no-wizard > "$OUT/hayabusa_log.txt" 2>&1
  else
    hayabusa csv-timber -f "$FILE" -o "$OUT/hayabusa.csv" --no-wizard > "$OUT/hayabusa_log.txt" 2>&1
  fi
  echo "(ผลลัพธ์ -> $OUT/hayabusa.csv)"
fi

# ---------- 5) ค้นคำว่า flag ใน log ----------
step "5) ค้นคำว่า flag / csg ใน log"
grep -a -i -E 'flag|csg' "$OUT/evtx_dump.txt" 2>/dev/null | head -n 20

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- log ที่แปลงแล้ว : $OUT/evtx_dump.txt"
echo "- event น่าสนใจ   : $OUT/event_interesting.txt"
echo "- ทั้งหมดอยู่ที่    : $OUT/"
echo "- เคล็ดลับ: โจทย์มักซ่อนแฟล็กใน event 4688 (คำสั่งที่รัน) หรือ 7045 (ชื่อ service)"
