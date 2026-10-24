#!/usr/bin/env bash
# ==========================================================================
#  disk_image.sh  —  ดูโครงสร้างอิมเมจดิสก์ และกู้ไฟล์ที่ถูกลบ
#  ทำอะไร: หาพาร์ทิชัน, ไล่รายชื่อไฟล์ทั้งหมด, กู้ไฟล์ที่ถูกลบออกมา
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash disk_image.sh
#  หมายเหตุ: ถ้าเป็นอิมเมจทั้งลูก ให้สคริปต์หาพาร์ทิชันเองอัตโนมัติ
# =============================================================================

FILE="${1:-disk.img}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT/recovered"

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
    warn "ยังไม่เจอ CSG_FLAG{ — ไฟล์ที่กู้มาอาจเป็น binary ให้รัน strings ในโฟลเดอร์ recovered/"
  fi
}

line "เริ่มตรวจอิมเมจดิสก์: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
if ! need mmls sleuthkit; then
  warn "สคริปต์นี้ต้องใช้ชุด SleuthKit (mmls/fls/icat) — ติดตั้งก่อนแล้วรันใหม่"
  exit 1
fi
ls -lh "$FILE" | tee "$OUT/file_info.txt"

# ---------- 1) ตารางพาร์ทิชัน ----------
step "1) ตารางพาร์ทิชัน (mmls)"
mmls "$FILE" > "$OUT/mmls.txt" 2>&1
cat "$OUT/mmls.txt"

# หา offset (หน่วยเป็น sector) ของพาร์ทิชันแรกโดยอัตโนมัติ
# บรรทัดตัวอย่าง: 001:  NTFS  0000000040  0000204863  0000204824  NTFS / exFAT
OFF=$(awk '$1 ~ /^[0-9]+:$/ && $3 ~ /^[0-9]+$/ {print $3; exit}' "$OUT/mmls.txt")
if [ -z "$OFF" ]; then
  # ถ้าหาไม่ได้ แปลว่าเป็นอิมเมจของพาร์ทิชันเดี่ยว เริ่มที่ 0
  OFF=0
fi
echo "-> ใช้ offset เริ่มต้น: $OFF (sector)"
printf '%s\n' "$OFF" > "$OUT/offset.txt"

# ---------- 2) รายชื่อไฟล์ทั้งหมด (รวมไฟล์ที่ถูกลบ) ----------
step "2) รายชื่อไฟล์ทั้งหมด (fls -r)"
fls -r -p -o "$OFF" "$FILE" > "$OUT/fls_all.txt" 2>&1
head -n 40 "$OUT/fls_all.txt"
echo "(ทั้งหมด $(wc -l < "$OUT/fls_all.txt") บรรทัด -> $OUT/fls_all.txt)"

# ---------- 3) เฉพาะไฟล์ที่ถูกลบ ----------
step "3) ไฟล์ที่ถูกลบแล้ว (เครื่องหมาย * หน้าชื่อ)"
fls -r -d -p -o "$OFF" "$FILE" > "$OUT/fls_deleted.txt" 2>&1
head -n 40 "$OUT/fls_deleted.txt"

# ---------- 4) กู้ไฟล์ที่ถูกลบออกมา ----------
step "4) กู้ไฟล์ที่ถูกลบ (tsk_recover -e)"
if need tsk_recover sleuthkit; then
  tsk_recover -e -o "$OFF" "$FILE" "$OUT/recovered" > "$OUT/tsk_recover.txt" 2>&1
  ok "กู้ไฟล์ไว้ที่ $OUT/recovered/"
  ls -1 "$OUT/recovered" | head -n 30 | sed 's/^/    /'
else
  # ถ้าไม่มี tsk_recover ให้ใช้ icat ทีละ inode แทน
  warn "ใช้ icat แทน (ช้ากว่า) — กู้เฉพาะ 20 ไฟล์แรก"
  n=0
  while read -r inode; do
    [ -z "$inode" ] && continue
    icat -o "$OFF" "$FILE" "$inode" > "$OUT/recovered/file_$inode" 2>/dev/null
    n=$((n+1))
    [ "$n" -ge 20 ] && break
  done < <(grep -a -E '^\*| r/r \*' "$OUT/fls_deleted.txt" | awk '{print $2}' | tr -d '*:')
fi

# ---------- 5) หาคำว่า flag ในไฟล์ที่กู้มา ----------
step "5) ค้นคำว่า flag ในไฟล์ที่กู้มา"
grep -a -r -i -E 'flag|csg' "$OUT/recovered" 2>/dev/null | head -n 20

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- offset พาร์ทิชัน : $OFF"
echo "- ไฟล์ทั้งหมด      : $(wc -l < "$OUT/fls_all.txt" 2>/dev/null) บรรทัด"
echo "- ไฟล์ที่ถูกลบ     : $(wc -l < "$OUT/fls_deleted.txt" 2>/dev/null) บรรทัด"
echo "- ไฟล์ที่กู้ได้     : $(ls -1 "$OUT/recovered" 2>/dev/null | wc -l) ไฟล์ -> $OUT/recovered/"
echo "- ทั้งหมดอยู่ที่    : $OUT/"
