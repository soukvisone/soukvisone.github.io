#!/usr/bin/env bash
# ==========================================================================
#  triage.sh  —  "ตัวคัดแยก" : ดูว่าไฟล์โจทย์เป็นอะไร แล้วเรียกสคริปต์ที่ใช่ให้
#
#  วิธีใช้:
#     1) แก้บรรทัด FILE ด้านล่างให้เป็นชื่อไฟล์โจทย์
#     2) รัน:   bash triage.sh
#     (หรือพิมพ์ชื่อไฟล์ต่อท้ายก็ได้:  bash triage.sh challenge.bin)
# ==========================================================================

FILE="${1:-challenge.bin}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

# ---------- ตั้งค่าพื้นฐาน ----------
BASE="$(cd "$(dirname "$0")" && pwd)"   # โฟลเดอร์ที่เก็บสคริปต์ชุดนี้
OUT="output_triage"                     # โฟลเดอร์เก็บผลลัพธ์ของสคริปต์นี้
mkdir -p "$OUT"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

# ---------- ขั้นที่ 1: ไฟล์นี้คืออะไร ----------
line "ขั้นที่ 1: ตรวจชนิดไฟล์"
if [ ! -e "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์/โฟลเดอร์อีกครั้ง แล้วรันใหม่"
  exit 1
fi

if command -v file >/dev/null 2>&1; then
  FT=$(file -b "$FILE")
  MIME=$(file -b --mime-type "$FILE")
else
  warn "ไม่พบคำสั่ง 'file' — ติดตั้งด้วย: sudo apt install -y file"
  FT="unknown"
  MIME="unknown"
fi

echo "ไฟล์ : $FILE"
echo "ชนิด : $FT"
echo "MIME : $MIME"
printf '%s\n%s\n' "$FT" "$MIME" > "$OUT/type.txt"

# ---------- ตัวช่วยเรียกสคริปต์ ----------
run() {   # run <พาธสคริปต์เทียบกับโฟลเดอร์นี้> <ไฟล์ที่จะส่งให้>
  local s="$BASE/$1"
  if [ ! -f "$s" ]; then
    warn "ไม่พบสคริปต์ $1 (ข้าม)"
    return
  fi
  line "เรียกใช้ $1"
  case "$1" in
    *.py) python3 "$s" "$2" ;;     # สคริปต์ Python
    *)    bash    "$s" "$2" ;;     # สคริปต์ Bash
  esac
}

# ---------- ขั้นที่ 2: เลือกชุดสคริปต์ตามชนิดไฟล์ ----------
line "ขั้นที่ 2: เลือกสคริปต์ที่ตรงกับไฟล์"
case "$FT" in
  *ELF*|*PE32*|*Mach-O*|*executable*)
      echo "-> ไฟล์โปรแกรม (binary) : ตรวจโครงสร้าง + หา hash/strings"
      run "reverse/bin_info.sh"      "$FILE"
      run "malware/static_info.sh"   "$FILE"
      ;;
  *pcap*|*tcpdump*|*"capture file"*)
      echo "-> ไฟล์ดักจับเครือข่าย : สรุป protocol / คุยกัน / HTTP / DNS"
      run "forensics/pcap_summary.sh" "$FILE"
      ;;
  *Zip*|*gzip*|*tar*|*7-zip*|*RAR*|*bzip2*|*XZ*|*compress*)
      echo "-> ไฟล์บีบอัด : แตกไฟล์ + ไล่หาแฟล็กข้างใน"
      run "misc/archive_crack.sh"          "$FILE"
      run "misc/find_flag_everywhere.sh"   "$FILE"
      ;;
  *PNG*|*JPEG*|*GIF*|*bitmap*|*WebP*|*TIFF*|*image*)
      echo "-> ไฟล์รูป : ตรวจ stego / metadata"
      run "forensics/stego_image.sh" "$FILE"
      ;;
  *WAVE*|*MPEG*|*FLAC*|*Ogg*|*audio*)
      echo "-> ไฟล์เสียง : ดู spectrogram / โรเตอร์ / DTMF"
      run "misc/audio_spectrogram.sh" "$FILE"
      ;;
  *PDF*)
      echo "-> ไฟล์ PDF : ตรวจ metadata และข้อความซ่อน"
      run "forensics/file_triage.sh" "$FILE"
      run "misc/find_flag_everywhere.sh" "$FILE"
      ;;
  *Composite\ Document*|*Microsoft*|*OOXML*|*Excel*|*Word*|*PowerPoint*)
      echo "-> เอกสาร Office : หา macro"
      run "malware/office_macro.sh"  "$FILE"
      run "forensics/file_triage.sh" "$FILE"
      ;;
  *SQLite*|*filesystem*|*disk\ image*|*DOS/MBR*|*partition*)
      echo "-> อิมเมจดิสก์ : ดูพาร์ทิชัน + ไฟล์ที่ถูกลบ"
      run "forensics/disk_image.sh" "$FILE"
      ;;
  *"Windows Event Log"*|*evtx*)
      echo "-> Windows Event Log : แปลงเป็นข้อความแล้วค้นหา"
      run "forensics/windows_logs.sh" "$FILE"
      ;;
  *Python*|*"byte-compiled"*)
      echo "-> ไฟล์ .pyc : แปลงกลับเป็นโค้ด"
      run "reverse/python_pyc_decompile.sh" "$FILE"
      ;;
  *text*|*JSON*|*XML*|*HTML*|*ASCII*|*Unicode*)
      echo "-> ไฟล์ข้อความ : ไล่หาแฟล็ก + ลองถอดรหัส"
      run "misc/find_flag_everywhere.sh" "$FILE"
      run "crypto/auto_decode.py"        "$FILE"
      ;;
  *)
      echo "-> ชนิดไม่ชัดเจน : สแกนกว้างแบบไม่เสียหาย"
      run "forensics/file_triage.sh"       "$FILE"
      run "misc/find_flag_everywhere.sh"   "$FILE"
      ;;
esac

# ---------- ขั้นที่ 3: สรุป ----------
line "ขั้นที่ 3: สรุป"
echo "- ผลลัพธ์ของแต่ละสคริปต์อยู่ในโฟลเดอร์ output_<ชื่อสคริปต์>/"
echo "- ชนิดไฟล์ที่ตรวจได้: $FT"
if [ -f "$OUT/type.txt" ]; then
  echo "- บันทึกชนิดไฟล์ไว้ที่: $OUT/type.txt"
fi
echo "- ถ้ายังไม่เจอแฟล็ก ให้เปิด README.md แล้วดูตาราง 'ไฟล์แบบนี้ -> ใช้สคริปต์ไหน'"
ok "จบการทำงานของ triage.sh"
