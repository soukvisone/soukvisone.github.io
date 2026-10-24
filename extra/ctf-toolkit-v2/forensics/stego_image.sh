#!/usr/bin/env bash
# ==========================================================================
#  stego_image.sh  —  หาแฟล็กที่ซ่อนในรูปภาพ (Steganography)
#  ทำอะไร: ดู metadata, ข้อความในไฟล์, ไฟล์ที่ฝังมา, และถอดข้อมูลด้วย zsteg/steghide
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash stego_image.sh
# ==========================================================================

FILE="${1:-challenge.png}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลอง steghide ด้วย passphrase ที่เดาจากโจทย์ หรือดู spectrogram/ค่า LSB ต่อ"
  fi
}

line "เริ่มตรวจรูป: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi

# ---------- 1) ชนิดและขนาดรูป ----------
step "1) ชนิดไฟล์และขนาด"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
ls -l "$FILE" | tee -a "$OUT/file.txt"

# ---------- 2) metadata (บางโจทย์เขียนแฟล็กใน Comment/Artist) ----------
step "2) Metadata ด้วย exiftool"
if need exiftool "sudo apt install -y libimage-exiftool-perl"; then
  exiftool -a -u -g1 "$FILE" > "$OUT/exiftool.txt" 2>&1
  head -n 40 "$OUT/exiftool.txt"
  echo "(ทั้งหมดอยู่ที่ $OUT/exiftool.txt)"
fi

# ---------- 3) ข้อความที่อ่านได้ในไฟล์ ----------
step "3) strings — ข้อความ/แฟล็กที่เขียนตรง ๆ"
if need strings binutils; then
  strings -n 6 "$FILE" > "$OUT/strings_all.txt" 2>&1
  grep -a -i -E 'flag|csg|pass|secret' "$OUT/strings_all.txt" | head -n 30
fi

# ---------- 4) ไฟล์อื่นที่ซ่อนอยู่ข้างใน ----------
step "4) binwalk — หาไฟล์ที่ฝังมาในรูป"
if need binwalk; then
  binwalk "$FILE" 2>&1 | tee "$OUT/binwalk.txt" | head -n 25
  if grep -q -E '^[0-9]+' "$OUT/binwalk.txt"; then
    mkdir -p "$OUT/extracted"
    binwalk --run-as=root -e -C "$OUT/extracted" "$FILE" > "$OUT/binwalk_extract.txt" 2>&1
    echo "(สกัดไว้ที่ $OUT/extracted/ — ลองรัน file_triage.sh กับไฟล์ที่สกัดได้)"
  fi
fi

# ---------- 5) zsteg — ไล่ดูบิตซ่อนใน PNG/BMP ----------
step "5) zsteg — ข้อมูลซ่อนในบิตของรูป"
if need zsteg "sudo gem install zsteg"; then
  # -a = ลองทุกวิธี (ใช้เวลาสักครู่), เก็บทั้งหมดลงไฟล์
  zsteg -a "$FILE" > "$OUT/zsteg_all.txt" 2>&1
  head -n 30 "$OUT/zsteg_all.txt"
  echo "(zsteg ทั้งหมด $(wc -l < "$OUT/zsteg_all.txt") บรรทัด -> $OUT/zsteg_all.txt)"
fi

# ---------- 6) steghide — ถอดด้วยรหัสผ่านว่าง ----------
step "6) steghide — ลองรหัสผ่านว่าง (โจทย์ง่ายมักไม่ตั้งรหัส)"
if need steghide; then
  if ! steghide info "$FILE" -p "" > "$OUT/steghide_info.txt" 2>&1; then
    echo "(ไฟล์นี้อาจไม่ใช่ JPEG/BMP/WAV หรือไม่ได้ซ่อนด้วย steghide)"
  fi
  head -n 10 "$OUT/steghide_info.txt"
  FILE_ABS=$(readlink -f "$FILE" 2>/dev/null || printf '%s' "$FILE")
  ( cd "$OUT" && steghide extract -sf "$FILE_ABS" -p "" -f ) > "$OUT/steghide_extract.txt" 2>&1
  cat "$OUT/steghide_extract.txt"
  # ถ้าถอดได้ จะมีไฟล์โผล่มาในโฟลเดอร์ output
  ls -1 "$OUT" | grep -v -E '\.(txt)$' | sed 's/^/    พบไฟล์ใหม่: /'
fi

# ---------- 7) ข้อมูลเพิ่มเติมจากตัวรูปเอง ----------
step "7) ตรวจโครงสร้างรูป (pngcheck ถ้ามี)"
if need pngcheck; then
  pngcheck -v "$FILE" > "$OUT/pngcheck.txt" 2>&1
  tail -n 15 "$OUT/pngcheck.txt"
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ผลลัพธ์อยู่ที่ : $OUT/"
echo "- ถ้ายังไม่เจอ: ลองเดารหัส steghide จากชื่อโจทย์ เช่น"
echo "    steghide extract -sf $FILE -p '<รหัสที่เดา>' -f"
echo "- รูปที่ดูปกติอาจซ่อนข้อความแบบ LSB ให้ลอง zsteg -a ดูทั้งหมดใน zsteg_all.txt"
