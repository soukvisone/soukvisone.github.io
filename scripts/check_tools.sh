#!/usr/bin/env bash
# ==========================================================================
#  check_tools.sh — ตรวจว่าเครื่องมีเครื่องมือครบไหม (อ่านจาก requirements.txt)
#
#  วิธีใช้:
#     bash scripts/check_tools.sh            # ตรวจเฉพาะ core
#     bash scripts/check_tools.sh --all      # ตรวจทั้งหมดรวมของ extra
#
#  ผลลัพธ์: [มี] / [ขาด] ทีละตัว + สรุปท้าย
#  ถ้าขาด: ติดตั้งด้วย  bash install.sh        (หรือ --all)
# ==========================================================================

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REQ="$HERE/../requirements.txt"
MODE="core"
[ "${1:-}" = "--all" ] && MODE="all"

[ -f "$REQ" ] || { echo "[!] ไม่พบ $REQ"; exit 1; }

have() {  # have <mgr> <check>
  case "$1" in
    pip) python3 -c "import importlib,sys; importlib.import_module(sys.argv[1])" "$2" >/dev/null 2>&1 ;;
    *)   command -v "$2" >/dev/null 2>&1 ;;
  esac
}

printf '\033[1;36m========== ตรวจเครื่องมือ (%s) ==========\033[0m\n' "$MODE"

N_OK=0
N_MISS=0
MISS_LIST=""

while read -r mgr pkg check tier _rest; do
  case "$mgr" in
    "")
      continue ;;
    \#*)
      # แสดงหัวข้อเฉพาะบรรทัดคั่นแบบ "# ---------- ... ----------"
      if printf '%s %s %s' "$mgr" "$pkg" "$check" | grep -q -- '----------'; then
        label=$(printf '%s %s %s %s' "$mgr" "$pkg" "$check" "$tier" | sed 's/^#*[[:space:]-]*//; s/[[:space:]-]*$//')
        [ -n "$label" ] && printf '\n\033[1;34m── %s\033[0m\n' "$label"
      fi
      continue ;;
  esac

  [ "$tier" = "extra" ] && [ "$MODE" != "all" ] && continue

  if have "$mgr" "$check"; then
    printf '  \033[1;32m[มี]\033[0m %-18s %s\n' "$check" "$(command -v "$check" 2>/dev/null || echo "(python module)")"
    N_OK=$((N_OK + 1))
  else
    printf '  \033[1;31m[ขาด]\033[0m %-18s แพ็กเกจ: %-24s (%s)\n' "$check" "$pkg" "$mgr"
    N_MISS=$((N_MISS + 1))
    MISS_LIST="$MISS_LIST $pkg"
  fi
done < "$REQ"

printf '\n\033[1;36m========== สรุป ==========\033[0m\n'
printf 'มีแล้ว %d รายการ · ขาด %d รายการ\n' "$N_OK" "$N_MISS"

if [ "$N_MISS" -eq 0 ]; then
  printf '\033[1;32m[+] ครบแล้ว — เริ่มใช้สคริปต์ได้เลย\033[0m\n'
  exit 0
fi

printf '\033[1;33m[!] ที่ขาด:%s\033[0m\n' "$MISS_LIST"
echo
echo "ติดตั้งอัตโนมัติ:   bash install.sh$( [ "$MODE" = "all" ] && echo " --all" )"
echo "ดูคำสั่งก่อน:      bash install.sh --dry-run"
echo "หมายเหตุของรายการที่ติดตั้งอัตโนมัติไม่ได้: ท้าย requirements.txt"
exit 1
