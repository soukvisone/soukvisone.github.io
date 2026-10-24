#!/usr/bin/env bash
# ==========================================================================
#  find_flag_everywhere.sh  —  ไล่หา CSG_FLAG{ ในทุกที่ที่เป็นไปได้
#  ทำอะไร: ค้นในไฟล์ข้อความ, ใน strings ของไฟล์ไบนารี, ในข้อมูล base64,
#           และแตกไฟล์ zip/tar/gz ที่เจอแล้วค้นข้างในต่อ (ลึก 3 ชั้น)
#
#  วิธีใช้: แก้บรรทัด TARGET แล้วรัน   bash find_flag_everywhere.sh
#  หมายเหตุ: ใช้ได้ทั้งระบุเป็นโฟลเดอร์ หรือไฟล์เดียว
# ==========================================================================

TARGET="challenge"          # <<< แก้บรรทัดนี้บรรทัดเดียว (โฟลเดอร์หรือไฟล์)

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT/extracted"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้ามขั้นนี้) — ติดตั้งด้วย:  sudo apt install -y ${2:-$1}"
  return 1
}

PATTERN='CSG_FLAG{[^}]*}'
HITS="$OUT/hits.txt"      # ไฟล์รวมผลลัพธ์ทั้งหมด
: > "$HITS"

add_hit() {   # add_hit <แหล่งที่มา> <ข้อความที่เจอ>
  printf '%s  |  %s\n' "$2" "$1" >> "$HITS"
}

line "เริ่มค้นหาใน: $TARGET"
if [ ! -e "$TARGET" ]; then
  warn "ไม่พบ '$TARGET' — ตรวจชื่อไฟล์/โฟลเดอร์อีกครั้ง"
  exit 1
fi

# เก็บรายการไฟล์ทั้งหมด (ถ้า TARGET เป็นไฟล์เดียว ก็มีไฟล์เดียว)
ALL_FILES="$OUT/_filelist.txt"
if [ -d "$TARGET" ]; then
  find "$TARGET" -type f 2>/dev/null > "$ALL_FILES"
else
  printf '%s\n' "$TARGET" > "$ALL_FILES"
fi
echo "ไฟล์ทั้งหมด: $(wc -l < "$ALL_FILES") ไฟล์"

# ---------- 1) ค้นตรง ๆ ในไฟล์ ----------
step "1) ค้นข้อความตรง ๆ (grep)"
grep -a -r -h -o -E "$PATTERN" "$TARGET" 2>/dev/null | sort -u > "$OUT/direct.txt"
if [ -s "$OUT/direct.txt" ]; then
  while read -r f; do add_hit "grep ตรง" "$f"; done < "$OUT/direct.txt"
  cat "$OUT/direct.txt"
else
  echo "(ไม่พบในข้อความตรง ๆ)"
fi

# ---------- 2) ค้นใน strings ของทุกไฟล์ ----------
step "2) ค้นใน strings (ไฟล์ไบนารี/รูป/ไฟล์บีบอัด)"
if need strings binutils; then
  : > "$OUT/strings_hits.txt"
  while read -r f; do
    [ -f "$f" ] || continue
    strings -n 6 "$f" 2>/dev/null | grep -a -o -E "$PATTERN" 2>/dev/null \
      | while read -r hit; do
          printf '%s  |  %s\n' "$hit" "$f" >> "$OUT/strings_hits.txt"
        done
  done < "$ALL_FILES"

  if [ -s "$OUT/strings_hits.txt" ]; then
    sort -u "$OUT/strings_hits.txt" | tee "$OUT/strings_hits_sorted.txt"
    while read -r line_hit; do
      add_hit "strings" "${line_hit%%  |  *}"
    done < "$OUT/strings_hits.txt"
  else
    echo "(ไม่พบใน strings)"
  fi
fi

# ---------- 3) ถอด base64 ที่เจอในไฟล์ แล้วค้นซ้ำ ----------
step "3) ถอด base64 ที่ฝังอยู่ในข้อความ แล้วค้นซ้ำ"
if need base64 coreutils && need strings binutils; then
  : > "$OUT/base64_hits.txt"
  while read -r f; do
    [ -f "$f" ] || continue
    # ดึงสตริงที่มีลักษณะเป็น base64 (อย่างน้อย 24 ตัว)
    strings -n 24 "$f" 2>/dev/null | grep -a -o -E '[A-Za-z0-9+/]{24,}={0,2}' | sort -u | head -n 200 \
    | while read -r blob; do
        decoded=$(printf '%s' "$blob" | base64 -d 2>/dev/null | tr -d '\000' | head -c 4000)
        if printf '%s' "$decoded" | grep -a -q -E "$PATTERN"; then
          printf '%s  |  %s\n' "$(printf '%s' "$decoded" | grep -a -o -E "$PATTERN" | head -n1)" "$f" \
            >> "$OUT/base64_hits.txt"
          printf '  [base64] %s\n    จากไฟล์: %s\n' "$blob" "$f"
        fi
      done
  done < "$ALL_FILES"
  if [ -s "$OUT/base64_hits.txt" ]; then
    sort -u "$OUT/base64_hits.txt"
  else
    echo "(ไม่พบแฟล็กที่ซ่อนใน base64)"
  fi
fi

# ---------- 4) แตกไฟล์บีบอัดแล้วค้นข้างใน (ลึก 3 ชั้น) ----------
step "4) แตกไฟล์ zip/tar/gz แล้วค้นข้างใน"
if need 7z p7zip-full; then :; fi      # 7z ใช้เสริม ถ้าไม่มีก็ข้ามได้

LEVEL_DIRS="$ALL_FILES"
for lvl in 1 2 3; do
  NEW_DIRS="$OUT/_level${lvl}_dirs.txt"
  : > "$NEW_DIRS"
  while read -r f; do
    [ -f "$f" ] || continue
    dest="$OUT/extracted/L${lvl}/$(basename "$f")"
    mkdir -p "$dest"

    case "$f" in
      *.zip)
        if command -v unzip >/dev/null 2>&1; then
          unzip -o -q -P "" "$f" -d "$dest" >/dev/null 2>&1 \
            || unzip -o -q "$f" -d "$dest" >/dev/null 2>&1
          printf '%s\n' "$dest" >> "$NEW_DIRS"
        fi
        ;;
      *.tar)
        tar -xf "$f" -C "$dest" >/dev/null 2>&1 && printf '%s\n' "$dest" >> "$NEW_DIRS"
        ;;
      *.tar.gz|*.tgz|*.gz|*.bz2|*.xz)
        if command -v 7z >/dev/null 2>&1; then
          7z x -y -o"$dest" "$f" >/dev/null 2>&1 && printf '%s\n' "$dest" >> "$NEW_DIRS"
        else
          tar -xf "$f" -C "$dest" >/dev/null 2>&1 && printf '%s\n' "$dest" >> "$NEW_DIRS"
        fi
        ;;
      *.7z|*.rar)
        if command -v 7z >/dev/null 2>&1; then
          7z x -y -o"$dest" "$f" >/dev/null 2>&1 && printf '%s\n' "$dest" >> "$NEW_DIRS"
        fi
        ;;
      *) : ;;
    esac
  done < "$LEVEL_DIRS"

  if [ ! -s "$NEW_DIRS" ]; then
    echo "(ชั้น $lvl: ไม่มีไฟล์บีบอัดให้แตกแล้ว)"
    break
  fi

  echo "(ชั้น $lvl: แตกได้ $(wc -l < "$NEW_DIRS") ที่)"
  while read -r d; do
    grep -a -r -h -o -E "$PATTERN" "$d" 2>/dev/null | sort -u | while read -r hit; do
      printf '%s  |  %s\n' "$hit" "$d" >> "$HITS"
      printf '  [+] %s  (ใน %s)\n' "$hit" "$d"
    done
  done < "$NEW_DIRS"

  # เตรียมรายการไฟล์สำหรับชั้นถัดไป
  : > "$OUT/_next_files.txt"
  while read -r d; do
    find "$d" -type f 2>/dev/null >> "$OUT/_next_files.txt"
  done < "$NEW_DIRS"
  LEVEL_DIRS="$OUT/_next_files.txt"
done

# ---------- 5) สรุป ----------
line "5) สรุป: แฟล็กทั้งหมดที่เจอ"
if [ -s "$HITS" ]; then
  sort -u "$HITS" | tee "$OUT/_FLAGS.txt"
  ok "พบแฟล็ก! (รายละเอียดอยู่ที่ $OUT/_FLAGS.txt)"
else
  warn "ยังไม่พบ CSG_FLAG{ เลย"
  echo "  ลองต่อ:"
  echo "   - forensics/file_triage.sh   (ดูว่าไฟล์เป็นอะไร)"
  echo "   - crypto/auto_decode.py      (ถ้าข้อความถูกเข้ารหัสหลายชั้น)"
  echo "   - misc/archive_crack.sh      (ถ้าไฟล์บีบอัดมีรหัสผ่าน)"
fi

echo
echo "- ไฟล์ที่สแกน   : $(wc -l < "$ALL_FILES")"
echo "- ผลตรง ๆ        : $OUT/direct.txt"
echo "- ผลจาก strings  : $OUT/strings_hits.txt"
echo "- ผลจาก base64   : $OUT/base64_hits.txt"
echo "- ไฟล์ที่แตกออก  : $OUT/extracted/"
echo "- ทั้งหมดอยู่ที่  : $OUT/"
