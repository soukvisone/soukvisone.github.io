#!/usr/bin/env bash
# ==========================================================================
#  archive_crack.sh  —  แตกไฟล์บีบอัด และเดารหัสผ่านถ้าติดรหัส
#  ทำอะไร: ดูรายชื่อไฟล์ข้างใน, ลองรหัสว่าง, ลองรหัสที่พบบ่อย,
#           แล้วใช้ john/fcrackzip กับ wordlist ถ้ายังไม่ได้
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash archive_crack.sh
# ==========================================================================

FILE="${1:-challenge.zip}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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

find_flags() {
  line "ค้นหา CSG_FLAG{ ในผลลัพธ์ทั้งหมด"
  local hits
  hits=$(grep -a -r -h -o 'CSG_FLAG{[^}]*}' "$OUT" 2>/dev/null | sort -u)
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | tee "$OUT/_FLAGS.txt"
    ok "พบแฟล็ก! บันทึกไว้ที่ $OUT/_FLAGS.txt"
  else
    warn "ยังไม่เจอ CSG_FLAG{ — ลอง misc/find_flag_everywhere.sh กับโฟลเดอร์ที่แตกออกมา"
  fi
}

line "เริ่มจัดการไฟล์บีบอัด: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
ls -lh "$FILE" | tee -a "$OUT/file.txt"

# ---------- 1) หา wordlist ----------
step "1) หา wordlist"
WORDLIST=""
for w in /usr/share/wordlists/rockyou.txt \
         /usr/share/wordlists/dirb/common.txt \
         /usr/share/wordlists/fasttrack.txt ; do
  if [ -f "$w" ]; then WORDLIST="$w"; break; fi
done
if [ -n "$WORDLIST" ]; then
  ok "ใช้ wordlist: $WORDLIST"
else
  warn "ไม่พบ wordlist — ติดตั้งด้วย:  sudo apt install -y wordlists"
  warn "แล้วรัน:  sudo gunzip /usr/share/wordlists/rockyou.txt.gz"
fi

# ---------- 2) ดูรายชื่อไฟล์ข้างใน ----------
step "2) ดูรายชื่อไฟล์ข้างใน"
if command -v 7z >/dev/null 2>&1; then
  7z l "$FILE" 2>&1 | tee "$OUT/7z_list.txt" | head -n 40
elif command -v unzip >/dev/null 2>&1; then
  unzip -l "$FILE" 2>&1 | tee "$OUT/unzip_list.txt" | head -n 40
else
  warn "ไม่พบ 7z หรือ unzip — ติดตั้งด้วย:  sudo apt install -y p7zip-full unzip"
fi

# ---------- 3) ลองแตกด้วยรหัสว่าง / รหัสที่พบบ่อย ----------
step "3) ลองรหัสผ่านที่พบบ่อย (ทำในเครื่องเท่านั้น)"
COMMON="password 123456 admin ctf flag csg csg2026 letmein root toor qwerty 12345678"
CRACKED=""

for pw in "" $COMMON; do
  if [ -z "$pw" ]; then label="(รหัสว่าง)"; else label="$pw"; fi

  case "$FILE" in
    *.zip)
      if unzip -o -q -P "$pw" "$FILE" -d "$OUT/extracted/try" >/dev/null 2>&1; then
        CRACKED="$pw"; ok "แตกได้ด้วยรหัส: $label"; break
      fi
      ;;
    *)
      if command -v 7z >/dev/null 2>&1; then
        if 7z x -y -p"$pw" -o"$OUT/extracted/try" "$FILE" >/dev/null 2>&1; then
          CRACKED="$pw"; ok "แตกได้ด้วยรหัส: $label"; break
        fi
      fi
      ;;
  esac
  printf '  ลองแล้ว: %s\n' "$label"
done

# ---------- 4) ถ้ายังไม่ได้ ใช้ john + zip2john ----------
if [ -z "$CRACKED" ]; then
  step "4) ยังไม่ได้รหัส — ใช้ john กับ wordlist"
  case "$FILE" in
    *.zip)
      if need zip2john john; then
        zip2john "$FILE" > "$OUT/hash_for_john.txt" 2>/dev/null
        if [ -s "$OUT/hash_for_john.txt" ]; then
          ok "สร้าง hash ให้ john แล้ว"
          if [ -n "$WORDLIST" ]; then
            echo "กำลังลอง wordlist (อาจใช้เวลาสักครู่)..."
            john --wordlist="$WORDLIST" "$OUT/hash_for_john.txt" 2>&1 | tail -n 15 | tee "$OUT/john_log.txt"
            # ดึงรหัสที่ john เจอ
            PW=$(john --show "$OUT/hash_for_john.txt" 2>/dev/null | head -n1 | cut -d: -f2)
            if [ -n "$PW" ]; then
              CRACKED="$PW"
              ok "john เจอรหัส: $PW"
              unzip -o -q -P "$PW" "$FILE" -d "$OUT/extracted/from_john" >/dev/null 2>&1
            fi
          fi
        fi
      fi
      # fcrackzip เป็นตัวสำรอง
      if [ -z "$CRACKED" ] && need fcrackzip; then
        if [ -n "$WORDLIST" ]; then
          fcrackzip -u -D -p "$WORDLIST" "$FILE" 2>&1 | tee "$OUT/fcrackzip.txt" | head -n 20
        fi
      fi
      ;;
    *)
      # 7z/rar ใช้ 7z2john หรือ rar2john
      for tool in 7z2john.pl 7z2john rar2john; do
        if command -v "$tool" >/dev/null 2>&1 && need john; then
          ok "ใช้ $tool"
          "$tool" "$FILE" > "$OUT/hash_for_john.txt" 2>/dev/null
          if [ -s "$OUT/hash_for_john.txt" ] && [ -n "$WORDLIST" ]; then
            john --wordlist="$WORDLIST" "$OUT/hash_for_john.txt" 2>&1 | tail -n 10
            PW=$(john --show "$OUT/hash_for_john.txt" 2>/dev/null | head -n1 | cut -d: -f2)
            [ -n "$PW" ] && CRACKED="$PW"
          fi
          break
        fi
      done
      ;;
  esac
fi

# ---------- 5) แตกไฟล์สุดท้าย ----------
step "5) แตกไฟล์ออกมาเก็บไว้"
if command -v 7z >/dev/null 2>&1; then
  7z x -y -p"${CRACKED}" -o"$OUT/extracted/final" "$FILE" > "$OUT/extract_log.txt" 2>&1
elif command -v unzip >/dev/null 2>&1; then
  unzip -o -q -P "${CRACKED}" "$FILE" -d "$OUT/extracted/final" > "$OUT/extract_log.txt" 2>&1
fi
find "$OUT/extracted/final" -type f 2>/dev/null | head -n 40 | sed 's/^/    /'

# ---------- 6) ค้นแฟล็กในไฟล์ที่แตกได้ ----------
step "6) ค้นแฟล็กในไฟล์ที่แตกออกมา"
grep -a -r -h -o 'CSG_FLAG{[^}]*}' "$OUT/extracted" 2>/dev/null | sort -u

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
if [ -n "$CRACKED" ]; then
  echo "- รหัสผ่าน    : $CRACKED"
else
  echo "- รหัสผ่าน    : ยังไม่พบ (ลอง wordlist ใหญ่ขึ้น หรือดูคำใบ้ในโจทย์)"
fi
echo "- ไฟล์ที่แตกได้ : $OUT/extracted/"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
echo
echo "คำสั่งที่ใช้ต่อได้เอง:"
echo "  unzip -P '$CRACKED' $FILE -d out/"
echo "  7z x -p'$CRACKED' $FILE -oout/"
