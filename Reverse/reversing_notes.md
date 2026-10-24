# Reversing Notes — แนวคิดและลำดับการแก้โจทย์ reverse

> ใช้เมื่อ: ได้ไฟล์โปรแกรมมา (.exe, ELF, .pyc, .apk, .dll, .jar, .php)
> เครื่องมือที่อนุญาต: `file`, `strings`, `readelf`, `objdump`, `checksec`, `ltrace`, `strace`, `gdb`(+peda/pwndbg/gef), `ghidra`, `radare2`, `rizin`, `UPX`, `pycdc`, `uncompyle6`, `unpyc3`, `pyinstxtractor-ng`, `jadx`, `apktool`, `dnSpy`, `Bytecode Viewer`, `capa`, `YARA`, `x64dbg`, `Detect It Easy`
> **ห้าม**: `IDA Free` (ไม่อนุมัติ), `PEiD` (ไม่อนุมัติ)

---

## 0) ตัดสินใจจากชนิดไฟล์

```
file challenge
├─ ELF 64-bit        -> Linux binary  -> ข้อ 2
├─ PE32+ (.exe/.dll) -> Windows       -> ข้อ 3
├─ .NET / C#         -> dnSpy         -> ข้อ 3.3
├─ Python byte-compiled (.pyc) -> pycdc / uncompyle6 -> ข้อ 4
├─ PyInstaller exe   -> pyinstxtractor-ng -> ข้อ 4.3
├─ Zip/APK           -> jadx / apktool -> ข้อ 5
├─ .jar              -> Bytecode Viewer / fernflower
├─ PHP               -> ข้อ 6 (matryoshka)
└─ ไม่รู้             -> Detect It Easy (DIE) ก่อน
```

---

## 1) ขั้นตอนแรกที่ต้องทำทุกครั้ง (5 นาที)

```bash
file challenge              # ชนิด + สถาปัตยกรรม
strings -n 6 challenge | head -50
strings -n 6 challenge | grep -i -E 'csg|flag|pass|secret|correct|wrong'
strings -el challenge | grep -i -E 'csg|flag'   # UTF-16 (Windows)
checksec --file=challenge   # PIE/NX/Canary (ถ้าเป็น ELF)
chmod +x challenge && ./challenge    # รันดู! ถามอะไร? พิมพ์อะไร?
```

**ถ้าโปรแกรมถามรหัสผ่าน** → อย่าเพิ่งเปิด Ghidra ให้ลอง `ltrace` ก่อน (ข้อ 2.2)

---

## 2) ELF (Linux binary)

### 2.1 ดูโครงสร้าง

```bash
readelf -h challenge          # entry point, สถาปัตยกรรม
readelf -s challenge | grep -E 'FUNC|flag|main'    # symbol (ถ้าไม่ strip)
objdump -d -M intel challenge | less               # disassembly
```

### 2.2 ltrace — ทางลัดที่หลายคนมองข้าม

```bash
ltrace ./challenge
# ถ้าเห็น: strcmp("test", "S3cr3tP4ss") = -1
#          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ รหัสผ่านคือ S3cr3tP4ss
```

**จาก writeup แนว reversing พื้นฐาน** — โจทย์ที่ตัดสินใจด้วย `strcmp` จะเฉลยได้ในคำสั่งเดียว

```bash
ltrace -s 200 ./challenge 2>&1 | grep -E 'strcmp|strncmp|memcmp'
```

### 2.3 strace — ดูว่าโปรแกรมทำอะไรกับระบบ

```bash
strace -f -s 200 ./challenge 2>&1 | grep -E 'open|read|write|execve'
```

### 2.4 gdb (+ peda / pwndbg / gef)

```bash
gdb ./challenge
# โหลดส่วนเสริม (ไฟล์มีอยู่แล้วในเครื่องแข่ง):
#   gdb -x /opt/tools/gef.py ./challenge
```

คำสั่งใน gdb:

```gdb
set disassembly-flavor intel
b main
run
ni                      # ทีละคำสั่ง
x/s $rdi                # ข้อความที่ผู้ใช้พิมพ์
x/s $rsi                # ข้อความที่โปรแกรมคาดหวัง  <- มักเป็นรหัสผ่าน
set $rax = 0            # บังคับให้ผลเปรียบเทียบเป็น "เท่ากัน"
continue
```

> ทางลัด: `b *main+<offset>` หลังดู `objdump` ว่ามี `call strcmp` ตรงไหน

### 2.5 flag ที่ถูกประกอบตอนรัน

```bash
ltrace ./challenge 2>&1 | grep -i csg
strace -e trace=write ./challenge 2>&1 | grep -i csg
# หรือใน gdb: find $rsp, $rsp+0x1000, "CSG"
```

---

## 3) Windows PE (.exe / .dll)

### 3.1 ดูเบื้องต้น

```bash
file sample.exe
strings -n 6 sample.exe | grep -i -E 'csg|flag|http|password'
strings -el sample.exe | grep -i -E 'csg|flag'      # ต้องลอง! PE มักเป็น UTF-16
objdump -x sample.exe | head -40                    # sections, imports
```

**จาก writeup 2025 — Packer (Reversing)**
โจทย์ตั้งใจแพ็กไฟล์ด้วย UPX → แก้ด้วย:

```bash
upx -d packed.exe -o unpacked.exe
strings unpacked.exe | grep -i csg
```

ถ้า `upx -d` ไม่ได้ (header ถูกแก้) ให้ซ่อมก่อนด้วย HxD แล้วลองใหม่

### 3.2 วิเคราะห์พฤติกรรมแบบไม่รัน

```bash
capa sample.exe                 # บอกความสามารถ (persistence, C2, crypto)
die sample.exe                  # Detect It Easy: บอกว่าแพ็ก/ภาษา/คอมไพเลอร์
yara -r rules/ sample.exe       # สแกนกฎ
```

**จาก writeup 2025 — Hunt4C2 (Reversing)**
แนวทางคือใช้ `YARA` + `capa` หา indicator ของ C2 แทนการ reverse ทั้งไฟล์

### 3.3 .NET (C#) — ใช้ dnSpy

```
1. เปิด dnSpy → File → Open → sample.exe
2. ดู tree ด้านซ้าย: ชื่อ class/method มักอ่านออก
3. คลิก method ที่ชื่อน่าสงสัย (CheckFlag, Verify, Login)
4. อ่าน pseudo-C# ได้เลย
5. ถ้าต้องการแก้: คลิกขวา → Edit Method → แก้ → Compile → Save Module
```

> ทางเลือก CLI: `Bytecode Viewer` หรือ `fernflower` (สำหรับ .jar)

### 3.4 x64dbg (Windows)

```
1. เปิด x64dbg → File → Open → sample.exe
2. F9 = run, F8 = step over, F7 = step into
3. คลิกขวา → Search for → String references
4. ไปที่ call ที่ตรวจรหัส → เปลี่ยน ZF flag (double click ใน flag panel)
```

---

## 4) Python (.pyc / PyInstaller / .py ที่ถูก obfuscate)

### 4.1 .pyc — แปลงกลับเป็นโค้ด

```bash
file challenge.pyc                  # ดูเวอร์ชัน Python จาก magic bytes
xxd -l 16 challenge.pyc

pycdc challenge.pyc                 # ตัวหลัก (รองรับหลายเวอร์ชัน)
uncompyle6 challenge.pyc            # Python <= 3.8
unpyc3 challenge.pyc                # ทางเลือก
```

> ถ้าเป็น Python 3.11+ ให้ใช้ `pycdc` ก่อน (uncompyle6 ยังไม่รองรับ)

### 4.2 ถ้าถอดไม่ได้ — อ่าน bytecode

```bash
python3 -c "
import dis, marshal, sys
f=open('challenge.pyc','rb'); f.read(16)
dis.dis(marshal.load(f))
" | head -60
```

### 4.3 PyInstaller (.exe ที่แพ็ก Python)

```bash
pyinstxtractor-ng challenge.exe      # แตกออกมาเป็น .pyc
ls challenge.exe_extracted/
pycdc challenge.exe_extracted/challenge.pyc
```

### 4.4 .py ที่ถูก obfuscate ด้วย eval(zlib+base64)

ทำมือด้วยสคริปต์สั้น ๆ แบบนี้:

```python
import base64, zlib, re
s = open("challenge.py").read()
for _ in range(10):
    m = re.search(r'base64\.b64decode\(["\']([^"\']+)', s)
    if not m: break
    s = zlib.decompress(base64.b64decode(m.group(1))).decode()
print(s)
```

---

## 5) Android (.apk)

```bash
unzip -l app.apk | head -30
jadx -d out/ app.apk                 # แปลงเป็น Java (อ่านง่ายสุด)
apktool d app.apk -o apktool_out/    # แตก resource และ smali
grep -r -i 'csg\|flag' out/ apktool_out/
```

> ไฟล์ `classes.dex` → `jadx` หรือ `dex2jar` + `Bytecode Viewer`

---

## 6) PHP ที่ห่อหลายชั้น (matryoshka)

**จาก writeup 2025 — Reversing matryoshka**

ไฟล์ PHP ที่หน้าตาเป็น:

```php
<?php eval(gzinflate(base64_decode("..."))); ?>
```

หลักคิด: **ถอดจากชั้นในสุดออกมาเรื่อย ๆ** ไม่ต้องรัน PHP

```bash
# ใช้สคริปต์ที่เตรียมไว้
python3 unhook.py     # ชื่อไฟล์ตามที่ตั้งเอง

# หรือทำมือ ทีละชั้น
python3 - <<'PY'
import re, base64, zlib
s = open("round_1.php").read()
for i in range(2000):
    m = re.search(r'base64_decode\(["\']([^"\']+)', s)
    if not m: break
    s = zlib.decompress(base64.b64decode(m.group(1))).decode("latin1")
    if i % 20 == 0: print("layer", i, len(s))
open("final.txt","w").write(s)
print(s[:2000])
PY
```

---

## 7) Go binary

```bash
strings -n 8 challenge | grep -i -E 'csg|flag|main\.'
goresym -m -d challenge 2>/dev/null | head -40      # กู้ชื่อฟังก์ชัน Go
```

**จาก writeup 2025 — Reversing gorillabot**
ไบนารี Go จะมีชื่อฟังก์ชันเต็มอยู่ในไฟล์ → `strings` + `goresym` มักพอ

---

## 8) ไฟล์ที่ "เสียหาย" (corrupted)

**จาก writeup 2025 — Reversing corrupted**

อาการ: เปิดใน Ghidra ไม่ได้ / `file` บอกไม่ชัด

```bash
file corrupted
xxd -l 64 corrupted          # เทียบ header กับไฟล์ปกติชนิดเดียวกัน
objdump -x corrupted | head  # PE: ดู e_lfanew ที่ offset 0x3C
```

วิธีซ่อม:
1. หา header ต้นฉบับ (ไฟล์ปกติชนิดเดียวกัน หรือ search ขนาด)
2. แทนที่ไบต์แรก ๆ ด้วย `dd` หรือ HxD
3. ลอง `file` อีกครั้ง → ถ้าถูกแล้วค่อยเปิด Ghidra

---

## 9) Ghidra — ใช้งานเร็ว ๆ

```
1. เปิด Ghidra → New Project → Non-Shared
2. File → Import File → เลือก binary (auto-detect)
3. Double click → Analyze (Yes)
4. ดู Symbol Tree → Functions → หา main
5. หน้าต่าง Decompile ด้านขวา = โค้ด C อ่านง่าย
6. คลิกที่ตัวแปร → Rename (L) ตั้งชื่อให้อ่านง่าย
7. Search → For Strings → หา "flag"
```

**Headless (สั่งจาก command line):**

```bash
$GHIDRA_HOME/support/analyzeHeadless /tmp/ghidra_proj proj1 -import challenge -postScript PrintStrings.java
```

---

## 10) radare2 / rizin — ทางเลือกที่เร็ว

```bash
r2 -A challenge
[0x00000000]> afl                 # list functions
[0x00000000]> axt @ str.flag      # ใครอ้างถึง string นี้
[0x00000000]> pdf @ main          # disassemble main
[0x00000000]> iz                  # strings ทั้งหมด
[0x00000000]> / CSG               # ค้นหาใน memory
[0x00000000]> q
```

rizin ใช้คำสั่งเดียวกัน (`rizin -A challenge`)

---

## 11) Patch — แก้โปรแกรมให้ผ่านการตรวจ

```bash
# 1) หาตำแหน่งคำสั่งที่ตรวจ (objdump/gdb)
objdump -d -M intel challenge | grep -A5 -B5 'cmp'

# 2) แก้ไบต์ (ต้องรู้ offset ในไฟล์ ไม่ใช่ virtual address)
#    ตัวอย่าง: เปลี่ยน jne (75) เป็น je (74) หรือ nop (90)
cp challenge patched
printf '\x90\x90' | dd of=patched bs=1 seek=$((0x1234)) conv=notrunc

# 3) รันดู
chmod +x patched && ./patched
```

> ใน Ghidra: คลิกขวาที่คำสั่ง → Patch Instruction
> ใน x64dbg: คลิกขวา → Assemble / Binary → Edit

---

## 12) ลำดับการทำงานสรุป

```
file → strings (+ -el) → รันดู → ltrace/strace → gdb
   ↓ (ถ้าซับซ้อน)
Ghidra/r2 → หา main → หา string "flag" → ดูว่าใครเรียก
   ↓ (ถ้าเป็นแพ็ก/ภาษาเฉพาะ)
UPX -d / pycdc / jadx / dnSpy / matryoshka
   ↓ (ถ้ายังไม่ออก)
patch หรือ emulate (qemu) หรือเขียน script คำนวณย้อนกลับ
```

---

## 13) เคล็ดลับจากสนาม

1. **รันโปรแกรมก่อน** — หลายข้อเฉลยได้จากการพิมพ์อะไรลงไปดู
2. `ltrace` เร็วกว่า Ghidra 10 เท่า สำหรับโจทย์ `strcmp`
3. ถ้า strings ไม่เจออะไรเลย ให้สงสัย **แพ็ก (UPX)** หรือ **ข้อความถูกเข้ารหัส**
4. อย่าเสียเวลา reverse ทั้งไฟล์ — หา "จุดตัดสินใจ" (branch ที่นำไปสู่ flag) ให้เจอ
5. โจทย์แนว "flag encoder" ให้เขียน **ตัวถอดย้อนกลับ** จากการอ่านอัลกอริทึม (มักเป็น XOR/สลับตำแหน่ง)
