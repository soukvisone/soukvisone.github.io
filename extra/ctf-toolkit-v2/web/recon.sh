#!/usr/bin/env bash
# ==========================================================================
#  recon.sh  —  สำรวจเว็บเป้าหมายเบื้องต้น (ไม่บุกรุก แค่ขอหน้าเว็บปกติ)
#  ทำอะไร: ดู header, robots.txt, sitemap, ไฟล์ที่ไม่ควรเปิดเผย,
#           เทคโนโลยีที่ใช้, คุกกี้, และคอมเมนต์ในโค้ดหน้าเว็บ
#
#  วิธีใช้: แก้บรรทัด URL แล้วรัน   bash recon.sh
#  หมายเหตุ: ส่งคำขอไปที่เป้าหมายของโจทย์เท่านั้น ไม่ส่งข้อมูลออกที่อื่น
# ==========================================================================

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
    warn "ยังไม่เจอ CSG_FLAG{ — ลอง dir_bruteforce.sh หาไฟล์/โฟลเดอร์ที่ซ่อนอยู่"
  fi
}

line "เริ่มสำรวจเว็บ: $URL"
need curl || { warn "ต้องมี curl ก่อน — sudo apt install -y curl"; exit 1; }
URL="${URL%/}"     # ตัด / ตัวท้ายออก เพื่อต่อ path ได้สวย ๆ

# ตัวช่วย: ดึงหน้าเว็บหนึ่งหน้าเก็บลงไฟล์
fetch() {   # fetch <path> <ชื่อไฟล์>
  local path="$1" name="$2"
  curl -s -k -L --max-time 15 -A "Mozilla/5.0 (CTF-recon)" \
       -o "$OUT/$name" -w '%{http_code} %{size_download}\n' "$URL$path" 2>/dev/null
}

# ---------- 1) header ของหน้าแรก ----------
step "1) HTTP header ของหน้าแรก"
curl -s -k -I -L --max-time 15 "$URL" | tee "$OUT/headers.txt"
echo
echo "คำใบ้จาก header: Server / X-Powered-By บอกเทคโนโลยีที่ใช้"

# ---------- 2) เก็บหน้าแรกไว้ดู ----------
step "2) ดึงหน้าแรกเก็บไว้"
CODE=$(fetch "/" "index.html")
echo "HTTP status + ขนาด: $CODE"
ok "บันทึกที่ $OUT/index.html"

# ---------- 3) robots.txt และ sitemap ----------
step "3) robots.txt / sitemap.xml (บางทีบอกที่ซ่อนแฟล็ก)"
for f in robots.txt sitemap.xml; do
  RES=$(fetch "/$f" "$f")
  printf '  /%-12s -> %s\n' "$f" "$RES"
done
if [ -s "$OUT/robots.txt" ]; then
  echo "--- เนื้อ robots.txt ---"
  head -n 30 "$OUT/robots.txt"
fi

# ---------- 4) ไฟล์/โฟลเดอร์ที่มักลืมปิด ----------
step "4) ไฟล์ที่มักเปิดเผยโดยไม่ตั้งใจ"
PATHS="/.git/HEAD /.env /backup.zip /www.zip /flag /flag.txt /admin/ /server-status /.htaccess /phpinfo.php /debug /console /api/"
for p in $PATHS; do
  RES=$(fetch "$p" "path_$(echo "$p" | tr '/.' '__').txt")
  printf '  %-18s -> %s\n' "$p" "$RES" | tee -a "$OUT/paths.txt"
done

# ---------- 5) เทคโนโลยีที่ใช้ ----------
step "5) เทคโนโลยีของเว็บ (whatweb ถ้ามี)"
if need whatweb; then
  whatweb -q "$URL" 2>&1 | tee "$OUT/whatweb.txt"
else
  echo "(ข้าม — ติดตั้งด้วย sudo apt install -y whatweb)"
fi

# ---------- 6) คุกกี้ ----------
step "6) คุกกี้ที่เซิร์ฟเวอร์ส่งมา"
curl -s -k -I -L --max-time 15 "$URL" | grep -i '^set-cookie' | tee "$OUT/cookies.txt"
if [ -s "$OUT/cookies.txt" ]; then
  echo "-> ถ้าค่าในคุกกี้ยาวและมีจุด 2 จุด ให้ลองถอดด้วย cookie_jwt_decode.py"
fi

# ---------- 7) คอมเมนต์และลิงก์ในหน้าเว็บ ----------
step "7) คอมเมนต์และลิงก์ในหน้าแรก (ที่ซ่อนแฟล็กได้)"
if [ -s "$OUT/index.html" ]; then
  grep -o '<!--.*-->' "$OUT/index.html" 2>/dev/null | head -n 20 | tee "$OUT/comments.txt"
  grep -o -E 'href="[^"]+"|src="[^"]+"' "$OUT/index.html" 2>/dev/null | sort -u | head -n 30 | tee "$OUT/links.txt"
fi

# ---------- 8) header ที่บอกช่องโหว่ที่พบบ่อย ----------
step "8) ตรวจ header ความปลอดภัย (ช่องโหว่ที่พบบ่อย)"
grep -i -E 'server:|x-powered-by|access-control-allow-origin|x-frame-options|content-security-policy' \
     "$OUT/headers.txt" | tee "$OUT/security_headers.txt"

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- หน้าแรก     : $OUT/index.html"
echo "- header      : $OUT/headers.txt"
echo "- robots      : $OUT/robots.txt"
echo "- path ที่ลอง : $OUT/paths.txt"
echo "- คุกกี้       : $OUT/cookies.txt"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
echo
echo "ขั้นต่อไป: bash ../web/dir_bruteforce.sh   (หาหน้าที่ซ่อนอยู่)"
