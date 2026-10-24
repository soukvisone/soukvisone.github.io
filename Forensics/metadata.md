# Metadata — ข้อมูลที่ไฟล์บอกเราโดยไม่ตั้งใจ

> ใช้เมื่อ: ได้รูป / PDF / เอกสาร Office / ไฟล์สื่อ มา แล้วต้องหา "เบาะแส"
> เครื่องมือ: `exiftool`, `pdfid`, `pdf-parser.py`, `mutool`, `qpdf`, `pdftotext`, `olemeta`, `strings`, `git`

Metadata เคยเฉลยโจทย์มาแล้วหลายข้อ: **รหัสผ่าน zip**, **พิกัด GPS**, **ชื่อคน**, **เวลา**, **ชื่อโปรแกรมที่ใช้แก้**

---

## 1) exiftool — คำสั่งเดียวที่ต้องใช้เป็น

```bash
exiftool file.jpg                  # ดูพื้นฐาน
exiftool -a -u -g1 file.jpg        # ดูทั้งหมด (a=all, u=unknown, g1=จัดกลุ่ม) ← ใช้ตัวนี้
exiftool -s file.jpg               # ชื่อ tag แบบสั้น (เอาไปอ้างอิงต่อ)
exiftool -G1 -a -s file.jpg        # มีชื่อกลุ่มกำกับ (อ่านง่าย)
```

**กรองเอาแต่ tag ที่มักมีคำตอบ:**

```bash
exiftool -a -u -g1 file.jpg | grep -i -E 'comment|description|artist|copyright|author|title|software|password'
```

---

## 2) จาก writeup จริง — metadata เคยให้ "รหัสผ่าน"

**จาก writeup 2025 — S2: Save the Cutest Cat (Stegano)**
ขั้นตอนในเฉลย:

1. `exiftool S3.jpg` → เจอ `User Comment: WATPHO-RECLINING-BUDDHA`
2. เอารหัสนั้นไปแตก zip ที่ซ่อนในรูป

```bash
exiftool S3.jpg | grep -i comment
unzip -P 'WATPHO-RECLINING-BUDDHA' S3.jpg
```

**จาก writeup 2025 — Cat Tail (Stegano)**
เฉลยบอกชัดว่า flag ถูกแบ่งเป็น 3 ส่วน:
- ส่วนที่ 1: LSB ของช่องสีฟ้า (Blue channel)
- ส่วนที่ 2: **metadata** (`exiftool`)
- ส่วนที่ 3: **ท้ายไฟล์** (tail)

```bash
exiftool -a -u -g1 cat.png | grep -i -E 'csg|flag|comment'
tail -c 2000 cat.png | strings
```

**บทเรียน:** ถ้าได้ flag ที่ขาดท่อน (`CSG_FLAG{T4bby_`) ให้ไปหา metadata + ท้ายไฟล์ต่อทันที

---

## 3) GPS — แปลงพิกัดเป็นลิงก์แผนที่

```bash
exiftool -GPSLatitude -GPSLongitude -GPSPosition -GPSAltitude file.jpg
```

ถ้าได้มาเป็น องศา/นาที/วินาที ให้แปลงเป็นทศนิยม:

```bash
exiftool -n -GPSLatitude -GPSLongitude file.jpg      # -n = ออกเป็นตัวเลขทศนิยมเลย
```

ได้ `13.7563  100.5018` → เปิดแผนที่:

```
https://www.google.com/maps?q=13.7563,100.5018
https://www.openstreetmap.org/?mlat=13.7563&mlon=100.5018#map=17/13.7563/100.5018
```

> ถ้าไม่มี GPS ให้ดู `GPSDateStamp` / `GPSTimeStamp` — บางโจทย์ถาม "ถ่ายกี่โมง"

**จาก writeup 2025 — O1: Japan geography / OSINT geoguess**
โจทย์แนวนี้ไม่ได้ใช้ GPS ตรง ๆ (มักถูกลบ) แต่ใช้ **เงา + ป้าย + ภาษา + พืช** ในภาพ → ไปดู `../OSINT/methodology.md`

---

## 4) รูป thumbnail ที่ซ่อนอยู่

รูปมักมี thumbnail ของ "ภาพก่อนแก้" ฝังอยู่

```bash
# ดูว่ามี thumbnail ไหม
exiftool -b -ThumbnailImage file.jpg > thumb.jpg
exiftool -b -PreviewImage file.jpg > preview.jpg
ls -l thumb.jpg preview.jpg
```

บางโจทย์ซ่อน flag ไว้ใน thumbnail (เพราะคนลืมลบ)

---

## 5) PDF — metadata และ stream ที่ซ่อนอยู่

```bash
# 1) ภาพรวม + จำนวน object ที่น่าสงสัย
pdfid file.pdf
#   ดูค่า /JS /JavaScript /OpenAction /AA /EmbeddedFile /Launch

# 2) ดู metadata
exiftool file.pdf
pdfinfo file.pdf          # ถ้ามี poppler-utils

# 3) ดึงข้อความทั้งหมด
pdftotext file.pdf - | head -100
pdftotext -layout file.pdf out.txt      # รักษารูปแบบตาราง

# 4) คลายการบีบอัด stream ทั้งหมดให้อ่านได้
qpdf --qdf --object-streams=disable file.pdf unpacked.pdf

# 5) ดูโครงสร้าง/สตรีม
mutool info file.pdf
mutool show file.pdf trailer
mutool extract file.pdf          # ดึงรูป/ฟอนต์ที่ฝังอยู่

# 6) ถังขยะในไฟล์ (object ที่ถูกลบแต่ยังอยู่)
peepdf -i file.pdf               # โหมดโต้ตอบ: พิมพ์ info, objects, stream <n>
```

**โจทย์ PDF ที่เจอบ่อย:**
- flag ใน `/Author` หรือ `/Subject`
- flag ใน JavaScript (`/JS`)
- flag ในรูปที่ฝัง (แตกด้วย `mutool extract` แล้วดูด้วย `zsteg`)
- flag ใน comment `%` ที่ซ่อนในสตรีม (ใช้ `qpdf --qdf` แล้ว `strings`)

---

## 6) เอกสาร Office — macro และ metadata

```bash
# ภาพรวม
oleid file.docm
olemeta file.docm            # metadata: ผู้สร้าง, เวลาสร้าง/แก้
oletimes file.docm           # timestamps ทั้งหมด

# macro
olevba file.docm             # ดึงโค้ด VBA + ธงอันตราย
olevba -c file.docm          # เฉพาะโค้ด
oledump.py file.docm         # ดู stream ข้างใน
oledump.py -s 8 -v file.docm # ดึง stream ที่ 8 แบบถอดการบีบอัด

# docx/xlsx (เป็น zip) — ดูข้างในตรง ๆ
unzip -o file.docx -d docx_out/
grep -r -a 'CSG_FLAG' docx_out/
```

---

## 7) git — metadata ที่คนลืม (เทคนิค OSINT ที่ออกจริง)

**จาก writeup 2025 — OSINT github**

```bash
git log                                  # ดูประวัติ commit
git show -s --format='%ae' <commit_sha>  # ดูอีเมลผู้เขียน commit
# เฉลย: CSG_FLAG{monicahayashi9@gmail.com}
```

คำสั่งที่มีประโยชน์เพิ่ม:

```bash
git log --all --oneline
git log -p --all | grep -i csg           # หา flag ในประวัติทั้งหมด
git log --format='%ae %an %ad' --date=iso
git show <sha>:path/to/file              # ดูไฟล์ ณ commit นั้น
git grep 'CSG_FLAG' $(git rev-list --all)  # ค้นทุก commit
```

---

## 8) ไฟล์อื่น ๆ ที่มี metadata

```bash
# วิดีโอ/เสียง
ffprobe file.mp4
mediainfo file.mp4
sox --i file.wav

# ZIP (เวลา + ชื่อไฟล์ภายใน)
zipinfo -v file.zip | head -40
7z l -slt file.zip

# SQLite (บางโจทย์เก็บ flag ใน DB)
sqlite3 file.db ".tables"
sqlite3 file.db ".dump" | grep -i csg

# รูปแบบ raw/disk
exiftool disk.img | head
```

---

## 9) เขียน metadata กลับ (เวลาต้องการทดสอบ)

```bash
# ใส่ comment (ใช้ทดสอบสคริปต์ตัวเองเท่านั้น)
exiftool -Comment='test' copy.jpg
```

> ระวัง: คำสั่งนี้ **แก้ไฟล์จริง** ให้ก็อปไว้ก่อน

---

## 10) Checklist 60 วินาที

```bash
f=challenge.jpg
exiftool -a -u -g1 "$f" > meta.txt
grep -i -E 'comment|author|artist|software|password|csg|flag' meta.txt
exiftool -n -GPSLatitude -GPSLongitude "$f"
exiftool -b -ThumbnailImage "$f" > thumb.jpg 2>/dev/null; file thumb.jpg
tail -c 2000 "$f" | strings | grep -i csg
```

ถ้าไม่เจอ → กลับไป `file_signatures.md` / `binwalk_commands.md`

---

## 11) ข้อควรระวัง

- `exiftool -all=` **ลบ metadata ทั้งหมด** (ห้ามใช้กับไฟล์โจทย์ก่อนส่ง flag)
- metadata ของรูปจากมือถืออาจมี **พิกัดบ้านเกิด** — อย่าเผลออัปโหลดรูปส่วนตัวขึ้นที่สาธารณะ
- ไฟล์ที่ดาวน์โหลดมาแล้ว metadata อาจถูก strip ไปแล้ว → ต้องดูที่ระดับไบต์ (`tail`, `strings`)
