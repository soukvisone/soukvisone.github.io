# File Signatures — รู้จักไฟล์จากไบต์แรก (Forensics 101)

> ใช้เมื่อ: ได้ไฟล์มาแล้ว **ไม่รู้ว่าจริง ๆ เป็นอะไร** (นามสกุลหลอกได้เสมอ)
> เครื่องมือ: `file`, `xxd`, `hexdump`, `HxD` (Windows), `CyberChef`

---

## 1) คำสั่งแรกที่ต้องรันทุกครั้ง

```bash
file suspicious.bin                 # ดู magic bytes ไม่สนนามสกุล
file -b --mime-type suspicious.bin  # เอา MIME ไปใช้ต่อ
xxd -l 64 suspicious.bin            # ไบต์แรก 64 ไบต์ (ดูด้วยตา)
```

ตัวอย่างผลลัพธ์:

```
suspicious.bin: PNG image data, 1920 x 1080, 8-bit/color RGBA, non-interlaced
```

แปลว่า **นามสกุลหลอก** — ของจริงเป็น PNG → เปลี่ยนชื่อเป็น `.png` แล้วเปิดดู

```bash
mv suspicious.bin suspicious.png
```

**จาก writeup 2025 — S2: Save the Cutest Cat (Stegano)**
ไฟล์ `S3.jpg` หน้าตาเป็น JPEG ปกติ แต่เปิดด้วย unzip ได้ เพราะข้างในมี ZIP ต่อท้าย
→ บทเรียน: `file` อย่างเดียวไม่พอ ต้องลอง `unzip -l` ด้วย (ดู `binwalk_commands.md`)

---

## 2) ตาราง Magic Bytes ที่ต้องจำ

| ชนิดไฟล์ | ไบต์แรก (hex) | หน้าตาใน xxd | นามสกุล |
|---|---|---|---|
| PNG | `89 50 4E 47 0D 0A 1A 0A` | `.PNG....` | .png |
| JPEG | `FF D8 FF` | `ÿØÿ` | .jpg |
| GIF | `47 49 46 38` | `GIF8` | .gif |
| BMP | `42 4D` | `BM` | .bmp |
| PDF | `25 50 44 46` | `%PDF` | .pdf |
| ZIP | `50 4B 03 04` | `PK..` | .zip/.docx/.xlsx/.apk |
| RAR | `52 61 72 21` | `Rar!` | .rar |
| 7-Zip | `37 7A BC AF 27 1C` | `7z..'.` | .7z |
| GZIP | `1F 8B` | `..` | .gz |
| BZIP2 | `42 5A 68` | `BZh` | .bz2 |
| XZ | `FD 37 7A 58 5A 00` | `..7zXZ.` | .xz |
| TAR | offset 257 = `75 73 74 61 72` | `ustar` | .tar |
| ELF (Linux) | `7F 45 4C 46` | `.ELF` | ไม่มีนามสกุล |
| PE / EXE (Windows) | `4D 5A` | `MZ` | .exe/.dll |
| Mach-O (mac) | `CF FA ED FE` | `....` | — |
| SQLite | `53 51 4C 69 74 65 20 66 6F 72 6D 61 74 20 33 00` | `SQLite format 3.` | .db/.sqlite |
| PCAP | `D4 C3 B2 A1` หรือ `A1 B2 C3 D4` | — | .pcap |
| PCAPNG | `0A 0D 0D 0A` | — | .pcapng |
| EVTX (Windows log) | `45 6C 66 46 69 6C 65 00` | `ElfFile.` | .evtx |
| OLE2 (doc/xls เก่า) | `D0 CF 11 E0 A1 B1 1A E1` | — | .doc/.xls |
| RIFF (WAV/AVI) | `52 49 46 46` | `RIFF` | .wav/.avi |
| MP3 | `49 44 33` | `ID3` | .mp3 |
| FLAC | `66 4C 61 43` | `fLaC` | .flac |
| OGG | `4F 67 67 53` | `OggS` | .ogg |

**ท่องให้ขึ้นใจ 5 ตัวที่เจอบ่อยสุด:** `%PDF`, `PK`, `MZ`, `.ELF`, `89 50 4E 47`

---

## 3) ไฟล์เสีย / header ถูกแก้ — ซ่อมยังไง

โจทย์แนว "Reversing corrupted" (writeup 2025) คือเอาไฟล์มาแล้วเปิดไม่ได้ เพราะ header เพี้ยน

### 3.1 PNG ที่เปิดไม่ขึ้น

```bash
pngcheck -v broken.png          # บอกว่าพังตรงไหน
xxd -l 32 broken.png            # เทียบกับ PNG ปกติ: 89 50 4E 47 0D 0A 1A 0A
```

ถ้า 8 ไบต์แรกเพี้ยน → เขียนทับด้วย header ที่ถูก:

```bash
printf '\x89PNG\r\n\x1a\n' | dd of=broken.png bs=1 conv=notrunc
pngcheck -v broken.png
```

(Windows: ใช้ **HxD** แก้ 8 ไบต์แรกด้วยมือ — ปลอดภัยกว่า)

### 3.2 ZIP ที่แตกไม่ได้

```bash
unzip -l broken.zip            # ดูสารบัญก่อน
zip -FF broken.zip --out fixed.zip    # ซ่อม ZIP ที่หัวไฟล์เสีย
7z l broken.zip                # 7z อ่านได้หลายกรณีที่ unzip พัง
```

### 3.3 ไฟล์ที่ถูกสลับหัวท้าย / ต่อกันหลายไฟล์

```bash
binwalk broken.bin             # ดูว่ามีกี่ไฟล์ต่อกัน (offset ไหน)
binwalk -e broken.bin          # แตกออกมาทั้งหมด
```

### 3.4 PE ที่รันไม่ขึ้น

```bash
file sample.exe
objdump -x sample.exe | head -40
# ถ้า MZ ถูก แต่ offset ของ PE header (e_lfanew ที่ 0x3C) เพี้ยน -> แก้ด้วย HxD
```

---

## 4) ดูไบต์ท้ายไฟล์ — จุดที่คนลืม

แฟล็กมักซ่อน **ต่อท้ายไฟล์** ไม่ใช่ต้นไฟล์

```bash
# ดู 200 ไบต์สุดท้าย
tail -c 200 suspicious.png | xxd

# หา flag ในส่วนท้าย
tail -c 5000 suspicious.png | strings -n 4 | grep -i csg
```

**จาก writeup 2025 — Cat Tail (Stegano)**
คำว่า "tail" ในชื่อโจทย์ไม่ได้หมายถึงหางแมว แต่หมายถึง **ท้ายไฟล์** — flag ส่วนที่ 3 อยู่ตรงนั้น

```bash
tail -c 1000 cat.png | strings
```

---

## 5) ไฟล์ที่ซ่อนไฟล์อื่นไว้ข้างใน (polyglot)

ไฟล์เดียวเป็นได้หลายอย่าง เช่น JPG + ZIP พร้อมกัน

```bash
file poly.jpg                  # บอก JPEG
unzip -l poly.jpg              # แต่อันนี้ก็เปิดได้!
binwalk poly.jpg               # เห็น offset ของ ZIP
dd if=poly.jpg of=hidden.zip bs=1 skip=<offset>   # แยกออกมา
```

**สูตรตรวจเร็ว:**

```bash
for f in *; do
  printf '%-30s ' "$f"
  file -b "$f" | cut -c1-50
done
```

---

## 6) ไฟล์ที่ไม่มีนามสกุลเลย

```bash
file *
ls -la                      # ดูขนาด + เวลา (บางทีบอกอะไรได้)
xxd -l 16 * | head -40      # ไบต์แรกของทุกไฟล์
```

ถ้าเป็นไบต์สุ่มทั้งหมด (entropy สูง) → อาจเป็น:
- ไฟล์ที่ถูก XOR
- ไฟล์ที่ถูกบีบอัด/เข้ารหัส
- memory dump / disk image

→ ไปดู `binwalk_commands.md` และ `../Crypto/crypto_cheatsheet.md` (XOR)

---

## 7) ตารางตัดสินใจ

| เจออะไร | ทำอะไรต่อ |
|---|---|
| `PK` | `unzip -l` → `binwalk -e` → `../Misc/useful_commands.md` (archive_crack) |
| `MZ` (exe) | `../Reverse/common_commands.md` |
| `.ELF` | `checksec` + `strings` + `../Reverse/reversing_notes.md` |
| `%PDF` | `pdfid`, `mutool info`, `peepdf` |
| `ElfFile` (evtx) | `chainsaw dump` / `hayabusa` |
| `SQLite format 3` | `sqlite3 file.db ".tables"` |
| `RIFF`/`fLaC`/`OggS` | `sox --i` + `../Misc/useful_commands.md` (audio) |
| ไบต์สุ่มทั้งหมด | XOR / entropy / memory dump |

---

## 8) เคล็ดลับจากสนามจริง

1. **อย่าเชื่อนามสกุล** — เปลี่ยนชื่อก่อนเปิดทุกครั้ง
2. **`file` อย่างเดียวไม่พอ** — ต้อง `binwalk` + `unzip -l` + `strings` ด้วย
3. **ไฟล์ใหญ่ผิดปกติ** (เช่น รูป 5 MB ที่ควรเป็น 200 KB) = มีอะไรซ่อนอยู่แน่นอน
4. **ดู timestamp** — บางโจทย์ใช้เวลาเป็นคำใบ้ (`exiftool` ดูข้อ `metadata.md`)
5. ถ้าแก้ไฟล์แล้วพัง ให้ **ก็อปเก็บต้นฉบับไว้ก่อน** (`cp broken.bin broken.bin.bak`)
