# OSINT Methodology — วิธีไล่หาข้อมูลแบบเป็นระบบ

> ใช้เมื่อ: โจทย์ให้ "รูป / ชื่อคน / ชื่อผู้ใช้ / โดเมน / อีเมล" มา แล้วถามหาข้อมูลที่เชื่อมโยง
> เครื่องมือ: `exiftool`, `git`, `whois`, `dig`, `curl`, `Google Chrome`, `pdftotext`
> กฎ: ทำกับ persona ในโจทย์เท่านั้น — ห้ามส่องบัญชีจริงของคนจริง

---

## 0) เลือกเส้นทางตามสิ่งที่ได้มา

```
ได้รูปถ่าย          -> ข้อ 1 (GPS + geoguess)
ได้ชื่อผู้ใช้        -> ข้อ 2
ได้โดเมน/เว็บ        -> ข้อ 3
ได้อีเมล             -> ข้อ 4
ได้ชื่อคน           -> ข้อ 5
ได้ไฟล์/เอกสาร       -> ข้อ 6 (metadata ในเอกสาร)
```

---

## 1) ได้รูปมา — ขั้นตอนที่ได้ผลที่สุด

### 1.1 ตรวจ metadata ก่อนเสมอ

```bash
exiftool -a -u -g1 photo.jpg
exiftool -n -GPSLatitude -GPSLongitude photo.jpg
```

ถ้ามีพิกัด → จบงาน (เปิด Google Maps)

```
https://www.google.com/maps?q=<lat>,<lon>
```

### 1.2 ถ้าไม่มี GPS → อ่านจากภาพ (geoguess)

**จาก writeup 2025 — O1: Japan geography / OSINT geoguess**

ลำดับการอ่านภาพ:

| สิ่งที่ดู | บอกอะไร |
|---|---|
| ภาษา/ป้าย | ประเทศ (อักษรคันจิ + ป้ายน้ำเงิน = ญี่ปุ่น) |
| ป้ายจราจร | รูปทรง/สีเฉพาะประเทศ |
| ป้ายทะเบียน | รูปแบบ + ตัวอักษรจังหวัด |
| ขับซ้าย/ขวา | ขับซ้าย = UK, JP, TH, AU, IN... |
| เสาไฟ/สายไฟ | ญี่ปุ่นมีสายไฟเยอะและเสาไม้ |
| พืช | สน/ปาล์ม/ใบไม้ผลัด |
| สถาปัตยกรรม | หลังคา หน้าต่าง วัสดุ |
| เงา + ดวงอาทิตย์ | ทิศ + ครึ่งโลก (เงาสั้นเที่ยง = เขตร้อน) |
| ป้ายร้าน/โลโก้ | แบรนด์ที่มีเฉพาะประเทศ |
| ยานพาหนะ | สี/รูปทรงรถเมล์ แท็กซี่ |

**ขั้นตอนคิด:**
1. ระบุประเทศ (จากภาษา/ป้าย)
2. ระบุภูมิภาค (จากพืช/อากาศ/สถาปัตยกรรม)
3. ระบุเมือง (จาก landmark/ชื่อถนน/ป้ายร้าน)
4. ระบุจุด (จากมุมกล้อง + Google Maps/Street View)

### 1.3 ค้นด้วยภาพ (ถ้ากติกาอนุญาต)

- ใช้ **Google Lens / Google Images** ผ่านเบราว์เซอร์ (Approved: Chrome)
- ⚠️ ถ้ากติกาห้ามอัปโหลดไฟล์โจทย์ ให้ค้นด้วย **คำสำคัญ** ที่อ่านได้จากภาพแทน

### 1.4 ตัวอย่างการตั้งคำค้น

```
"<ข้อความบนป้าย>" <ประเทศ>
"<ชื่อถนน>" street view
"<โลโก้ร้าน>" <เมือง>
```

---

## 2) ได้ชื่อผู้ใช้ (username) มา

```bash
# 1) ดูว่าใช้ชื่อเดียวกันที่ไหนอีก (ค้นในเบราว์เซอร์)
#    "<username>" site:github.com
#    "<username>" site:twitter.com
#    "<username>" pastebin

# 2) GitHub — มักมีอีเมลใน commit (เทคนิคที่ออกจริง)
git clone https://github.com/<user>/<repo>
cd <repo>
git log
git show -s --format='%ae' <commit_sha>
git log --format='%ae %an %ad' --date=iso
```

**จาก writeup 2025 — OSINT github**
คำสั่งในเฉลยมีแค่:

```bash
git log
git show -s --format='%ae' <commit_sha>
# Flag: CSG_FLAG{monicahayashi9@gmail.com}
```

### 2.1 ตรวจชื่อผู้ใช้ซ้ำหลายแพลตฟอร์ม (ทำในเบราว์เซอร์)

```
https://github.com/<username>
https://twitter.com/<username>
https://www.instagram.com/<username>
https://www.reddit.com/user/<username>
https://<username>.github.io
```

---

## 3) ได้โดเมน / เว็บไซต์มา

```bash
whois example.com                     # เจ้าของ, วันจด, nameserver
dig example.com ANY                   # record ทั้งหมด
dig +short example.com MX             # เมลเซิร์ฟเวอร์
dig +short example.com TXT            # TXT (บางทีมี flag!)
dig +short example.com NS
host -t ns example.com
nslookup -type=txt example.com
```

**หา subdomain:**

```bash
subfinder -d example.com -silent
# หรือไล่ด้วย ffuf
ffuf -u http://FUZZ.example.com -w subdomains.txt -fs 0
```

**ไฟล์ที่ต้องลอง:**

```bash
curl -s http://example.com/robots.txt
curl -s http://example.com/sitemap.xml
curl -s http://example.com/.well-known/security.txt
curl -s http://example.com/.git/HEAD
```

**Certificate Transparency** (ดูว่าเคยมี subdomain อะไร):
เปิด `https://crt.sh/?q=example.com` ในเบราว์เซอร์

---

## 4) ได้อีเมลมา

```bash
# 1) ตรวจรูปแบบ + องค์กร
# 2) Gravatar: md5 ของอีเมล -> รูปโปรไฟล์
echo -n "user@example.com" | md5sum
# เปิด: https://gravatar.com/avatar/<md5>
```

```bash
# 3) ดูว่าเคยปรากฏที่ไหน (ค้นในเบราว์เซอร์)
"user@example.com"
```

> หลีกเลี่ยงการ login/สมัครบริการด้วยอีเมลในโจทย์ — ผิดกติกาและเสี่ยง

---

## 5) ได้ชื่อคนมา

1. ค้น `"<ชื่อเต็ม>"` + ประเทศ/บริษัท
2. ลองรูปแบบ username ที่เกิดจากชื่อ:
   ```
   name.surname / namesurname / n.surname / surname.name / name_surname
   ```
3. ดูเอกสาร PDF ที่เกี่ยวข้อง (metadata มักมีชื่อผู้สร้าง)

```bash
exiftool document.pdf | grep -i -E 'author|creator|producer'
pdftotext document.pdf - | head -30
```

---

## 6) ได้ไฟล์/เอกสารมา — OSINT จาก metadata

```bash
exiftool -a -u -g1 file.jpg          # กล้อง, เวลา, โปรแกรมแก้
exiftool file.pdf                    # Author, Creator, Producer
olemeta file.docx                    # ชื่อผู้สร้าง Office
strings -n 8 file.pdf | grep -i -E '@|http'
```

**จาก writeup 2025 — O1 (Japan geography) / Secret Lesson**
โจทย์แนวนี้มักให้ภาพหรือเอกสาร แล้วคำตอบอยู่ใน metadata หรือในเนื้อหา (เช่น ชื่อสถานที่, เวลา, หมายเลข)

---

## 7) Google Dorking — คำค้นที่ได้ผล

```
site:example.com filetype:pdf
site:example.com inurl:admin
site:example.com ext:sql | ext:bak | ext:zip
"CSG_FLAG" site:example.com
intext:"index of" "backup"
filetype:xlsx "password"
```

---

## 8) ข้อมูลที่มักเป็นคำตอบของโจทย์ OSINT

- ชื่อ-นามสกุลเต็มของเจ้าของ
- อีเมล (จาก commit / metadata)
- พิกัดสถานที่ (จาก GPS หรือ geoguess)
- วันที่ (ถ่ายรูป / จดโดเมน / commit)
- ชื่อ Wi-Fi / ชื่อเครื่อง (จากภาพหน้าจอ)
- หมายเลขโทรศัพท์ / ที่อยู่บนป้าย

---

## 9) บันทึกผลแบบนี้ (ช่วยมากเวลาต้องส่ง flag)

```
เป้าหมาย      :
เบาะแสที่เจอ   :
แหล่งที่มา    : <URL / ไฟล์>
ข้อมูลที่ได้   :
ข้อสันนิษฐาน  :
ขั้นต่อไป      :
```

---

## 10) ข้อควรระวัง

- ห้ามใช้ข้อมูลนี้ไปยุ่งกับบัญชีจริงของคนจริง
- อย่าอัปโหลดไฟล์โจทย์ขึ้นบริการวิเคราะห์ (VirusTotal / CrackStation ฯลฯ) — อยู่ใน Unapproved List
- ถ้าใช้ Google Lens/Images ให้แน่ใจว่ากติกาอนุญาต (บางสนามห้าม)
- เก็บ screenshot ไว้เป็นหลักฐานใน writeup
