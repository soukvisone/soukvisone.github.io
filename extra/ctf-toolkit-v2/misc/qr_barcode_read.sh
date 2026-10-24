#!/usr/bin/env bash
# ==========================================================================
#  qr_barcode_read.sh  —  อ่าน QR code / บาร์โค้ดจากรูป
#  ทำอะไร: สแกนรูปด้วย zbarimg, แสดงข้อความที่ซ่อนใน QR,
#           และถ้าใน QR เป็น base64/hex จะถอดให้ด้วย
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash qr_barcode_read.sh
# ==========================================================================

FILE="${1:-qr.png}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ถ้า QR ให้ URL มา ให้เปิดดูด้วยเบราว์เซอร์เอง"
  fi
}

line "เริ่มอ่าน QR/บาร์โค้ด: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi

# ---------- 1) ชนิดไฟล์ ----------
step "1) ชนิดไฟล์"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi

# ---------- 2) สแกนด้วย zbarimg ----------
step "2) สแกนด้วย zbarimg"
if need zbarimg zbar-tools; then
  # --raw = เอาข้อความดิบ (ไม่ต้องมี prefix)
  zbarimg -q --raw "$FILE" > "$OUT/qr_content.txt" 2> "$OUT/zbarimg_err.txt"
  if [ -s "$OUT/qr_content.txt" ]; then
    ok "อ่านได้:"
    cat "$OUT/qr_content.txt"
  else
    warn "อ่านไม่ได้ — รูปอาจเบลอ/เล็กเกินไป/ไม่ใช่ QR"
    echo "(ลองขยายรูปก่อนด้วย: convert input.png -resize 300% big.png)"
  fi
else
  warn "ติดตั้งได้ด้วย:  sudo apt install -y zbar-tools"
fi

# ---------- 3) ถ้า QR มีหลายอันในรูป ----------
step "3) ตรวจว่ามี QR หลายอันในรูปเดียวไหม"
if need zbarimg zbar-tools; then
  COUNT=$(zbarimg -q "$FILE" 2>/dev/null | wc -l)
  echo "พบสัญลักษณ์ทั้งหมด: $COUNT"
  zbarimg -q "$FILE" 2>/dev/null | head -n 20
fi

# ---------- 4) ถ้าข้อความใน QR ถูกเข้ารหัสอีกชั้น ----------
step "4) ถ้าเนื้อหาใน QR เป็น base64 / hex ให้ถอดให้"
if [ -s "$OUT/qr_content.txt" ]; then
  CONTENT=$(head -c 2000 "$OUT/qr_content.txt")

  # ลอง base64
  if printf '%s' "$CONTENT" | grep -q -E '^[A-Za-z0-9+/=]{8,}$'; then
    DEC=$(printf '%s' "$CONTENT" | base64 -d 2>/dev/null | tr -d '\000')
    if [ -n "$DEC" ]; then
      echo "--- ถอด base64 ---"
      printf '%s\n' "$DEC" | tee "$OUT/qr_base64_decoded.txt"
    fi
  fi

  # ลอง hex
  if printf '%s' "$CONTENT" | grep -q -E '^[0-9a-fA-F]+$' && [ $(( ${#CONTENT} % 2 )) -eq 0 ]; then
    echo "--- ถอด hex ---"
    printf '%s' "$CONTENT" | xxd -r -p 2>/dev/null | tee "$OUT/qr_hex_decoded.txt"
    echo
  fi

  # ถ้าเป็น URL ให้เตือนเรื่องความปลอดภัย
  case "$CONTENT" in
    http://*|https://*)
      warn "เนื้อหาเป็น URL — อย่าเพิ่งเปิดถ้าไม่ไว้ใจ ตรวจโดเมนก่อน"
      ;;
  esac
fi

# ---------- 5) ถ้าเป็นรูปที่ซ่อนข้อมูล ให้ตรวจต่อ ----------
step "5) ตรวจข้อมูลอื่นในรูป (เผื่อมีมากกว่า QR)"
if need strings binutils; then
  strings -n 6 "$FILE" | grep -a -i -E 'flag|csg' | head -n 10
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- เนื้อหาใน QR : $OUT/qr_content.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
if [ -s "$OUT/qr_content.txt" ]; then
  echo "- ข้อความ: $(head -c 200 "$OUT/qr_content.txt")"
fi
