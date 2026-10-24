#!/usr/bin/env bash
# ==========================================================================
#  auto_triage.sh — คำสั่งเดียว: ตรวจไฟล์ → รันทุกอย่างที่เกี่ยวข้อง → หา flag
#  ใช้เมื่อ: ได้ไฟล์โจทย์มา 1 ไฟล์ ยังไม่รู้ว่าต้องทำอะไร
#
#  วิธีใช้:
#     bash auto_triage.sh challenge.bin
#     bash auto_triage.sh            # ใช้ค่าเริ่มต้นด้านล่าง
# ==========================================================================

FILE="${1:-challenge.bin}"           # <<< แก้บรรทัดนี้บรรทัดเดียว

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้าม) — ติดตั้ง: sudo apt install -y ${2:-$1}"
  return 1
}

TIER='[A-Za-z0-9_]{2,16}\{[^}]{2,300}\}'

line "เริ่มตรวจ: $FILE"
[ -f "$FILE" ] || { warn "ไม่พบไฟล์ '$FILE'"; exit 1; }
ls -lh "$FILE" | tee "$OUT/info.txt"

# ---------- 1) ชนิดไฟล์ ----------
step "1) ชนิดไฟล์ + hash"
if need file; then file "$FILE" | tee -a "$OUT/info.txt"; fi
md5sum "$FILE" 2>/dev/null | tee -a "$OUT/info.txt"
FT=$(file -b "$FILE" 2>/dev/null)
echo "ประเภท: $FT"

# ---------- 2) ข้อความในไฟล์ ----------
step "2) strings (ASCII + UTF-16)"
if need strings binutils; then
  strings -n 6 "$FILE"  > "$OUT/strings.txt"   2>&1
  strings -el "$FILE"   > "$OUT/strings_utf16.txt" 2>&1
  grep -a -i -E 'csg|flag|pass|secret|key|admin' "$OUT/strings.txt" "$OUT/strings_utf16.txt" \
    | head -40 | tee "$OUT/strings_interesting.txt"
fi

# ---------- 3) metadata ----------
step "3) metadata"
if need exiftool "libimage-exiftool-perl"; then
  exiftool -a -u -g1 "$FILE" > "$OUT/exiftool.txt" 2>&1
  grep -i -E 'comment|author|artist|description|software|password' "$OUT/exiftool.txt" | head -20
fi

# ---------- 4) ไฟล์ที่ซ่อนอยู่ ----------
step "4) binwalk (หาไฟล์ฝังอยู่)"
if need binwalk; then
  binwalk "$FILE" | tee "$OUT/binwalk.txt" | head -25
  if grep -q -E '^[0-9]+' "$OUT/binwalk.txt"; then
    mkdir -p "$OUT/extracted"
    binwalk --run-as=root -e -C "$OUT/extracted" "$FILE" > "$OUT/binwalk_extract.txt" 2>&1 \
      || binwalk -e -C "$OUT/extracted" "$FILE" >> "$OUT/binwalk_extract.txt" 2>&1
    find "$OUT/extracted" -type f 2>/dev/null | head -20 | sed 's/^/    /'
  fi
fi

# ---------- 5) ถ้าเป็นไฟล์บีบอัด ----------
case "$FT" in
  *Zip*)
    step "5) ไฟล์ ZIP — ดูรายชื่อ + ลองรหัสว่าง"
    unzip -l "$FILE" | head -30
    unzip -o -q -P "" "$FILE" -d "$OUT/unzip" 2>/dev/null && ok "แตกได้โดยไม่ต้องใช้รหัส"
    ;;
  *gzip*)
    step "5) gzip"
    gunzip -c "$FILE" > "$OUT/decompressed.bin" 2>/dev/null && file "$OUT/decompressed.bin"
    ;;
esac

# ---------- 6) ตามชนิดไฟล์ ----------
case "$FT" in
  *PNG*|*bitmap*)
    step "6) รูปภาพ — zsteg"
    need zsteg "ไม่ใช่ apt: sudo gem install zsteg" && zsteg -a "$FILE" > "$OUT/zsteg.txt" 2>&1
    head -20 "$OUT/zsteg.txt" 2>/dev/null
    ;;
  *JPEG*)
    step "6) JPEG — steghide (รหัสว่าง)"
    if need steghide; then
      steghide info "$FILE" -p "" > "$OUT/steghide.txt" 2>&1
      FILE_ABS=$(readlink -f "$FILE" 2>/dev/null || printf '%s' "$FILE")
      ( cd "$OUT" && steghide extract -sf "$FILE_ABS" -p "" -f ) >> "$OUT/steghide.txt" 2>&1
      cat "$OUT/steghide.txt" | head -12
    fi
    ;;
  *WAVE*|*audio*)
    step "6) เสียง — spectrogram + DTMF"
    if need sox; then
      sox "$FILE" -n spectrogram -o "$OUT/spectrogram.png" -x 2000 -y 1025 2>/dev/null
      ok "เปิดดู: $OUT/spectrogram.png"
    fi
    need multimon-ng && multimon-ng -t wav -a DTMF "$FILE" > "$OUT/dtmf.txt" 2>&1 && head -10 "$OUT/dtmf.txt"
    ;;
  *ELF*|*PE32*)
    step "6) ไบนารี — checksec / readelf / UPX"
    need checksec && checksec --file="$FILE" | tee "$OUT/checksec.txt"
    need readelf && readelf -h "$FILE" | head -15
    need upx && upx -l "$FILE" 2>&1 | head -5
    ;;
  *PDF*)
    step "6) PDF — metadata + ข้อความ"
    need pdftotext && pdftotext "$FILE" - 2>/dev/null | head -40
    need pdfid && pdfid "$FILE" | head -20
    ;;
  *"Composite Document"*|*Microsoft*)
    step "6) Office — macro"
    need olevba "python3-oletools" && olevba "$FILE" > "$OUT/olevba.txt" 2>&1 && head -25 "$OUT/olevba.txt"
    ;;
  *Python*|*"byte-compiled"*)
    step "6) .pyc — decompile"
    need pycdc && pycdc "$FILE" > "$OUT/decompiled.py" 2>&1 && head -40 "$OUT/decompiled.py"
    ;;
esac

# ---------- 7) สแกน flag ----------
line "7) ค้นหา flag"
{
  grep -a -o -E "$TIER" "$FILE" 2>/dev/null
  grep -a -h -o -E "$TIER" "$OUT"/*.txt 2>/dev/null
  find "$OUT/extracted" "$OUT/unzip" -type f -exec grep -a -o -E "$TIER" {} + 2>/dev/null
} | sort -u > "$OUT/_flags_all.txt"

if [ -s "$OUT/_flags_all.txt" ]; then
  ok "พบ:"
  cat "$OUT/_flags_all.txt" | sed 's/^/    /'
  grep -E '^CSG_FLAG\{' "$OUT/_flags_all.txt" > "$OUT/_FLAGS.txt" 2>/dev/null || true
else
  warn "ยังไม่พบ — ขั้นต่อไป:"
  echo "    bash flag_hunt.sh $FILE"
  echo "    python3 crypto_pipeline.py '<ข้อความที่สงสัย>'"
fi

line "สรุป"
echo "- ผลลัพธ์ทั้งหมด: $OUT/"
ls -1 "$OUT" | sed 's/^/    /'
