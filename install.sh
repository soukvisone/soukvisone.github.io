#!/usr/bin/env bash
# ==========================================================================
#  install.sh — ติดตั้งเครื่องมือตาม requirements.txt (ข้ามของที่มีอยู่แล้ว)
#
#  วิธีใช้:
#     bash install.sh                 # เฉพาะ core (แนะนำ)
#     bash install.sh --all           # ทุกอย่าง (ใหญ่มาก)
#     bash install.sh --dry-run       # ดูคำสั่งที่จะรัน
#     bash install.sh --all --dry-run
#
#  ต้องมี: sudo (apt/gem) และ python3 (pip)
#  ปลอดภัย: ไม่ลบอะไร ไม่แก้ไฟล์ระบบ นอกจากติดตั้งแพ็กเกจ
# ==========================================================================

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REQ="$HERE/requirements.txt"

MODE="core"
DRY="no"
for arg in "$@"; do
  case "$arg" in
    --all)     MODE="all" ;;
    --core)    MODE="core" ;;
    --dry-run) DRY="yes" ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "[!] ไม่รู้จักตัวเลือก: $arg (ใช้ --all / --dry-run / --help)"; exit 2 ;;
  esac
done

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[มีแล้ว]\033[0m %s\n' "$*"; }
new()  { printf '\033[1;33m[ติดตั้ง]\033[0m %s\n' "$*"; }
skip() { printf '\033[1;90m[ข้าม]\033[0m %s\n' "$*"; }

[ -f "$REQ" ] || { echo "[!] ไม่พบ requirements.txt ที่ $REQ"; exit 1; }

# เช็กว่ามี tool นี้แล้วหรือยัง
have() {  # have <mgr> <check>
  case "$1" in
    pip) python3 -c "import importlib,sys; importlib.import_module(sys.argv[1])" "$2" >/dev/null 2>&1 ;;
    *)   command -v "$2" >/dev/null 2>&1 ;;
  esac
}

line "โหมด: $MODE   (dry-run: $DRY)"
echo "อ่านรายการจาก: $REQ"

APT_LIST=""
PIP_LIST=""
GEM_LIST=""
SKIP_LIST=""
N_HAVE=0

while read -r mgr pkg check tier _rest; do
  case "$mgr" in ""|\#*) continue ;; esac
  [ "$tier" = "extra" ] && [ "$MODE" != "all" ] && continue

  if [ "$mgr" = "skip" ]; then
    if have skip "$check"; then ok "$check"; else SKIP_LIST="$SKIP_LIST $check"; fi
    continue
  fi

  if have "$mgr" "$check"; then
    ok "$check"
    N_HAVE=$((N_HAVE + 1))
    continue
  fi

  new "$pkg  (ตรวจด้วย: $check)"
  case "$mgr" in
    apt) APT_LIST="$APT_LIST $pkg" ;;
    pip) PIP_LIST="$PIP_LIST $pkg" ;;
    gem) GEM_LIST="$GEM_LIST $pkg" ;;
  esac
done < "$REQ"

line "สรุปแผน"
echo "มีอยู่แล้ว   : $N_HAVE รายการ"
[ -n "$APT_LIST" ]  && echo "apt ที่ต้องลง  :$APT_LIST"
[ -n "$PIP_LIST" ]  && echo "pip ที่ต้องลง  :$PIP_LIST"
[ -n "$GEM_LIST" ]  && echo "gem ที่ต้องลง  :$GEM_LIST"
[ -n "$SKIP_LIST" ] && echo "ติดตั้งอัตโนมัติไม่ได้:$SKIP_LIST  (ดูวิธีที่ท้าย requirements.txt)"

if [ -z "$APT_LIST$PIP_LIST$GEM_LIST" ]; then
  echo
  printf '\033[1;32m[+] ครบแล้ว ไม่ต้องติดตั้งอะไรเพิ่ม\033[0m\n'
  exit 0
fi

if [ "$DRY" = "yes" ]; then
  echo
  echo "--- คำสั่งที่จะรัน (dry-run ไม่ได้ทำจริง) ---"
  [ -n "$APT_LIST" ] && echo "sudo apt-get update && sudo apt-get install -y$APT_LIST"
  [ -n "$PIP_LIST" ] && echo "python3 -m pip install --break-system-packages$PIP_LIST"
  [ -n "$GEM_LIST" ] && echo "sudo gem install$GEM_LIST"
  exit 0
fi

# ---------- ติดตั้งจริง ----------
if [ -n "$APT_LIST" ]; then
  line "apt-get"
  # shellcheck disable=SC2086
  sudo apt-get update -qq && sudo apt-get install -y $APT_LIST || {
    echo "[!] apt ติดตั้งไม่ครบ — ลองรันใหม่ทีละแพ็กเกจเพื่อดู error"
  }
fi

if [ -n "$PIP_LIST" ]; then
  line "pip"
  # shellcheck disable=SC2086
  python3 -m pip install --break-system-packages $PIP_LIST || {
    echo "[!] pip ติดตั้งไม่ครบ — ถ้าเป็น Kali รุ่นเก่าให้ตัด --break-system-packages ออก"
  }
fi

if [ -n "$GEM_LIST" ]; then
  line "gem"
  # shellcheck disable=SC2086
  sudo gem install $GEM_LIST || echo "[!] gem ติดตั้งไม่ครบ"
fi

line "ให้สิทธิ์รันสคริปต์"
chmod +x "$HERE/install.sh" 2>/dev/null || true
find "$HERE/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
ok "chmod +x install.sh scripts/*.sh"

line "สร้างเว็บใหม่ (docs/)"
if python3 -c "import markdown" >/dev/null 2>&1; then
  if ( cd "$HERE/docs" && python3 build.py >/dev/null 2>&1 ); then
    ok "docs/*.html อัปเดตแล้ว"
  else
    echo "(build docs ไม่สำเร็จ — เปิด docs/index.html ที่มีอยู่ได้เลย)"
  fi
else
  echo "(ข้าม — ไม่มีโมดูล markdown: python3 -m pip install --break-system-packages markdown)"
fi

line "ตรวจซ้ำ"
bash "$HERE/scripts/check_tools.sh" || true

echo
echo "เสร็จแล้ว — ถ้ามี [ขาด] เหลืออยู่ ให้อ่านหมายเหตุท้าย requirements.txt"
echo "เริ่มใช้:  cd $HERE && python3 scripts/run_pipeline.py <target>"
