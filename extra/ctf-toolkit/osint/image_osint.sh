#!/usr/bin/env bash
# ==========================================================================
#  image_osint.sh  —  ดูข้อมูลในรูปว่าถ่ายที่ไหน เมื่อไหร่ ด้วยอะไร
#  ทำอะไร: ดึง metadata ทั้งหมด, แปลงพิกัด GPS เป็นลิงก์ Google Maps,
#           และดูข้อความที่ฝังมาในรูป
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash image_osint.sh
#  หมายเหตุ: สคริปต์ไม่ส่งรูปออกเน็ต — ลิงก์ที่ได้คัดลอกไปเปิดเองในเบราว์เซอร์
# ==========================================================================

FILE="${1:-photo.jpg}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลอง forensics/stego_image.sh กับรูปนี้ต่อ"
  fi
}

line "เริ่มตรวจรูป: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi

# ---------- 1) ชนิดและขนาด ----------
step "1) ชนิดไฟล์และขนาด"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
ls -l "$FILE" | tee -a "$OUT/file.txt"

# ---------- 2) metadata ทั้งหมด ----------
step "2) Metadata ทั้งหมด (exiftool)"
if need exiftool "sudo apt install -y libimage-exiftool-perl"; then
  exiftool -a -u -g1 "$FILE" > "$OUT/exiftool_all.txt" 2>&1
  head -n 45 "$OUT/exiftool_all.txt"
  echo "(ทั้งหมด -> $OUT/exiftool_all.txt)"
else
  warn "ติดตั้งได้ด้วย:  sudo apt install -y libimage-exiftool-perl"
fi

# ---------- 3) กล้อง / เวลา / ซอฟต์แวร์ ----------
step "3) กล้อง เวลา และโปรแกรมที่ใช้แต่งรูป"
if need exiftool "sudo apt install -y libimage-exiftool-perl"; then
  exiftool -Make -Model -LensModel -DateTimeOriginal -CreateDate \
           -Software -Artist -Copyright -Comment "$FILE" 2>/dev/null | tee "$OUT/camera_info.txt"
  echo
  echo "(ถ้ามีคำว่า Photoshop/GIMP แปลว่ารูปอาจถูกแก้ — ควรดู metadata ละเอียดขึ้น)"
fi

# ---------- 4) พิกัด GPS ----------
step "4) พิกัด GPS ในรูป"
if need exiftool "sudo apt install -y libimage-exiftool-perl"; then
  # ขอพิกัดแบบทศนิยมตรง ๆ (ถ้ามี)
  LAT=$(exiftool -s3 -GPSLatitude  "$FILE" 2>/dev/null)
  LON=$(exiftool -s3 -GPSLongitude "$FILE" 2>/dev/null)

  # บางไฟล์ให้มาเป็น องศา นาที วินาที + ตัวอักษร N/S/E/W จึงต้องคำนวณเอง
  if [ -z "$LAT" ] || [ -z "$LON" ]; then
    RAW_LAT=$(exiftool -s3 -n -GPSLatitude  "$FILE" 2>/dev/null)
    RAW_LON=$(exiftool -s3 -n -GPSLongitude "$FILE" 2>/dev/null)
    LAT="$RAW_LAT"
    LON="$RAW_LON"
  fi

  { exiftool -GPSLatitude -GPSLongitude -GPSLatitudeRef -GPSLongitudeRef \
             -GPSAltitude -GPSTimeStamp "$FILE" 2>/dev/null; } | tee "$OUT/gps_raw.txt"

  if [ -n "$LAT" ] && [ -n "$LON" ]; then
    # แปลงเป็นทศนิยม 6 ตำแหน่ง
    LAT6=$(python3 -c "print(f'{float('$LAT'):.6f}')" 2>/dev/null)
    LON6=$(python3 -c "print(f'{float('$LON'):.6f}')" 2>/dev/null)
    if [ -n "$LAT6" ] && [ -n "$LON6" ]; then
      ok "พิกัด: $LAT6, $LON6"
      echo "ลิงก์แผนที่ (คัดลอกไปเปิดในเบราว์เซอร์เอง):"
      echo "  https://www.google.com/maps?q=$LAT6,$LON6"
      echo "  https://www.openstreetmap.org/?mlat=$LAT6&mlon=$LON6#map=17/$LAT6/$LON6"
      printf 'lat=%s\nlon=%s\nhttps://www.google.com/maps?q=%s,%s\n' \
             "$LAT6" "$LON6" "$LAT6" "$LON6" > "$OUT/gps_decimal.txt"
    fi
  else
    warn "รูปนี้ไม่มีพิกัด GPS (หรือถูกอำพรางไว้)"
  fi
fi

# ---------- 5) ข้อความ/ข้อมูลที่ฝังในรูป ----------
step "5) ข้อความที่ฝังมาในรูป"
if need strings binutils; then
  strings -n 6 "$FILE" > "$OUT/strings.txt" 2>&1
  grep -a -i -E 'flag|csg|gps|comment|author' "$OUT/strings.txt" | head -n 20
fi

# ---------- 6) เบาะแสว่าเป็นรูปจากที่ไหน ----------
step "6) เบาะแสอื่น (ชื่อไฟล์, โปรแกรมแก้ไข)"
echo "ชื่อไฟล์: $(basename "$FILE")"
grep -a -i -E 'software|photoshop|gimp|lightroom|snapseed|instagram' "$OUT/exiftool_all.txt" 2>/dev/null | head -n 10

# ---------- 7) ถ้ามีไฟล์รูปอื่นในโฟลเดอร์เดียวกัน ----------
step "7) รูปอื่นที่อยู่โฟลเดอร์เดียวกัน (อาจเป็นชุดเดียวกัน)"
ls -1 "$(dirname "$FILE")" 2>/dev/null | grep -i -E '\.(jpg|jpeg|png|gif|webp|tif|tiff|heic)$' | head -n 20

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- กล้อง/เวลา : ดู $OUT/camera_info.txt"
echo "- พิกัด GPS   : $OUT/gps_decimal.txt (ถ้ามี)"
echo "- metadata ทั้งหมด : $OUT/exiftool_all.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
echo
echo "เคล็ดลับ OSINT: ถ้ารูปไม่มี GPS ให้ดูเงา/ป้าย/ภาษา/ป้ายทะเบียนในภาพ แล้วค้นด้วยภาพ"
echo "(ใช้เบราว์เซอร์เอง ไม่ต้องผ่านสคริปต์นี้)"
