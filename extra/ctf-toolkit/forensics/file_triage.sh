#!/usr/bin/env bash
# ==========================================================================
#  file_triage.sh  —  ตรวจไฟล์ปริศนาเบื้องต้น (ต้องรันก่อนเสมอ)
#  ทำอะไร: บอกชนิดไฟล์, metadata, ข้อความที่อ่านได้, ไฟล์ที่ซ่อนอยู่ข้างใน
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash file_triage.sh
# ==========================================================================

FILE="${1:-challenge.bin}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

# ---------- ตั้งค่าพื้นฐาน ----------
OUT="output_$(basename "$0" .sh)"   # โฟลเดอร์ผลลัพธ์: output_file_triage/
mkdir -p "$OUT"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

# need <คำสั่ง> <แพ็กเกจ>: ถ้าไม่มีจะบอกวิธีติดตั้งแล้วข้ามไป
need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้ามขั้นนี้) — ติดตั้งด้วย:  sudo apt install -y ${2:-$1}"
  return 1
}

# ค้นหาแฟล็กในทุกไฟล์ผลลัพธ์
find_flags() {
  line "ค้นหา CSG_FLAG{ ในผลลัพธ์ทั้งหมด"
  local hits
  hits=$(grep -a -r -h -o 'CSG_FLAG{[^}]*}' "$OUT" 2>/dev/null | sort -u)
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | tee "$OUT/_FLAGS.txt"
    ok "พบแฟล็ก! บันทึกไว้ที่ $OUT/_FLAGS.txt"
  else
    warn "ยังไม่เจอ CSG_FLAG{ — ลองสคริปต์หมวดอื่นต่อ (stego / crypto / misc)"
  fi
}

line "เริ่มตรวจไฟล์: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
ls -l "$FILE" | tee "$OUT/ls.txt"

# ---------- 1) ชนิดไฟล์จริง (ดู magic bytes ไม่ใช่ดูนามสกุล) ----------
step "1) ชนิดไฟล์"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
  file -b --mime-type "$FILE" | tee -a "$OUT/file.txt"
fi

# ---------- 2) metadata ทั้งหมด (บางโจทย์ซ่อนแฟล็กใน comment) ----------
step "2) Metadata ด้วย exiftool"
if need exiftool libimage-exiftool-perl; then
  exiftool -a -u -g1 "$FILE" > "$OUT/exiftool.txt" 2>&1
  head -n 40 "$OUT/exiftool.txt"
  echo "(บันทึกทั้งหมดไว้ที่ $OUT/exiftool.txt)"
fi

# ---------- 3) ข้อความที่ซ่อนในไฟล์ ----------
step "3) ข้อความที่อ่านได้ (strings)"
if need strings binutils; then
  strings -n 6 "$FILE" > "$OUT/strings_all.txt" 2>&1
  # หาเฉพาะบรรทัดที่น่าสนใจ
  grep -a -i -E 'flag|csg|pass|secret|key|hidden' "$OUT/strings_all.txt" \
      | head -n 40 | tee "$OUT/strings_interesting.txt"
  echo "(strings ทั้งหมด $(wc -l < "$OUT/strings_all.txt") บรรทัด -> $OUT/strings_all.txt)"
fi

# ---------- 4) ไฟล์/ข้อมูลที่ฝังอยู่ข้างใน ----------
step "4) ไฟล์ที่ซ่อนอยู่ข้างใน (binwalk)"
if need binwalk; then
  binwalk "$FILE" 2>&1 | tee "$OUT/binwalk.txt" | head -n 30
  # ถ้าเจอไฟล์ฝังอยู่ ให้สกัดออกมาไว้ในโฟลเดอร์ย่อย (ไม่ overwrite ของเดิม)
  if grep -q -E '^[0-9]+' "$OUT/binwalk.txt"; then
    mkdir -p "$OUT/extracted"
    binwalk --run-as=root -e -C "$OUT/extracted" "$FILE" > "$OUT/binwalk_extract.txt" 2>&1
    echo "(สกัดไฟล์ที่ฝังไว้ออกมาที่ $OUT/extracted/)"
  fi
fi

# ---------- 5) ไบต์ต้นไฟล์ (ดู magic แบบตาเปล่า) ----------
step "5) ไบต์ต้นไฟล์ 256 ไบต์แรก (xxd)"
if need xxd; then
  xxd -l 256 "$FILE" | tee "$OUT/xxd_head.txt"
fi

# ---------- 6) ค่า hash ไว้เทียบกับโจทย์อื่น ----------
step "6) ค่า hash ของไฟล์"
if need md5sum coreutils; then
  { md5sum "$FILE"; sha1sum "$FILE"; sha256sum "$FILE"; } 2>/dev/null | tee "$OUT/hashes.txt"
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ชนิดไฟล์   : $(cat "$OUT/file.txt" 2>/dev/null | head -n 1)"
echo "- ผลลัพธ์อยู่ที่ : $OUT/"
ls -1 "$OUT" | sed 's/^/    /'
