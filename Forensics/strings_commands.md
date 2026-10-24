# strings — ขุดข้อความที่ซ่อนในไฟล์ไบนารี

> ใช้เมื่อ: ไฟล์เปิดไม่ได้ / เป็นไบนารี / สงสัยว่ามีข้อความฝังอยู่
> เครื่องมือ: `strings`, `ripgrep (rg)`, `FLOSS`, `xxd`, `grep`

**strings คือเครื่องมือที่คุ้มที่สุดในสนาม CTF** — หลายโจทย์เฉลยได้ใน 5 วินาทีด้วยคำสั่งเดียว

---

## 1) คำสั่งพื้นฐานที่ต้องใช้เป็น

```bash
strings file.bin                 # ข้อความยาว >= 4 ตัวอักษร
strings -n 6 file.bin            # ยาว >= 6 (ตัด noise ออก)
strings -n 8 file.bin            # ยาว >= 8 (สำหรับไฟล์ใหญ่ ๆ)
strings -t x file.bin            # บอก offset (hex) ของแต่ละบรรทัด
strings -a file.bin              # สแกนทั้งไฟล์ (ไม่ข้ามส่วนหัว)
```

**กรองเอาแต่ที่น่าสนใจ:**

```bash
strings -n 6 file.bin | grep -i -E 'csg|flag|pass|secret|key|admin|token'
```

---

## 2) ตัวเลือกที่คนมักลืม (แต่สำคัญมาก)

### 2.1 ข้อความ UTF-16 (ไฟล์ Windows / .NET / PowerShell)

Windows เก็บข้อความเป็น 2 ไบต์ต่อตัวอักษร → `strings` ปกติ **มองไม่เห็น**

```bash
strings -el file.exe | grep -i flag        # little-endian 16-bit (ที่ใช้บ่อยสุด)
strings -eb file.exe | grep -i flag        # big-endian 16-bit
```

**จาก writeup — Reversing (PE/.NET)**
ถ้า `strings file.exe` ไม่เจออะไรเลย ให้ลอง `strings -el` ก่อนสรุปว่าไม่มี

### 2.2 ข้อความที่ติดกันเป็นพืด (ไม่มี newline)

```bash
strings -n 20 file.bin | fold -w 100 | grep -i csg
```

### 2.3 ดู offset เพื่อไปแก้ไฟล์ต่อ

```bash
strings -t x file.bin | grep -i 'CSG'
# 0001a2b0 CSG_FLAG{...
xxd -s 0x1a2b0 -l 128 file.bin
```

---

## 3) สูตรสำเร็จที่ใช้บ่อยในสนาม

### 3.1 หา flag ตรง ๆ

```bash
strings -n 6 * 2>/dev/null | grep -o 'CSG_FLAG{[^}]*}' | sort -u
```

### 3.2 หา flag ที่ถูกแบ่งเป็นส่วน ๆ

โจทย์บางข้อตัด flag เป็น 3 ท่อนแล้วซ่อนคนละที่

```bash
strings -n 6 file.bin | grep -i -E 'csg|flag|\{|\}' -A2 -B2
```

### 3.3 หา base64 ที่ซ่อนอยู่ แล้วถอดทันที

```bash
strings -n 20 file.bin | grep -E '^[A-Za-z0-9+/]{20,}={0,2}$' | while read -r b; do
  d=$(printf '%s' "$b" | base64 -d 2>/dev/null)
  printf '%s' "$d" | grep -q 'CSG_FLAG' && echo "[$b] -> $d"
done
```

### 3.4 ดึง key/รหัสผ่านจาก memory dump (เทคนิคจาก CSG2024)

**จาก writeup 2024 — ข้อ memory forensics**
คำสั่งที่เฉลยใช้จริง:

```bash
strings 4960.dmp | grep SECRET > tlskey.log
```

ใช้หัก **TLS session key** จาก memory dump เพื่อถอด HTTPS ใน Wireshark
(ใน Wireshark: `Preferences → Protocols → TLS → (Pre)-Master-Secret log filename`)

### 3.5 หา path/ชื่อไฟล์ที่โปรแกรมเข้าถึง

```bash
strings -n 6 sample.exe | grep -E '^[A-Za-z]:\\|^/|\.txt|\.dll|\.exe|\.php'
```

### 3.6 หา URL / IP (โจทย์ malware C2)

```bash
strings -n 6 sample.exe | grep -E 'https?://|[0-9]{1,3}(\.[0-9]{1,3}){3}|\.onion'
```

---

## 4) เมื่อ strings ไม่พอ — FLOSS

มัลแวร์ชอบซ่อนข้อความแบบ "ประกอบกลับตอนรัน" (XOR/base64 ในโค้ด) → `strings` เห็นแต่ขยะ

```bash
floss sample.exe                 # ดึงทั้ง static + decoded strings
floss -q sample.exe | grep -i csg
```

FLOSS อยู่ใน Approved List (`pipx flare-floss`) — ใช้แทนการรันมัลแวร์จริงได้ปลอดภัยกว่า

---

## 5) ripgrep — เร็วกว่า grep สำหรับสแกนทั้งโฟลเดอร์

```bash
rg -a -o 'CSG_FLAG\{[^}]*\}' .            # -a = มองเป็น text
rg -a -i 'flag|csg' --max-count 5 .
rg -a -l 'CSG_FLAG' .                     # เอาแค่ชื่อไฟล์ที่เจอ
```

---

## 6) ข้อจำกัดของ strings (ต้องรู้ไว้จะได้ไม่เสียเวลา)

| สถานการณ์ | strings เห็นไหม | ต้องใช้อะไรแทน |
|---|---|---|
| ข้อความธรรมดา ASCII | เห็น | — |
| UTF-16 (Windows) | ไม่เห็น | `strings -el` |
| ข้อมูลถูก gzip/zip | ไม่เห็น | `binwalk -e`, `gunzip` |
| ข้อมูลถูก XOR | เห็นแต่ขยะ | `../Crypto/crypto_cheatsheet.md` (XOR) |
| ข้อความถูกสร้างตอนรัน | ไม่เห็น | `FLOSS`, `ltrace`, `gdb` |
| ข้อความอยู่ในรูป (LSB) | ไม่เห็น | `zsteg`, `StegSolve`, `OpenStego` |
| ข้อความใน PDF stream (บีบอัด) | ไม่เห็น | `mutool clean -d`, `qpdf --qdf` |

---

## 7) รวมคำสั่งที่ควรพิมพ์ก่อนคิดอะไรซับซ้อน

```bash
f=challenge.bin

file "$f"                                   # 1. มันคืออะไร
strings -n 6 "$f" | head -50                # 2. มีข้อความอะไร
strings -n 6 "$f" | grep -i -E 'csg|flag'   # 3. มี flag ไหม
strings -el "$f" | grep -i -E 'csg|flag'    # 4. มีแบบ UTF-16 ไหม
binwalk "$f" | head                          # 5. มีไฟล์อื่นซ่อนไหม
xxd -l 64 "$f"                               # 6. header เป็นอะไร
```

ถ้าทั้ง 6 ข้อไม่เจอ → ไปหมวดอื่น (`../Reverse/`, `../Crypto/`, `../Misc/`)

---

## 8) เคล็ดลับจากสนาม

1. **`strings | grep` คือคำสั่งแรกของการแข่งทุกครั้ง** — เร็วกว่าเปิด Ghidra
2. ถ้าเจอข้อความยาว ๆ ที่ดูเหมือน base64 ให้ `| base64 -d` ต่อทันที
3. ถ้าเจอ flag ที่ขาด `}` ให้ดูบรรทัดถัดไป (บางทีตัดเพราะมีอักขระพิเศษคั่น)
4. ไฟล์ `.dmp`, `.raw`, `.vmem` → `strings` ได้เลยแม้ไม่ใช้ Volatility
5. `strings` บนไฟล์ 100 MB ใช้เวลาเป็นนาที → ใส่ `-n 8` เพื่อเร็วขึ้น
