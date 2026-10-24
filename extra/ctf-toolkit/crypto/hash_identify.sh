#!/usr/bin/env bash
# ==========================================================================
#  hash_identify.sh  —  บอกว่า hash ที่ได้มาเป็นชนิดไหน แล้วแนะนำคำสั่ง crack
#  ทำอะไร: ทายชนิด hash, ตรวจว่ามี john/hashcat ไหม, แล้วพิมพ์คำสั่งที่ใช้ได้เลย
#           (สคริปต์จะไม่ crack ให้อัตโนมัติ เพราะใช้เวลานาน)
#
#  วิธีใช้: แก้บรรทัด HASH แล้วรัน   bash hash_identify.sh
# ==========================================================================

HASH="5f4dcc3b5aa765d61d8327deb882cf99"          # <<< แก้บรรทัดนี้บรรทัดเดียว

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
    warn "ยังไม่เจอ CSG_FLAG{ — แฟล็กมักเป็นรหัสผ่านที่ crack ได้ ให้รันคำสั่งที่แนะนำด้านล่าง"
  fi
}

line "ตรวจชนิด hash"
printf '%s\n' "$HASH" | tee "$OUT/hash.txt"
echo "ความยาว: ${#HASH} ตัวอักษร"

# ---------- 1) หา wordlist ----------
step "1) หา wordlist ในเครื่อง"
ROCKYOU=""
for w in /usr/share/wordlists/rockyou.txt /usr/share/wordlists/rockyou.txt.gz; do
  if [ -f "$w" ]; then ROCKYOU="$w"; break; fi
done
if [ -z "$ROCKYOU" ]; then
  warn "ไม่พบ rockyou.txt — ติดตั้งด้วย:  sudo apt install -y wordlists"
  warn "แล้วรัน:  sudo gunzip /usr/share/wordlists/rockyou.txt.gz"
  ROCKYOU="/usr/share/wordlists/rockyou.txt"     # ใส่ไว้ในคำสั่งให้ดูก่อน
else
  ok "พบ wordlist: $ROCKYOU"
fi

# ---------- 2) ใช้ hashid ถ้ามี ----------
step "2) ทายชนิดด้วย hashid"
if need hashid; then
  # -m = แสดง hashcat mode, -j = แสดง john format
  hashid -m -j "$HASH" 2>&1 | tee "$OUT/hashid.txt"
  echo
  echo "-> ค่า mode (hashcat) และ format (john) อยู่ในผลข้างบน"
else
  warn "ติดตั้ง hashid ได้ด้วย:  python3 -m pip install --break-system-packages hashid"
fi

# ---------- 3) ทายเองจากความยาว/รูปแบบ ----------
step "3) ทายจากรูปแบบ (ใช้ได้แม้ไม่มี hashid)"
LEN=${#HASH}
type=""
hc_mode=""
john_fmt=""
case "$LEN" in
  32)  type="MD5 (หรือ NTLM)";              hc_mode="0 (MD5) / 1000 (NTLM)"; john_fmt="raw-md5 / nt" ;;
  40)  type="SHA1";                          hc_mode="100";                   john_fmt="raw-sha1" ;;
  56)  type="SHA224";                        hc_mode="1300";                  john_fmt="raw-sha224" ;;
  64)  type="SHA256 (หรือ SHA3-256)";        hc_mode="1400";                  john_fmt="raw-sha256" ;;
  96)  type="SHA384";                        hc_mode="10800";                 john_fmt="raw-sha384" ;;
  128) type="SHA512 (หรือ Whirlpool)";       hc_mode="1700";                  john_fmt="raw-sha512" ;;
  *)
      # ตรวจรูปแบบพิเศษ
      if [[ "$HASH" == \$2* ]]; then
        type="bcrypt"; hc_mode="3200"; john_fmt="bcrypt"
      elif [[ "$HASH" == \$1\$* ]]; then
        type="MD5-crypt"; hc_mode="500"; john_fmt="md5crypt"
      elif [[ "$HASH" == \$6\$* ]]; then
        type="SHA512-crypt"; hc_mode="1800"; john_fmt="sha512crypt"
      elif [[ "$HASH" == \$5\$* ]]; then
        type="SHA256-crypt"; hc_mode="7400"; john_fmt="sha256crypt"
      elif [[ "$HASH" == \$argon2* ]]; then
        type="Argon2"; hc_mode="ไม่รองรับตรง ๆ"; john_fmt="argon2"
      elif [[ "$HASH" == *:* ]]; then
        type="อาจเป็น hash แบบมี salt (user:hash หรือ hash:salt)"; hc_mode="?"; john_fmt="?"
      else
        type="ไม่ทราบชนิด"; hc_mode="?"; john_fmt="?"
      fi
      ;;
esac

printf 'ชนิดที่น่าจะเป็น : %s\n' "$type" | tee "$OUT/guess.txt"
printf 'hashcat mode     : %s\n' "$hc_mode" | tee -a "$OUT/guess.txt"
printf 'john format      : %s\n' "$john_fmt" | tee -a "$OUT/guess.txt"

# ---------- 4) แนะนำคำสั่ง crack ----------
step "4) คำสั่ง crack ที่ใช้ได้เลย (คัดลอกไปรัน)"
echo "# เตรียมไฟล์ hash"
echo "echo '$HASH' > hash.txt"
echo
echo "# วิธีที่ 1: john (ช้ากว่าแต่ใช้ง่าย)"
if [ "$john_fmt" = "?" ]; then
  echo "john --wordlist=$ROCKYOU hash.txt        # ให้ john เดาชนิดเอง"
  echo "john --list=formats | grep -i <คำที่เดา>  # ดูชื่อ format ที่รองรับ"
else
  echo "john --format=$john_fmt --wordlist=$ROCKYOU hash.txt"
fi
echo "john --show hash.txt"
echo
echo "# วิธีที่ 2: hashcat (เร็วกว่าถ้ามี GPU)"
if [ "$hc_mode" = "?" ]; then
  echo "hashcat -m 0 -a 0 hash.txt $ROCKYOU      # -m ต้องใส่ให้ตรงชนิด"
  echo "hashcat --example-hashes | less          # ดูตัวอย่าง hash ของแต่ละ mode"
else
  echo "hashcat -m ${hc_mode%% *} -a 0 hash.txt $ROCKYOU"
fi
echo "hashcat -m ${hc_mode%% *} -a 0 hash.txt $ROCKYOU --show"
echo
echo "# ถ้า crack ไม่เจอ ลองกฎแปลงคำ (เพิ่มโอกาส)"
echo "hashcat -m ${hc_mode%% *} -a 0 hash.txt $ROCKYOU -r /usr/share/hashcat/rules/best64.rule"

# ---------- 5) บันทึกคำแนะนำ ----------
{
  echo "HASH: $HASH"
  echo "ชนิด: $type"
  echo "hashcat mode: $hc_mode"
  echo "john format: $john_fmt"
  echo "wordlist: $ROCKYOU"
} > "$OUT/summary.txt"

# ---------- 6) ลองเดาแบบเร็ว ๆ ในเครื่อง (ไม่ใช้ wordlist) ----------
step "5) ลองเดาแบบเร็ว ๆ: hash ของคำที่พบบ่อยในโจทย์ CTF"
if need md5sum coreutils; then
  for guess in password admin 123456 flag csg csg2026 letmein root toor; do
    H=$(printf '%s' "$guess" | md5sum | awk '{print $1}')
    if [ "$H" = "$HASH" ]; then
      ok "เจอแล้ว! '$guess' ให้ค่า MD5 ตรงกับ hash นี้"
      printf 'CSG_FLAG{%s}\n' "$guess" >> "$OUT/_possible_flag.txt"
    fi
    # SHA256 ด้วย
    H2=$(printf '%s' "$guess" | sha256sum | awk '{print $1}')
    if [ "$H2" = "$HASH" ]; then
      ok "เจอแล้ว! '$guess' ให้ค่า SHA256 ตรงกับ hash นี้"
      printf 'CSG_FLAG{%s}\n' "$guess" >> "$OUT/_possible_flag.txt"
    fi
  done
  echo "(ลองไป $(echo password admin 123456 flag csg csg2026 letmein root toor | wc -w) คำ)"
fi

# ---------- สรุป ----------
find_flags
line "สรุปสั้น ๆ"
echo "- hash      : $HASH"
echo "- ชนิด      : $type"
echo "- john      : $john_fmt"
echo "- hashcat   : $hc_mode"
echo "- wordlist  : $ROCKYOU"
echo "- ทั้งหมดอยู่ที่ : $OUT/"
