# binwalk & Carving — หาไฟล์ที่ซ่อนอยู่ในไฟล์

> ใช้เมื่อ: สงสัยว่าในไฟล์มี "ไฟล์อื่น" ต่อท้าย/ฝังอยู่ (รูปที่มี zip, pdf ที่มีรูป, ไฟล์ที่ต่อกันหลายอัน)
> เครื่องมือ: `binwalk`, `foremost`, `testdisk`/`photorec`, `dd`, `unzip`, `7z`, `bkcrack`, `fcrackzip`, `john`

---

## 1) binwalk — คำสั่งหลัก 4 แบบ

```bash
# 1) สแกนเฉย ๆ (ไม่แตะไฟล์) — เริ่มจากอันนี้เสมอ
binwalk suspicious.jpg

# 2) สแกน + แตกไฟล์ที่เจอออกมาที่ _suspicious.jpg.extracted/
binwalk -e suspicious.jpg

# 3) แตกแบบกำหนดชนิดเอง (แม่นกว่าเมื่อ binwalk เดาชนิดผิด)
binwalk --dd='zip:zip:.*' suspicious.jpg

# 4) ดู entropy (กราฟ) — ใช้หา "ส่วนที่ถูกบีบอัด/เข้ารหัส"
binwalk -E suspicious.bin
```

**อ่านผลลัพธ์:**

```
DECIMAL       HEXADECIMAL     DESCRIPTION
--------------------------------------------------------------------------------
0             0x0             JPEG image data, JFIF standard 1.01
1543          0x607           Zip archive data, at least v2.0 to extract, name: secret.txt
2917          0x61B5          End of Zip archive
```

→ มี ZIP เริ่มที่ offset `1543` → แตกออกมา:

```bash
dd if=suspicious.jpg of=hidden.zip bs=1 skip=1543
unzip -l hidden.zip
unzip hidden.zip
```

> ถ้า binwalk รุ่นใหม่ปฏิเสธให้รันเฉพาะ root: `binwalk --run-as=root -e file`

---

## 2) อย่าลืม `unzip` ตรง ๆ — เร็วที่สุดและบ่อยที่สุด

**จาก writeup 2025 — S2: Save the Cutest Cat (Stegano)**
ไฟล์ `S3.jpg` เปิดด้วย unzip ได้เลย ไม่ต้อง binwalk

```bash
exiftool S3.jpg            # 1) ดู metadata ก่อน -> เจอ password ใน User Comment
unzip -l S3.jpg            # 2) ดูว่ามีอะไรข้างใน
unzip S3.jpg               # 3) แตกออกมา (ถ้ามีรหัส จะถาม)
unzip -P 'WATPHO-RECLINING-BUDDHA' S3.jpg    # ใส่รหัสที่ได้จาก metadata
```

**จาก writeup 2025 — C2: Plato (Crypto)**
`Plato.jpg` มี ZIP ต่อท้าย รหัสคือ `man` (คำที่หายไปจาก quote ในโจทย์)

```bash
binwalk Plato.jpg
dd if=Plato.jpg of=plato.zip bs=1 skip=<offset>
unzip -P man plato.zip -d plato/
ls plato/             # ได้รูป 12 ชิ้น (4x3) -> ต้องต่อจิ๊กซอว์ก่อน
```

---

## 3) foremost / photorec — กู้ไฟล์เมื่อไม่รู้ offset

```bash
# foremost: ไล่หาชนิดไฟล์ที่กำหนด แล้วเซฟแยกโฟลเดอร์
foremost -t all -i disk.img -o out_foremost/
foremost -t jpg,png,zip,pdf -i suspicious.bin -o out_foremost/

# photorec: กู้ไฟล์จากอิมเมจดิสก์ (โต้ตอบทีละขั้น)
photorec disk.img
#   -> เลือกพาร์ทิชัน -> เลือกชนิดไฟล์ -> เลือกโฟลเดอร์ปลายทาง
```

`out_foremost/` จะมีโฟลเดอร์แยกตามชนิด (`jpg/`, `zip/`, `png/`) — ไล่ดูทีละอัน

---

## 4) ไฟล์ที่ติดรหัสผ่าน

### 4.1 ZIP — เดารหัส

```bash
# ลองรหัสว่าง + รหัสที่เดาง่าย ๆ ก่อน
unzip -P '' file.zip
for p in password 123456 admin ctf flag csg csg2026 infected novirus man; do
  unzip -P "$p" -t file.zip >/dev/null 2>&1 && echo "เจอ: $p" && break
done
```

### 4.2 ZIP — ใช้ john (ชัวร์กว่า)

```bash
zip2john file.zip > zip.hash
john --wordlist=/usr/share/wordlists/rockyou.txt zip.hash
john --show zip.hash
# ได้รหัสแล้ว
unzip -P '<รหัส>' file.zip
```

### 4.3 ZIP — brute force สั้น ๆ (รหัส a-z ไม่เกิน 4 ตัว)

```bash
fcrackzip -u -D -p /usr/share/wordlists/rockyou.txt file.zip
fcrackzip -u -b -l 1-4 -c a file.zip        # brute a-z ยาว 1-4
```

### 4.4 ZIP แบบ ZipCrypto — bkcrack (เมื่อมี known plaintext)

ถ้ารู้ว่าใน zip มีไฟล์ที่เรารู้เนื้อหา (เช่น `flag.txt` ที่ขึ้นต้นด้วย `CSG_FLAG{`):

```bash
# 1) ดูรายชื่อไฟล์ในซิป
unzip -l secret.zip

# 2) เตรียม plaintext ที่รู้ (อย่างน้อย 12 ไบต์ ต้องตรงเป๊ะ)
printf 'CSG_FLAG{' > plain.bin

# 3) โจมตี
bkcrack -C secret.zip -c flag.txt -p plain.bin

# 4) ได้ key มาแล้ว -> ถอดทั้งซิป
bkcrack -C secret.zip -k <key1> <key2> <key3> -U unlocked.zip <newpassword>
```

> ใช้ได้กับ **ZipCrypto (แบบเก่า)** เท่านั้น ไม่ใช่ AES-256

### 4.5 7z / RAR

```bash
7z l file.7z
7z x -p'<รหัส>' file.7z -oout/
# RAR
unrar x -p'<รหัส>' file.rar
# ถ้าไม่รู้รหัส: ทำ hash แล้ว john
7z2john.pl file.7z > h.txt && john --wordlist=/usr/share/wordlists/rockyou.txt h.txt
rar2john file.rar > h.txt && john --wordlist=/usr/share/wordlists/rockyou.txt h.txt
```

---

## 5) ไฟล์บีบอัดชนิดอื่นที่ต้องรู้จัก

```bash
file mystery.bin
# gzip
gunzip -c mystery.bin > out.bin
# bzip2 / xz / lz4 / zstd / lzip / lrzip
bunzip2 -c mystery.bin > out.bin
xz -dc mystery.bin > out.bin
lz4 -d mystery.bin out.bin
zstd -d mystery.bin -o out.bin
lzip -dc mystery.bin > out.bin
lrzip -d mystery.bin
# tar (ดูข้างในก่อนแตก)
tar -tvf mystery.tar
tar -xf mystery.tar -C out/
```

**แตกซ้อนหลายชั้นอัตโนมัติ:**

```bash
f=mystery.bin; for i in $(seq 1 6); do
  t=$(file -b "$f")
  case "$t" in
    *gzip*)  mv "$f" "$f.gz";  gunzip -f "$f.gz"; f="${f%.gz}" ;;
    *bzip2*) mv "$f" "$f.bz2"; bunzip2 -f "$f.bz2"; f="${f%.bz2}" ;;
    *XZ*)    mv "$f" "$f.xz";  xz -df "$f.xz"; f="${f%.xz}" ;;
    *Zip*)   unzip -o "$f" -d "layer$i"; f=$(find "layer$i" -type f | head -1) ;;
    *tar*)   mkdir -p "layer$i"; tar -xf "$f" -C "layer$i"; f=$(find "layer$i" -type f | head -1) ;;
    *) echo "หยุดที่ชั้น $i: $t"; break ;;
  esac
  echo "ชั้น $i -> $f"
done
file -b "$f"; strings -n 6 "$f" | grep -i csg
```

---

## 6) กรณี "ไฟล์เดียวซ่อนหลายไฟล์" — polyglot

```bash
# ดูว่ามีกี่ signature
binwalk file.bin | grep -E 'Zip|PNG|JPEG|PDF|gzip|ELF'

# แยกทุกส่วนออกมา
binwalk -e file.bin
ls _file.bin.extracted/
```

ถ้า binwalk แตกไม่ครบ ให้ `dd` ทีละ offset ที่เห็น

---

## 7) ตรวจว่าข้างในมีแฟล็กไหม (หลังแตกไฟล์)

```bash
grep -a -r -o 'CSG_FLAG{[^}]*}' _*.extracted/
strings -n 6 _*.extracted/* | grep -i csg
```

หรือใช้สคริปต์สำเร็จรูป:

```bash
bash scripts/flag_hunt.sh .              # สแกนทั้งโฟลเดอร์ (grep+strings+base64+แตกซ้ำ)
python3 scripts/run_pipeline.py Plato.jpg  # ตรวจไฟล์เดียวแบบครบขั้นตอน
```

---

## 8) ลำดับการทำงาน (จำไปใช้ได้เลย)

```
file → binwalk → unzip -l → binwalk -e → foremost
   ↓ (ถ้าติดรหัส)
exiftool (หารหัสใน metadata) → ลองรหัสง่าย → zip2john+john → bkcrack
   ↓ (ถ้าแตกได้แล้ว)
strings / grep CSG_FLAG / เปิดไฟล์ดูเอง
```

---

## 9) ข้อควรระวัง

- `binwalk -e` จะ **เขียนไฟล์ลงโฟลเดอร์ปัจจุบัน** — รันในโฟลเดอร์ทำงานแยกจะไม่รก
- ไฟล์ใหญ่ (>1 GB) ให้ใช้ `--dd` ระบุชนิดแทน `-e` เพื่อไม่ให้แตกพร่ำเพรื่อ
- `dd` ผิด offset = ไฟล์เสีย ให้ตรวจ offset จาก binwalk อีกครั้ง
- ถ้าแตกได้แต่เปิดไม่ได้ → กลับไปดู `file_signatures.md` (header อาจถูกแก้)
