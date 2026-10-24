#!/usr/bin/env bash
# ==========================================================================
#  pcap_summary.sh  —  สรุปไฟล์ดักจับเครือข่าย (.pcap / .pcapng)
#  ทำอะไร: ดูว่ามี protocol อะไร, ใครคุยกับใคร, ดึงไฟล์ที่โหลดผ่าน HTTP,
#           ดู DNS ที่ถูกถาม, และหาชื่อผู้ใช้/รหัสผ่านที่ส่งแบบไม่เข้ารหัส
#
#  วิธีใช้: แก้บรรทัด FILE แล้วรัน   bash pcap_summary.sh
# ==========================================================================

FILE="${1:-capture.pcap}"          # <<< แก้บรรทัดนี้บรรทัดเดียว

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT/http_objects"

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลองเปิดไฟล์ใน http_objects/ หรือใช้ tshark -z follow,tcp,ascii,0"
  fi
}

line "เริ่มอ่านไฟล์แพ็กเก็ต: $FILE"
if [ ! -f "$FILE" ]; then
  warn "ไม่พบไฟล์ '$FILE' — ตรวจชื่อไฟล์อีกครั้ง"
  exit 1
fi
if ! need tshark; then
  warn "สคริปต์นี้ต้องใช้ tshark เป็นหลัก — ติดตั้งก่อนแล้วรันใหม่"
  exit 1
fi
tshark -v | head -n 1 | tee "$OUT/tshark_version.txt"

# ---------- 1) ภาพรวม protocol ----------
step "1) Protocol ทั้งหมดในไฟล์"
tshark -r "$FILE" -q -z io,phs > "$OUT/protocols.txt" 2>&1
head -n 40 "$OUT/protocols.txt"

# ---------- 2) ใครคุยกับใคร (conversations) ----------
step "2) การสนทนา (IP / TCP / UDP)"
{ echo "### IP";  tshark -r "$FILE" -q -z conv,ip
  echo "### TCP"; tshark -r "$FILE" -q -z conv,tcp
  echo "### UDP"; tshark -r "$FILE" -q -z conv,udp
} > "$OUT/conversations.txt" 2>&1
head -n 25 "$OUT/conversations.txt"

# ---------- 3) HTTP: คำขอ + ไฟล์ที่โหลด ----------
step "3) HTTP request ทั้งหมด"
tshark -r "$FILE" -Y http.request -T fields \
       -e frame.number -e ip.src -e ip.dst \
       -e http.request.method -e http.host -e http.request.uri \
       > "$OUT/http_requests.txt" 2>&1
head -n 25 "$OUT/http_requests.txt"

step "4) ดึงไฟล์ที่ส่งผ่าน HTTP ออกมา"
FILE_ABS=$(readlink -f "$FILE" 2>/dev/null || printf '%s' "$FILE")
( cd "$OUT/http_objects" && tshark -r "$FILE_ABS" --export-objects http,. -q ) \
       > "$OUT/http_export.txt" 2>&1
ls -1 "$OUT/http_objects" | head -n 30 | sed 's/^/    /'
echo "(ไฟล์ที่ดึงได้อยู่ใน $OUT/http_objects/)"

# ---------- 5) DNS: โดเมนที่ถูกถาม ----------
step "5) DNS queries"
tshark -r "$FILE" -Y dns.flags.response==0 -T fields -e dns.qry.name \
       > "$OUT/dns_queries.txt" 2>&1
sort -u "$OUT/dns_queries.txt" | head -n 40

# ---------- 6) รหัสผ่าน/โทเคนที่ส่งแบบไม่เข้ารหัส ----------
step "6) ข้อมูลรับรองที่ไม่เข้ารหัส (HTTP Basic / FTP / Telnet / POP / IMAP)"
tshark -r "$FILE" \
  -Y 'http.authorization || ftp || telnet || pop || imap || smtp' \
  -T fields -e frame.number -e ip.src -e ip.dst \
             -e http.authorization -e ftp.request.command -e ftp.request.arg \
             -e telnet.data -e pop.request.parameter -e imap.request \
             -e smtp.req.parameter \
  > "$OUT/credentials.txt" 2>&1
head -n 30 "$OUT/credentials.txt"

# ---------- 7) ค้นคำที่มักเป็นแฟล็ก ----------
step "7) ค้นคำว่า flag / CSG ในทุกแพ็กเก็ต"
tshark -r "$FILE" -Y 'frame contains "CSG_FLAG"' -T fields -e frame.number -e data \
       > "$OUT/frames_with_flag.txt" 2>&1
if [ -s "$OUT/frames_with_flag.txt" ]; then
  ok "เจอแพ็กเก็ตที่มีคำว่า CSG_FLAG"
  head -n 10 "$OUT/frames_with_flag.txt"
else
  echo "(ไม่พบแพ็กเก็ตที่พิมพ์แฟล็กตรง ๆ)"
fi

# ---------- 8) ข้อมูลแบบ ascii ของ stream แรก ๆ (อ่านง่าย) ----------
step "8) เนื้อหา TCP stream 5 อันแรก (แบบ ascii)"
tshark -r "$FILE" -q -z conv,tcp 2>/dev/null | awk 'NR>5 && $1 ~ /^[0-9]/ {print $1}' \
  | head -n 5 > "$OUT/_streams.txt"
while read -r st; do
  [ -z "$st" ] && continue
  echo "----- stream $st -----" >> "$OUT/streams_ascii.txt"
  tshark -r "$FILE" -q -z "follow,tcp,ascii,$st" >> "$OUT/streams_ascii.txt" 2>&1
done < "$OUT/_streams.txt"
echo "(ดูได้ที่ $OUT/streams_ascii.txt)"

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- protocol   : ดู $OUT/protocols.txt"
echo "- ใครคุยกับใคร: $OUT/conversations.txt"
echo "- HTTP request: $OUT/http_requests.txt  | ไฟล์ที่โหลด: $OUT/http_objects/"
echo "- DNS        : $OUT/dns_queries.txt"
echo "- รหัสผ่าน   : $OUT/credentials.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
