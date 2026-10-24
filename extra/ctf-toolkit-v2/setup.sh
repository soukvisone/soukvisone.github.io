#!/usr/bin/env bash
# ==========================================================================
#  setup.sh  —  ตรวจว่า Kali เครื่องนี้มีเครื่องมือครบไหม
#  ถ้าขาดอะไร จะพิมพ์คำสั่ง apt / pip / gem ที่ต้องรันให้ท้ายสุด
#
#  วิธีใช้:  bash setup.sh
#  (สคริปต์นี้ไม่แก้อะไรในเครื่อง คุณต้องรันคำสั่งที่มันแนะนำเอง)
# ==========================================================================

CHECK_ONLY="yes"        # <<< ไม่ต้องแก้: "yes" = แค่ตรวจ, "no" = ติดตั้งให้เลย

APT_PKGS=""
PIP_PKGS=""
GEM_PKGS=""

line() { printf '\n\033[1;36m========== %s ==========\033[0m\n' "$*"; }

miss_apt() { APT_PKGS="$APT_PKGS $1"; }
miss_pip() { PIP_PKGS="$PIP_PKGS $1"; }
miss_gem() { GEM_PKGS="$GEM_PKGS $1"; }

# need <คำสั่ง> <แพ็กเกจ apt|-> <แพ็กเกจ pip|-> [แพ็กเกจ gem]
need() {
  local cmd="$1" aptpkg="$2" pippkg="$3" gempkg="$4"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '  \033[1;32m[มีแล้ว]\033[0m %-16s %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '  \033[1;31m[ขาด]\033[0m   %-16s apt:%-26s pip:%-14s gem:%s\n' \
           "$cmd" "${aptpkg:--}" "${pippkg:--}" "${gempkg:--}"
    [ -n "${aptpkg:-}" ] && [ "$aptpkg" != "-" ] && miss_apt "$aptpkg"
    [ -n "${pippkg:-}" ] && [ "$pippkg" != "-" ] && miss_pip "$pippkg"
    [ -n "${gempkg:-}" ] && [ "$gempkg" != "-" ] && miss_gem "$gempkg"
  fi
}

line "1) เครื่องมือพื้นฐาน"
need file          file              -
need strings       binutils          -
need xxd           xxd               -
need python3       python3           -
need pip3          python3-pip       -

line "2) Forensics / Stego / Disk"
need exiftool      libimage-exiftool-perl -
need binwalk       binwalk           -
need zsteg         -                 -             zsteg
need steghide      steghide          -
need tshark        tshark            -
need mmls          sleuthkit         -
need fls           sleuthkit         -
need icat          sleuthkit         -
need tsk_recover   sleuthkit         -
need evtx_dump.py  python3-evtx      evtx
need chainsaw      -                 -             -
need hayabusa     -                 -             -

line "3) Malware"
need olevba        python3-oletools  oletools
need oledump.py    python3-oletools  oletools
need yara          yara              -

line "4) Web"
need curl          curl              -
need ffuf          ffuf              -
need gobuster      gobuster          -
need nikto         nikto             -

line "5) Reverse"
need checksec      checksec          pwntools
need readelf       binutils          -
need objdump       binutils          -
need gdb           gdb               -
need ltrace        ltrace            -
need strace        strace            -
need r2            radare2           -
need uncompyle6    -                 uncompyle6
need pycdc         -                 -             -

line "6) Crypto / Crack"
need hashid        -                 hashid
need john          john              -
need hashcat       hashcat           -
need fcrackzip     fcrackzip         -
need 7z            7zip              -
need zbarimg       zbar-tools        -
need sox           sox               -
need multimon-ng   multimon-ng       -

line "7) ไลบรารี Python ที่สคริปต์บางตัวใช้"
for mod in pefile sympy gmpy2 Crypto volatility3; do
  if python3 - "$mod" <<'PY' >/dev/null 2>&1
import importlib, sys
name = sys.argv[1]
if name == "volatility3":
    import volatility3
else:
    importlib.import_module(name)
PY
  then
    printf '  \033[1;32m[มีแล้ว]\033[0m %s\n' "$mod"
  else
    printf '  \033[1;31m[ขาด]\033[0m   %s\n' "$mod"
    case "$mod" in
      pefile)     miss_pip pefile ;;
      sympy)      miss_pip sympy ;;
      gmpy2)      miss_pip gmpy2 ;;
      Crypto)     miss_pip pycryptodome ;;
      volatility3) miss_pip volatility3 ;;
    esac
  fi
done

line "สรุป: คำสั่งติดตั้งที่ยังขาด"
if [ -z "$APT_PKGS$PIP_PKGS$GEM_PKGS" ]; then
  printf '\033[1;32m[+] เครื่องนี้มีครบทุกอย่างแล้ว — เริ่มใช้สคริปต์ได้เลย\033[0m\n'
  exit 0
fi

echo "คัดลอกทีละบรรทัดไปรันใน terminal:"
echo
if [ -n "$APT_PKGS" ]; then
  echo "# แพ็กเกจระบบ (apt)"
  echo "sudo apt update"
  echo "sudo apt install -y$APT_PKGS"
  echo
fi
if [ -n "$PIP_PKGS" ]; then
  echo "# ไลบรารี Python (pip)"
  echo "python3 -m pip install --break-system-packages$PIP_PKGS"
  echo
fi
if [ -n "$GEM_PKGS" ]; then
  echo "# เครื่องมือ Ruby (gem)"
  echo "sudo gem install$GEM_PKGS"
  echo
fi

echo "หมายเหตุ: ถ้า pip ฟ้อง error ตอนติดตั้ง ให้ติดตั้งผ่าน apt แทน เช่น"
echo "  sudo apt install -y python3-pefile python3-sympy python3-gmpy2 python3-pycryptodome"
echo
echo "ติดตั้งเสร็จแล้วรัน 'bash setup.sh' อีกครั้งเพื่อตรวจว่าครบหรือยัง"

# ถ้าอยากให้สคริปต์ติดตั้งให้เลย ให้แก้บรรทัดบนสุดเป็น CHECK_ONLY="no"
if [ "$CHECK_ONLY" = "no" ]; then
  line "กำลังติดตั้งให้อัตโนมัติ (CHECK_ONLY=no)"
  [ -n "$APT_PKGS" ] && sudo apt install -y $APT_PKGS
  [ -n "$PIP_PKGS" ] && python3 -m pip install --break-system-packages $PIP_PKGS
  [ -n "$GEM_PKGS" ] && sudo gem install $GEM_PKGS
fi
