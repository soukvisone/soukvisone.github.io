#!/usr/bin/env bash
# ==========================================================================
#  bin_info.sh  —  ดูโครงสร้างไฟล์โปรแกรม (ELF) ก่อนลงมือ reverse
#  ทำอะไร: บอกสถาปัตยกรรม, การป้องกัน (checksec), ข้อความในไฟล์,
#           symbol, และชุดคำสั่ง assembly ช่วงแรก
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash bin_info.sh
# ==========================================================================

FILE="${1:-challenge}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — แฟล็กอาจถูกประกอบตอนรัน ให้ลอง dynamic_trace.sh หรือ gdb"
  fi
}

line "เริ่มตรวจไฟล์โปรแกรม: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
# ให้สิทธิ์รัน (จำเป็นถ้าจะรันโปรแกรมดู)
chmod +x "$FILE" 2>/dev/null

# ---------- 1) ชนิดและสถาปัตยกรรม ----------
step "1) ชนิดไฟล์ / สถาปัตยกรรม"
if need file; then
  file "$FILE" | tee "$OUT/file.txt"
fi
ls -l "$FILE" | tee -a "$OUT/file.txt"

# ---------- 2) การป้องกันของโปรแกรม ----------
step "2) การป้องกัน (checksec)"
if need checksec; then
  checksec --file="$FILE" 2>&1 | tee "$OUT/checksec.txt"
  echo
  echo "อ่านผล:"
  echo "  NX enabled    = มีป้องกันการรันโค้ดบน stack"
  echo "  PIE enabled   = ที่อยู่หน่วยความจำสุ่ม (exploit ยากขึ้น)"
  echo "  Canary found  = มีตัวกันการเขียนทับ return address"
  echo "  No canary     = เขียนทับ return address ได้ -> เหมาะกับ ret2win"
else
  warn "ติดตั้ง checksec ได้ด้วย:  sudo apt install -y checksec  (หรือ pip install pwntools)"
fi

# ---------- 3) ข้อความในไฟล์ ----------
step "3) ข้อความในไฟล์ (strings)"
if need strings binutils; then
  strings -n 5 "$FILE" > "$OUT/strings_all.txt" 2>&1
  # คำที่มักเป็นแฟล็กหรือเบาะแส
  grep -a -i -E 'flag|csg|pass|secret|correct|wrong|win|/bin/sh' "$OUT/strings_all.txt" \
       | head -n 40 | tee "$OUT/strings_interesting.txt"
  echo "(strings ทั้งหมด $(wc -l < "$OUT/strings_all.txt") บรรทัด)"
fi

# ---------- 4) symbol และส่วนของไฟล์ ----------
step "4) symbol / section (readelf)"
if need readelf binutils; then
  readelf -h "$FILE" > "$OUT/readelf_header.txt" 2>&1
  readelf -S "$FILE" > "$OUT/readelf_sections.txt" 2>&1
  readelf -s "$FILE" > "$OUT/readelf_symbols.txt" 2>&1
  head -n 20 "$OUT/readelf_header.txt"
  echo
  echo "--- ฟังก์ชันที่น่าสนใจ (ชื่อมีคำว่า flag/win/main) ---"
  grep -a -E 'flag|win|main|secret|check' "$OUT/readelf_symbols.txt" | head -n 20
fi

# ---------- 5) ชุดคำสั่ง assembly ----------
step "5) assembly ช่วงแรก (objdump -d 80 บรรทัด)"
if need objdump binutils; then
  objdump -d -M intel "$FILE" 2>/dev/null | head -n 80 | tee "$OUT/objdump_head.txt"
  objdump -d -M intel "$FILE" > "$OUT/objdump_full.txt" 2>/dev/null
  echo "(ทั้งหมด -> $OUT/objdump_full.txt)"
fi

# ---------- 6) ข้อมูลเพิ่มเติมถ้ามี radare2 ----------
step "6) ข้อมูลเพิ่มจาก radare2 (ถ้าติดตั้งไว้)"
if need r2 radare2; then
  r2 -q -c "iI; iS; afl" "$FILE" > "$OUT/radare2_info.txt" 2>&1
  head -n 30 "$OUT/radare2_info.txt"
fi

# ---------- 7) hash ไว้เทียบ ----------
step "7) hash ของไฟล์"
{ md5sum "$FILE"; sha256sum "$FILE"; } 2>/dev/null | tee "$OUT/hashes.txt"

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- ชนิดไฟล์ : $(head -n 1 "$OUT/file.txt" 2>/dev/null)"
if [ -f "$OUT/checksec.txt" ]; then
  echo "- การป้องกัน:"
  grep -a -E 'RELRO|Canary|NX|PIE|RPATH|RUNPATH' "$OUT/checksec.txt" | sed 's/^/    /'
fi
echo "- คำที่น่าสนใจ: ดู $OUT/strings_interesting.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
echo "- ขั้นต่อไป: รันโปรแกรมดู -> bash ../reverse/dynamic_trace.sh"
