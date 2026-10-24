# Reverse — Common Commands (คัดลอกใช้ได้เลย)

> เปลี่ยน `challenge` เป็นชื่อไฟล์จริง

---

## 1) ข้อมูลไฟล์

```bash
file challenge
ls -l challenge
md5sum challenge sha256sum challenge
xxd -l 64 challenge
die challenge                 # Detect It Easy (GUI/CLI) — บอกภาษา/แพ็กเกอร์
```

---

## 2) strings (ตัวช่วยอันดับ 1)

```bash
strings -n 6 challenge | head -60
strings -n 6 challenge | grep -i -E 'csg|flag|pass|secret|correct|wrong|admin'
strings -el challenge | grep -i -E 'csg|flag'        # UTF-16 (Windows/.NET)
strings -t x challenge | grep -i csg                 # พร้อม offset
```

---

## 3) ELF

```bash
readelf -h challenge                  # header
readelf -S challenge                  # sections
readelf -s challenge | grep FUNC      # symbols
readelf -d challenge                  # dynamic (lib ที่ใช้)

objdump -d -M intel challenge > disasm.txt
objdump -d -M intel challenge | grep -B3 -A3 'call.*strcmp'
objdump -s -j .rodata challenge       # ข้อมูลใน section .rodata

nm -C challenge | head -30            # symbols (ถ้าไม่ strip)
ldd challenge                         # ไลบรารีที่ต้องใช้
```

---

## 4) checksec (ELF hardening)

```bash
checksec --file=challenge
# ผลที่ได้:
#   RELRO  Canary  NX  PIE  RPATH  RUNPATH  Symbols  FORTIFY
#   Full   Yes     Yes Yes  No     No       No       Yes

# อ่านผล:
#   NX enabled + No canary  -> เขียนทับ return address ได้ (pwn)
#   PIE enabled             -> ที่อยู่สุ่ม (ต้อง leak address)
#   No PIE                  -> ใช้ address คงที่ได้ (ง่าย)
```

---

## 5) รันและดักดูพฤติกรรม

```bash
chmod +x challenge
./challenge                       # รันตรง ๆ
echo test | ./challenge           # ป้อน input
./challenge AAAA                  # ใส่ argument

ltrace -f -s 200 ./challenge                       # ฟังก์ชันไลบรารี
ltrace -f -s 200 ./challenge 2>&1 | grep strcmp    # หารหัสผ่าน
strace -f -s 200 ./challenge                       # system call
strace -e trace=openat,read,write ./challenge
```

---

## 6) gdb (+ peda / pwndbg / gef)

```bash
gdb ./challenge
gdb -q ./challenge                    # ไม่แสดง banner
gdb -x /opt/tools/gef.py ./challenge  # โหลด GEF
gdb -ex 'set disassembly-flavor intel' -ex 'b main' -ex run ./challenge
```

คำสั่งใน gdb:

```gdb
set disassembly-flavor intel
b main                     # breakpoint
b *0x4011a0                # breakpoint ที่ address
run
run < input.txt
ni / si / n / s            # step
continue
x/s $rdi                   # string ที่ rdi ชี้
x/20x $rsp                 # stack
info registers
bt                         # backtrace
find $rsp, $rsp+0x1000, "CSG"
set $rax = 0               # บังคับผลเปรียบเทียบ
jump *0x401200             # ข้ามการตรวจ
```

> ไฟล์เสริมในเครื่องแข่ง: `/opt/tools/gef.py`, pwndbg (ติดตั้งแล้ว), peda

---

## 7) UPX / แพ็กเกอร์

```bash
upx -l challenge              # ดูว่าแพ็กอยู่ไหม
upx -d challenge -o unpacked  # แตก
strings unpacked | grep -i csg
```

ถ้า `upx -d` ฟ้อง `CantUnpackException` → header ถูกแก้ ให้ซ่อมด้วย HxD (แก้ชื่อ section `UPX0`/`UPX1` กลับ)

---

## 8) Python

```bash
# .pyc
file challenge.pyc
pycdc challenge.pyc > out.py
uncompyle6 -o out/ challenge.pyc
unpyc3 challenge.pyc

# ดู bytecode
python3 -c "
import dis, marshal
f=open('challenge.pyc','rb'); f.read(16)
dis.dis(marshal.load(f))
"

# PyInstaller
pyinstxtractor-ng challenge.exe
pycdc challenge.exe_extracted/challenge.pyc
```

---

## 9) Windows PE

```bash
objdump -x sample.exe | head -50
objdump -d sample.exe | less
strings -el sample.exe | grep -i csg
capa sample.exe
die sample.exe
yara -r rules/ sample.exe
```

**dnSpy (GUI, .NET):** เปิด → ดู Method → Edit Method → Compile → Save Module
**x64dbg (GUI, native):** F9 run, F8 step over, F7 step into, คลิกขวา → Follow in Dump

---

## 10) Android

```bash
unzip -l app.apk | head
jadx -d out/ app.apk
grep -r -i -E 'csg|flag' out/ | head
apktool d app.apk -o apktool_out/
dex2jar app.apk -o app.jar
```

---

## 11) Ghidra (headless)

```bash
# เปิด GUI
ghidra

# วิเคราะห์อัตโนมัติจาก command line
$GHIDRA_HOME/support/analyzeHeadless /tmp/proj p1 -import challenge -deleteProject
```

**ลำดับใน GUI:**
```
Import → Analyze → Symbol Tree → Functions → main
     → Decompiler window → คลิกตัวแปร → L (rename)
     → Search → Program Text (หา "CSG")
```

---

## 12) radare2 / rizin

```bash
r2 -A challenge
afl                    # ฟังก์ชันทั้งหมด
iz                     # strings
izz                    # strings ทั้งไฟล์ (รวม data section)
axt @ str.flag         # ใครเรียกใช้ string นี้
pdf @ main             # disassemble main
VV                     # โหมด graph
/ CSG                  # ค้นหา
q
```

---

## 13) ROP / pwn (ถ้าโจทย์เป็นแนว binary exploitation)

```bash
checksec --file=challenge
ROPgadget --binary challenge | grep 'pop rdi'
ROPgadget --binary challenge --ropchain
python3 -c "from pwn import *; print(cyclic(100))"     # หา offset
gdb -q ./challenge -ex 'run' -ex 'bt'                   # ดู crash
```

โครง exploit พื้นฐาน (ret2win):

```python
from pwn import *
p = process("./challenge")
payload = b"A" * 40            # offset ถึง return address
payload += p64(0x4011a6)       # address ของ win()
p.sendline(payload)
p.interactive()
```

---

## 14) Patch ไฟล์

```bash
cp challenge patched
# เปลี่ยน jne (0x75) เป็น nop (0x90) ที่ offset 0x1234
printf '\x90\x90' | dd of=patched bs=1 seek=$((0x1234)) conv=notrunc
chmod +x patched && ./patched
```

---

## 15) ตารางเลือกเครื่องมือ

| สถานการณ์ | ใช้ |
|---|---|
| อยากรู้เร็วว่าโปรแกรมเช็กอะไร | `ltrace` |
| ต้องดูการอ่านไฟล์/เน็ต | `strace`, `tshark` |
| ต้องดูทีละคำสั่ง/แก้ค่า | `gdb` + gef/pwndbg |
| ต้องอ่านโค้ดทั้งไฟล์ | `Ghidra` / `radare2` |
| เป็น .NET | `dnSpy` |
| เป็น Java/Android | `jadx` / `Bytecode Viewer` |
| เป็น Python | `pycdc` / `pyinstxtractor-ng` |
| ถูกแพ็ก | `upx -d` |
| อยากรู้ว่ามัลแวร์ทำอะไร | `capa` + `YARA` |
