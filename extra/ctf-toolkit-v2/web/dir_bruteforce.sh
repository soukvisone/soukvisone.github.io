#!/usr/bin/env bash
# ==========================================================================
#  dir_bruteforce.sh  —  ไล่หาหน้าที่ซ่อนอยู่บนเว็บ (directory brute force)
#  ทำอะไร: ยิงคำขอไปที่ URL/<คำใน wordlist> แล้วเก็บหน้าที่ตอบกลับมาว่ามีจริง
#
#  วิธีใช้: แก้บรรทัด URL แล้วรัน   bash dir_bruteforce.sh
#  หมายเหตุ: wordlist สคริปต์จะเลือกให้อัตโนมัติจากชุดที่มีใน Kali
# =============================================================================

URL="${1:-http://target.ctf}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลองเปิดหน้าที่เจอด้วย curl แล้วอ่านซอร์ส"
  fi
}

line "เริ่มไล่หาโฟลเดอร์/ไฟล์บน: $URL"
URL="${URL%/}"

# ---------- 1) เลือก wordlist อัตโนมัติ ----------
step "1) เลือก wordlist"
WORDLIST=""
for w in \
  /usr/share/wordlists/dirb/common.txt \
  /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt \
  /usr/share/seclists/Discovery/Web-Content/common.txt \
  /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  /usr/share/wordlists/dirb/big.txt ; do
  if [ -f "$w" ]; then WORDLIST="$w"; break; fi
done

if [ -z "$WORDLIST" ]; then
  warn "ไม่พบ wordlist ในเครื่อง — ติดตั้งด้วย:  sudo apt install -y wordlists seclists"
  warn "แล้วรัน:  sudo gunzip /usr/share/wordlists/rockyou.txt.gz  (ถ้าต้องใช้)"
  exit 1
fi
ok "ใช้ wordlist: $WORDLIST ($(wc -l < "$WORDLIST") บรรทัด)"

# ---------- 2) เลือกเครื่องมือ: ffuf ก่อน ถ้าไม่มีใช้ gobuster ----------
step "2) เริ่มสแกน"
if command -v ffuf >/dev/null 2>&1; then
  ok "ใช้ ffuf"
  ffuf -u "$URL/FUZZ" \
       -w "$WORDLIST" \
       -mc 200,204,301,302,307,401,403 \
       -t 40 \
       -timeout 10 \
       -of json -o "$OUT/ffuf.json" \
       2>&1 | tee "$OUT/ffuf_log.txt" | tail -n 40

  # แปลงผลเป็นรายการอ่านง่าย
  if [ -f "$OUT/ffuf.json" ]; then
    python3 - "$OUT/ffuf.json" > "$OUT/found.txt" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for r in data.get("results", []):
    print(f"{r['status']:>4}  {r['length']:>8}  {r['url']}")
PY
  fi

elif command -v gobuster >/dev/null 2>&1; then
  ok "ใช้ gobuster"
  gobuster dir -u "$URL" -w "$WORDLIST" \
           -s 200,204,301,302,307,401,403 \
           -t 40 --no-error -q \
           -o "$OUT/gobuster.txt" 2>&1 | tee "$OUT/gobuster_log.txt" | tail -n 40
  cp "$OUT/gobuster.txt" "$OUT/found.txt" 2>/dev/null
else
  warn "ไม่พบ ffuf หรือ gobuster — ติดตั้งด้วย:  sudo apt install -y ffuf gobuster"
  exit 1
fi

# ---------- 3) แสดงผลที่เจอ ----------
step "3) หน้าที่เจอ"
if [ -s "$OUT/found.txt" ]; then
  cat "$OUT/found.txt"
  echo
  echo "-> หน้าที่น่าสนใจ (admin, backup, flag, upload, .git):"
  grep -i -E 'admin|backup|flag|upload|\.git|config|secret|test' "$OUT/found.txt" || true
else
  echo "(ไม่พบหน้าที่ตอบกลับตามที่กำหนด — ลอง wordlist ใหญ่ขึ้น หรือเปลี่ยน URL)"
fi

# ---------- 4) เปิดดูหน้าละเอียดของแต่ละอัน ----------
step "4) ดึงเนื้อหาของแต่ละหน้าที่เจอ (เฉพาะ 200)"
mkdir -p "$OUT/pages"
if [ -s "$OUT/found.txt" ]; then
  while read -r status len url; do
    [ "$status" = "200" ] || continue
    name=$(echo "$url" | sed 's|https\?://||; s|[/?&=]|_|g')
    curl -s -k -L --max-time 10 "$url" -o "$OUT/pages/$name.html" 2>/dev/null
  done < "$OUT/found.txt"
  ls -1 "$OUT/pages" 2>/dev/null | head -n 20
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- URL       : $URL"
echo "- wordlist  : $WORDLIST"
echo "- ผลที่เจอ  : $OUT/found.txt"
echo "- หน้าเว็บ   : $OUT/pages/"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
