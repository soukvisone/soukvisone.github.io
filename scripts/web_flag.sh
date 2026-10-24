#!/usr/bin/env bash
# ==========================================================================
#  web_flag.sh — ไล่หา flag จากเว็บเป้าหมายแบบอัตโนมัติ
#  ทำอะไร: header → robots/sitemap → path ที่มักลืมปิด → cookie/JWT → grep flag
#
#  วิธีใช้:
#     bash web_flag.sh http://target:8080
#     bash web_flag.sh                  # ใช้ค่าเริ่มต้นด้านล่าง
#  หมายเหตุ: ยิงเฉพาะเป้าหมายที่โจทย์ให้มาเท่านั้น
# ==========================================================================

URL="${1:-http://target}"            # <<< แก้บรรทัดนี้บรรทัดเดียว
RUN_FFUF="no"                        # "yes" = เรียก ffuf ด้วย (ต้องมี wordlist)
FFUF_WORDLIST="/usr/share/seclists/Discovery/Web-Content/common.txt"

OUT="output_$(basename "$0" .sh)"
mkdir -p "$OUT/pages"

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
step() { printf '\n\033[1;34m--- %s ---\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "ไม่พบคำสั่ง '$1' (ข้าม) — ติดตั้ง: sudo apt install -y ${2:-$1}"
  return 1
}

URL="${URL%/}"
need curl || { warn "ต้องมี curl ก่อน"; exit 1; }

# เก็บทุก response ไว้ใน pages/ แล้วค่อย grep ทีหลัง
grab() {  # grab <path> <filename>
  local p="$1" n="$2"
  local code
  code=$(curl -s -k -L --max-time 12 -A "Mozilla/5.0 (notes)" \
              -o "$OUT/pages/$n" -w '%{http_code}' "$URL$p" 2>/dev/null)
  printf '  %-6s %-32s %s\n' "$code" "$p" "$(wc -c < "$OUT/pages/$n" 2>/dev/null) bytes"
  [ "$code" = "200" ] && printf '%s\n' "$URL$p" >> "$OUT/found_200.txt"
}

line "เป้าหมาย: $URL"
: > "$OUT/found_200.txt"

# ---------- 1) header ----------
step "1) HTTP header"
curl -s -k -i -L --max-time 15 "$URL/" > "$OUT/headers.txt" 2>&1
head -n 25 "$OUT/headers.txt"
grep -i -E 'server:|x-powered-by|set-cookie|location:' "$OUT/headers.txt" | head -10

# ---------- 2) ไฟล์มาตรฐาน ----------
step "2) robots / sitemap / security.txt / git"
for p in /robots.txt /sitemap.xml /.well-known/security.txt /.git/HEAD /.env /flag /flag.txt; do
  grab "$p" "$(echo "$p" | tr '/.' '__').out"
done

# ---------- 3) path ที่มักลืมปิด ----------
step "3) path ที่พบบ่อย (รายการในสคริปต์ ไม่ต้องใช้ wordlist)"
for p in /admin /admin/ /login /dashboard /api /api/v1 /debug /console /backup /backup.zip \
         /www.zip /uploads /upload /files /download /static /assets /test /dev /tmp \
         /phpinfo.php /info.php /server-status /actuator /actuator/env /swagger /swagger-ui \
         /api/users /api/flag /robots.txt.bak /index.php.bak /config.php /config.php.bak \
         /.DS_Store /.htaccess /.git/config; do
  grab "$p" "$(echo "$p" | tr '/.?=' '____').out"
done

# ---------- 4) cookie / JWT ----------
step "4) cookie และ JWT"
grep -i '^set-cookie' "$OUT/headers.txt" | tee "$OUT/cookies.txt"
if [ -s "$OUT/cookies.txt" ]; then
  TOKEN=$(grep -o -E 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*' "$OUT/cookies.txt" | head -1)
  if [ -n "$TOKEN" ]; then
    ok "พบ JWT — กำลังถอด"
    python3 - "$TOKEN" <<'PY' | tee "$OUT/jwt.txt"
import base64, json, sys
tok = sys.argv[1]
for name, part in zip(("HEADER", "PAYLOAD"), tok.split(".")[:2]):
    pad = "=" * (-len(part) % 4)
    try:
        print(name, json.dumps(json.loads(base64.urlsafe_b64decode(part + pad)), ensure_ascii=False, indent=2))
    except Exception as e:
        print(name, "(ถอดไม่ได้)", e)
PY
  else
    echo "(ไม่พบ JWT ในคุกกี้ — อาจเป็น session ปกติ)"
  fi
fi

# ---------- 5) ค้นคำสำคัญในทุกหน้าที่โหลดมา ----------
step "5) ค้น flag / คำสำคัญ ในทุก response"
grep -a -r -h -o -E '[A-Za-z0-9_]{2,16}\{[^}]{2,300}\}' "$OUT/pages" 2>/dev/null | sort -u > "$OUT/_candidates.txt"
grep -a -r -h -o -E 'CSG_FLAG\{[^}]*\}' "$OUT/pages" 2>/dev/null | sort -u > "$OUT/_FLAGS.txt"
if [ -s "$OUT/_FLAGS.txt" ]; then
  ok "พบ flag:"; cat "$OUT/_FLAGS.txt" | sed 's/^/    /'
else
  warn "ไม่พบ CSG_FLAG{...} ในหน้าที่โหลดมา"
fi
[ -s "$OUT/_candidates.txt" ] && { echo "รูปแบบอื่นที่น่าสนใจ:"; head -20 "$OUT/_candidates.txt" | sed 's/^/    /'; }

# ---------- 6) ffuf (ถ้าเปิดใช้) ----------
step "6) ffuf (เฉพาะเมื่อ RUN_FFUF=yes)"
if [ "$RUN_FFUF" = "yes" ]; then
  if need ffuf && [ -f "$FFUF_WORDLIST" ]; then
    ffuf -u "$URL/FUZZ" -w "$FFUF_WORDLIST" -mc 200,204,301,302,401,403 -t 40 \
         -o "$OUT/ffuf.json" -of json 2>&1 | tail -20
  else
    warn "ไม่มี ffuf หรือไม่พบ wordlist: $FFUF_WORDLIST"
  fi
else
  echo "(ปิดอยู่ — เปิดด้วยการแก้ RUN_FFUF=\"yes\")"
fi

# ---------- สรุป ----------
line "สรุป"
echo "- หน้า 200 OK : $(wc -l < "$OUT/found_200.txt" 2>/dev/null) รายการ -> $OUT/found_200.txt"
echo "- response ทั้งหมด: $OUT/pages/"
echo "- header      : $OUT/headers.txt"
echo "- flag        : $OUT/_FLAGS.txt"
echo
echo "ขั้นต่อไป: เปิดหน้าไหนน่าสนใจด้วย curl -i แล้วดู param / ฟอร์ม"
echo "          ถ้ามีช่องกรอก -> ../Web/common_payloads.md"
