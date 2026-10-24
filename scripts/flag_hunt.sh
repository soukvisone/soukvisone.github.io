#!/usr/bin/env bash
# ==========================================================================
#  flag_hunt.sh — ไล่หา flag ในทุกที่ (ข้อความ / strings / base64 / hex / ไฟล์บีบอัด)
#  ใช้เมื่อ: มีโฟลเดอร์หรือไฟล์กองอยู่ แล้วไม่รู้ว่า flag อยู่ไหน
#
#  วิธีใช้:
#     bash flag_hunt.sh                 # สแกนโฟลเดอร์ปัจจุบัน
#     bash flag_hunt.sh ./challenge     # สแกนโฟลเดอร์/ไฟล์ที่ระบุ
#     bash flag_hunt.sh file.bin
# ==========================================================================

TARGET="${1:-.}"                     # <<< แก้บรรทัดนี้ได้ (หรือส่งเป็น argument)

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT/x"
HITS="$OUT/hits_raw.txt"
: > "$HITS"

# รูปแบบที่ 1: flag มาตรฐาน   2: คำนำหน้าอะไรก็ได้ + {...} (flag ที่ยังเข้ารหัส)
TIER1='[A-Za-z0-9_]{2,16}\{[^}]{2,300}\}'

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้ามขั้นนี้) — ติดตั้งด้วย:  sudo apt install -y ${2:-$1}"
  return 1
}

add_hit() {   # add_hit <match> <source>
  printf '%s\t%s\n' "$1" "$2" >> "$HITS"
}

line "เริ่มสแกน: $TARGET"
[ -e "$TARGET" ] || { warn "ไม่พบ '$TARGET'"; exit 1; }

# รายการไฟล์ (ข้ามไฟล์ใหญ่เกิน 300MB และข้ามโฟลเดอร์ผลลัพธ์ของตัวเอง)
LIST="$OUT/_files.txt"
if [ -d "$TARGET" ]; then
  find "$TARGET" -type f -size -300M -not -path "./$OUT/*" 2>/dev/null > "$LIST"
else
  printf '%s\n' "$TARGET" > "$LIST"
fi
echo "ไฟล์ทั้งหมด: $(wc -l < "$LIST")"

# ---------- 1) grep ตรง ๆ ----------
step "1) grep ตรง ๆ (ข้อความในไฟล์)"
while IFS= read -r f; do
  grep -a -o -E "$TIER1" "$f" 2>/dev/null | while IFS= read -r m; do add_hit "$m" "$f"; done
done < "$LIST"
echo "เจอ $(wc -l < "$HITS") รายการ"

# ---------- 2) strings ----------
step "2) strings (ไฟล์ไบนารี/รูป/บีบอัด)"
if need strings binutils; then
  BEFORE=$(wc -l < "$HITS")
  while IFS= read -r f; do
    strings -n 6 "$f" 2>/dev/null | grep -a -o -E "$TIER1" 2>/dev/null \
      | while IFS= read -r m; do add_hit "$m" "$f (strings)"; done
  done < "$LIST"
  echo "เพิ่ม $(($(wc -l < "$HITS") - BEFORE)) รายการ"
fi

# ---------- 3) base64 ที่ฝังอยู่ ----------
step "3) ถอด base64 ที่ฝังในไฟล์ แล้วค้นซ้ำ"
if need base64 coreutils && need strings binutils; then
  BEFORE=$(wc -l < "$HITS")
  while IFS= read -r f; do
    strings -n 24 "$f" 2>/dev/null | grep -a -o -E '[A-Za-z0-9+/]{24,}={0,2}' | sort -u | head -80 \
    | while IFS= read -r blob; do
        dec=$(printf '%s' "$blob" | base64 -d 2>/dev/null | tr -d '\000')
        printf '%s' "$dec" | grep -a -o -E "$TIER1" 2>/dev/null \
          | while IFS= read -r m; do add_hit "$m" "$f (base64)"; done
      done
  done < "$LIST"
  echo "เพิ่ม $(($(wc -l < "$HITS") - BEFORE)) รายการ"
fi

# ---------- 4) hex ----------
step "4) ถอด hex ที่ฝังในไฟล์"
if need xxd; then
  BEFORE=$(wc -l < "$HITS")
  while IFS= read -r f; do
    strings -n 20 "$f" 2>/dev/null | grep -a -E '^[0-9a-fA-F]{20,}$' | sort -u | head -40 \
    | while IFS= read -r hx; do
        dec=$(printf '%s' "$hx" | xxd -r -p 2>/dev/null | tr -d '\000')
        printf '%s' "$dec" | grep -a -o -E "$TIER1" 2>/dev/null \
          | while IFS= read -r m; do add_hit "$m" "$f (hex)"; done
      done
  done < "$LIST"
  echo "เพิ่ม $(($(wc -l < "$HITS") - BEFORE)) รายการ"
fi

# ---------- 5) แตกไฟล์บีบอัด 2 ชั้น ----------
step "5) แตกไฟล์บีบอัดแล้วค้นข้างใน (2 ชั้น)"
for lvl in 1 2; do
  found=0
  while IFS= read -r f; do
    dest="$OUT/x/L${lvl}/$(basename "$f")"
    mkdir -p "$dest" 2>/dev/null || continue
    case "$f" in
      *.zip)
        if command -v unzip >/dev/null 2>&1; then
          unzip -o -q -P "" "$f" -d "$dest" 2>/dev/null || unzip -o -q "$f" -d "$dest" 2>/dev/null
          found=$((found+1))
        fi ;;
      *.tar)      tar -xf "$f" -C "$dest" 2>/dev/null && found=$((found+1)) ;;
      *.gz|*.tgz) tar -xzf "$f" -C "$dest" 2>/dev/null || gunzip -c "$f" > "$dest/out.bin" 2>/dev/null && found=$((found+1)) ;;
      *.7z|*.rar) command -v 7z >/dev/null 2>&1 && 7z x -y -o"$dest" "$f" >/dev/null 2>&1 && found=$((found+1)) ;;
    esac
  done < "$LIST"

  [ "$found" -eq 0 ] && { echo "(ชั้น $lvl: ไม่มีไฟล์บีบอัด)"; break; }
  echo "(ชั้น $lvl: แตกได้ $found ไฟล์)"

  find "$OUT/x/L${lvl}" -type f 2>/dev/null > "$OUT/_l${lvl}.txt"
  while IFS= read -r f; do
    grep -a -o -E "$TIER1" "$f" 2>/dev/null | while IFS= read -r m; do add_hit "$m" "$f (archive L$lvl)"; done
    strings -n 6 "$f" 2>/dev/null | grep -a -o -E "$TIER1" | while IFS= read -r m; do add_hit "$m" "$f (archive L$lvl strings)"; done
  done < "$OUT/_l${lvl}.txt"

  # เตรียมรายการสำหรับชั้นถัดไป
  cp "$OUT/_l${lvl}.txt" "$LIST".next && LIST="$LIST".next
done

# ---------- 6) สรุป ----------
line "สรุปผล"
sort -u "$HITS" > "$OUT/hits.txt" 2>/dev/null
STRICT_HITS="$OUT/_flags.txt"

# แยกชั้น: flag มาตรฐาน vs candidate
awk -F'\t' '$1 ~ /^CSG_FLAG\{/ {print $1}' "$OUT/hits.txt" | sort -u > "$STRICT_HITS.1" 2>/dev/null
awk -F'\t' '$1 !~ /^CSG_FLAG\{/ {print $1}' "$OUT/hits.txt" | sort -u > "$STRICT_HITS.2" 2>/dev/null

if [ -s "$STRICT_HITS.1" ]; then
  ok "พบ flag มาตรฐาน:"
  cat "$STRICT_HITS.1" | sed 's/^/    /'
  cp "$STRICT_HITS.1" "$OUT/_FLAGS.txt"
else
  warn "ไม่พบรูปแบบ CSG_FLAG{...} ตรง ๆ"
fi

if [ -s "$STRICT_HITS.2" ]; then
  echo
  echo "พบชื่อรูปแบบอื่น (อาจเป็น flag ที่ยังเข้ารหัสอยู่ — เอาไปถอดต่อ):"
  head -n 30 "$STRICT_HITS.2" | sed 's/^/    /'
fi

echo
echo "- รายการทั้งหมด : $OUT/hits.txt  ($(wc -l < "$OUT/hits.txt") บรรทัด)"
echo "- ไฟล์ที่แตกได้  : $OUT/x/"
echo "- ถ้าไม่เจอ: ลอง automation/auto_triage.sh กับไฟล์ต้นทาง หรือแก้ XOR/base64 ต่อ"
