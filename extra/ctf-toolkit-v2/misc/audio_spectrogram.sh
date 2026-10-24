#!/usr/bin/env bash
# ==========================================================================
#  audio_spectrogram.sh  —  วิเคราะห์ไฟล์เสียงที่ซ่อนข้อความ/แฟล็ก
#  ทำอะไร: ดูข้อมูลไฟล์, แปลงเป็นภาพ spectrogram (เห็นข้อความที่ซ่อน),
#           ตรวจสัญญาณ DTMF (เสียงกดปุ่มโทรศัพท์) และเบาะแสมอร์ส
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash audio_spectrogram.sh
#  ผลลัพธ์: เปิดดูภาพในโฟลเดอร์ output_audio_spectrogram/
# ==========================================================================

FILE="${1:-challenge.wav}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ให้เปิดดู spectrogram.png ด้วยตา (ข้อความมักเขียนด้วยคลื่นเสียง)"
  fi
}

line "เริ่มวิเคราะห์เสียง: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi

# ---------- 1) ข้อมูลไฟล์ ----------
step "1) ข้อมูลไฟล์เสียง"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
ls -lh "$FILE" | tee -a "$OUT/file.txt"

# ---------- 2) ข้อมูลโดยละเอียดด้วย sox ----------
step "2) ข้อมูลเสียง (sox --i)"
if need sox; then
  sox --i "$FILE" 2>&1 | tee "$OUT/sox_info.txt"
  echo
  echo "หมายเหตุ: อ่านค่า 'Channels' และ 'Sample Rate' ไว้ปรับภาพ spectrogram"
else
  warn "ติดตั้งได้ด้วย:  sudo apt install -y sox"
fi

# ---------- 3) สร้าง spectrogram ----------
step "3) สร้างภาพ spectrogram (หัวใจของโจทย์เสียง)"
if need sox; then
  # ภาพแบบปกติ — เห็นทั้งไฟล์
  sox "$FILE" -n spectrogram -o "$OUT/spectrogram.png" -x 1200 -y 513 -z 100 2>&1 \
    || warn "สร้าง spectrogram ไม่สำเร็จ (ไฟล์อาจเสียหาย)"

  # ภาพแบบละเอียด (เห็นความถี่ต่ำชัดขึ้น — ข้อความมักอยู่ช่วง 0-8kHz)
  sox "$FILE" -n spectrogram -o "$OUT/spectrogram_tall.png" -x 2000 -y 1025 -z 120 2>&1

  # ภาพแบบกว้างมาก (เหมาะกับข้อความยาว)
  sox "$FILE" -n spectrogram -o "$OUT/spectrogram_wide.png" -x 4000 -y 513 -z 90 2>&1

  ls -lh "$OUT"/spectrogram*.png 2>/dev/null | awk '{print "    "$9" ("$5")"}'
  ok "เปิดดูภาพเหล่านี้ด้วยตา: $OUT/spectrogram.png"
else
  warn "ข้ามขั้นนี้เพราะไม่มี sox — ติดตั้งด้วย:  sudo apt install -y sox"
fi

# ---------- 4) ตรวจ DTMF (เสียงกดปุ่มโทรศัพท์) ----------
step "4) ตรวจเสียง DTMF (ถ้าเป็นเสียงกดปุ่ม จะได้ตัวเลข)"
if need multimon-ng; then
  multimon-ng -t wav -a DTMF "$FILE" > "$OUT/dtmf.txt" 2>&1
  if [ -s "$OUT/dtmf.txt" ]; then
    head -n 30 "$OUT/dtmf.txt"
    echo "-> ตัวเลขที่ได้อาจเป็นรหัสผ่านของไฟล์อื่น"
  else
    echo "(ไม่พบสัญญาณ DTMF)"
  fi
else
  warn "ติดตั้งได้ด้วย:  sudo apt install -y multimon-ng"
fi

# ---------- 5) เบาะแสมอร์ส ----------
step "5) เบาะแสมอร์ส (ฟังจังหวะสั้น/ยาว)"
if need sox; then
  # แปลงเป็นไฟล์เสียงโมโนความถี่ต่ำ เพื่อให้ฟังง่ายขึ้น (ไม่บังคับ)
  sox "$FILE" "$OUT/mono.wav" remix 1 2>/dev/null
  echo "ไฟล์เสียงโมโน: $OUT/mono.wav (เปิดฟังด้วยโปรแกรมเล่นเสียง)"
  echo "ถ้าได้ยินเสียงสั้น/ยาวเป็นจังหวะ ให้จดเป็น . และ - แล้วใช้ crypto/auto_decode.py"
fi

# ---------- 6) ข้อมูลที่ซ่อนในไฟล์ ----------
step "6) ข้อมูลอื่นที่ฝังในไฟล์เสียง"
if need strings binutils; then
  strings -n 6 "$FILE" > "$OUT/strings.txt" 2>&1
  grep -a -i -E 'flag|csg|morse|dtmf' "$OUT/strings.txt" | head -n 20
fi

if need binwalk; then
  binwalk "$FILE" 2>&1 | head -n 15 | tee "$OUT/binwalk.txt"
fi

# ---------- 7) ตรวจคลื่นแบบกลับด้าน (Reverse audio) ----------
step "7) ลองกลับด้านเสียง (บางโจทย์ซ่อนข้อความแบบเล่นย้อนกลับ)"
if need sox; then
  sox "$FILE" "$OUT/reversed.wav" reverse 2>/dev/null
  if [ -f "$OUT/reversed.wav" ]; then
    ok "สร้างไฟล์เสียงย้อนกลับแล้ว: $OUT/reversed.wav (ลองฟังดู)"
    sox "$OUT/reversed.wav" -n spectrogram -o "$OUT/spectrogram_reversed.png" -x 1200 -y 513 2>/dev/null
  fi
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ข้อมูลเสียง   : $OUT/sox_info.txt"
echo "- ภาพ spectrogram: $OUT/spectrogram.png (สำคัญที่สุด)"
echo "- DTMF          : $OUT/dtmf.txt"
echo "- เสียงย้อนกลับ  : $OUT/reversed.wav"
echo "- ทั้งหมดอยู่ที่  : $OUT/"
echo
echo "วิธีอ่าน spectrogram: เปิดไฟล์ png แล้วมองหาตัวอักษร/รูปแบบที่เขียนด้วยคลื่น"
echo "ถ้าภาพเล็กเกินไป ให้เร่งความกว้าง: sox $FILE -n spectrogram -o big.png -x 4000"
