# Automation — หา Flag ด้วยคำสั่งเดียว

> หน้านี้รวม **สคริปต์ automation 6 ตัว** ที่ทำงานในเครื่องทั้งหมด (ไม่อัปโหลดอะไรออกเน็ต)
> เป้าหมาย: ลดเวลาคิดว่า "จะเริ่มตรงไหน" เหลือแค่ **ใส่ชื่อไฟล์ แล้วอ่านผล**

---

## 0) เริ่มใน 60 วินาที

```bash
cd CTF-2026                      # root ของ repo
bash install.sh                  # 1) ติดตั้งของที่ขาด (core)
bash scripts/check_tools.sh      #    หรือตรวจเฉย ๆ ว่าครบไหม

python3 scripts/run_pipeline.py challenge.bin    # 2) สั่งงานเดียว — มันเรียกทุกตัวให้
```

ถ้าอยากคุมเองทีละขั้น:

```bash
bash scripts/auto_triage.sh challenge.bin    # ตรวจไฟล์ + รัน tool ที่เกี่ยวกับชนิดนั้น
bash scripts/flag_hunt.sh ./challenge/       # ไล่หา flag ในทุกไฟล์/ทุกชั้น
python3 scripts/crypto_pipeline.py "UTFO{...}"   # ถอดรหัสข้อความ
bash scripts/web_flag.sh http://target:8080  # สแกนเว็บ
```

---

## 1) ตารางเลือกสคริปต์

| สถานการณ์ | ใช้ตัวไหน | ผลลัพธ์ |
|---|---|---|
| ได้ไฟล์มา 1 ไฟล์ ไม่รู้ว่าอะไร | `auto_triage.sh` | ตรวจชนิด + strings + metadata + binwalk + รัน tool ตามชนิด |
| มีโฟลเดอร์เต็มไปด้วยไฟล์ | `flag_hunt.sh` | grep/strings/base64/hex/แตก archive 2 ชั้น |
| ได้ข้อความที่ดูเข้ารหัส | `crypto_pipeline.py` | ถอดซ้อน 3 ชั้น + XOR + จัดอันดับ |
| ได้ URL เว็บ | `web_flag.sh` | header/paths/cookie/JWT + grep flag |
| ไม่อยากเลือกเอง | `run_pipeline.py` | เรียกทุกตัวตามชนิดอัตโนมัติ + รวม flag |
| อยากรู้ว่าเครื่องขาดอะไร | `check_tools.sh` | รายการ tool + คำสั่งติดตั้ง |

---

## 2) `auto_triage.sh` — ตรวจไฟล์เดียวให้ครบ

```bash
bash scripts/auto_triage.sh            # ใช้ค่าในไฟล์ (challenge.bin)
bash scripts/auto_triage.sh file.pdf   # หรือส่ง path มาก็ได้
```

**ทำอะไรตามชนิดไฟล์**

| ชนิด | สิ่งที่รันให้ |
|---|---|
| ทุกไฟล์ | `file`, `md5sum`, `strings` (ASCII + UTF-16), `exiftool`, `binwalk -e` |
| ZIP | `unzip -l` + ลองรหัสว่าง |
| gzip | `gunzip -c` แล้ว `file` ต่อ |
| PNG/BMP | `zsteg -a` |
| JPEG | `steghide` (รหัสว่าง) |
| WAV/MP3 | `sox ... spectrogram` + `multimon-ng -a DTMF` |
| ELF/PE | `checksec`, `readelf`, `upx -l` |
| PDF | `pdftotext`, `pdfid` |
| Office | `olevba` |
| .pyc | `pycdc` |

**ผลลัพธ์**: `output_auto_triage/` — มี `strings.txt`, `exiftool.txt`, `binwalk.txt`, `spectrogram.png`, `_flags_all.txt`

---

## 3) `flag_hunt.sh` — ไล่หาทุกซอกทุกมุม

```bash
bash scripts/flag_hunt.sh                  # สแกนโฟลเดอร์ปัจจุบัน
bash scripts/flag_hunt.sh ./challenge      # เจาะจงโฟลเดอร์
bash scripts/flag_hunt.sh file.bin         # ไฟล์เดียว
```

**ลำดับที่มันทำ**

```
1. grep ตรง ๆ ในทุกไฟล์
2. strings (จับข้อความในไบนารี)
3. base64 ที่ฝังอยู่ → ถอด → grep ซ้ำ
4. hex ที่ฝังอยู่ → ถอด → grep ซ้ำ
5. แตก zip/tar/gz/7z/rar 2 ชั้น แล้ว grep ข้างใน
6. สรุป: แยก "flag มาตรฐาน" กับ "รูปแบบอื่นที่น่าสงสัย"
```

**จุดที่ต่างจาก `grep -r` ธรรมดา**

- จับรูปแบบกว้างกว่า: `[A-Za-z0-9_]{2,16}\{...\}` → เจอ flag ที่ยัง **เข้ารหัส** อยู่ (เช่น `OST_RLNS{...}`)
- ถอด base64/hex ให้ก่อน grep → เจอ flag ที่ซ่อนในข้อมูลเข้ารหัส
- แตกไฟล์บีบอัดให้อัตโนมัติ

**ผลลัพธ์**: `output_flag_hunt/hits.txt` (ทุก hit + มาจากไฟล์ไหน), `_FLAGS.txt`

---

## 4) `crypto_pipeline.py` — ถอดรหัสซ้อนหลายชั้น

```bash
python3 scripts/crypto_pipeline.py                          # ใช้ DATA ในไฟล์
python3 scripts/crypto_pipeline.py "UTFO{qrs_123}"          # ส่งข้อความ
python3 scripts/crypto_pipeline.py cipher.bin               # อ่านจากไฟล์
```

**วิธีที่มันลองให้อัตโนมัติ**

```
base64 · base32 · base58 · hex · rot13 · rot47 · url-decode
caesar (1-25) · atbash · morse · binary (0/1)
+ ถอดซ้อนกันได้ถึง 3 ชั้น (เช่น base64 → base64 → reverse)
+ XOR: 1 ไบต์ทั้ง 256 ค่า, และคีย์ซ้ำโดยใช้เบาะแส CSG_FLAG{
```

**อ่านผลยังไง**

```
2.1) ถอดชั้นที่ 1
  [base64] CSG_FLAG{one_layer}          <- เจอแล้ว จบ
2.2) ถอดชั้นที่ 2
  [rot13] ...
[+] CSG_FLAG{...}                        <- สรุปท้ายสุด
[?] OST_RLNS{Ynk!==...}                  <- รูปแบบอื่น = ยังต้องถอดต่อ
```

**ผลลัพธ์**: `output_crypto_pipeline/results.txt` (ทุก candidate + ลำดับการถอด), `_FLAGS.txt`

---

## 5) `web_flag.sh` — สแกนเว็บแบบไม่ต้องคิด path เอง

```bash
bash scripts/web_flag.sh http://target:8080
```

**สิ่งที่ยิงให้**

```
/robots.txt /sitemap.xml /.well-known/security.txt /.git/HEAD /.env
/admin /login /api /api/v1 /debug /backup.zip /uploads /phpinfo.php
/actuator/env /swagger /server-status /.htaccess /config.php.bak  ...
```

พร้อมกับ:

- เก็บ header ทั้งหมด (ดู `Server`, `X-Powered-By`, `Set-Cookie`)
- ถอด JWT ที่อยู่ในคุกกี้ให้ทันที
- grep `CSG_FLAG{...}` และรูปแบบอื่นในทุก response

**เปิด ffuf เพิ่ม** (ถ้าต้องการ wordlist ใหญ่):

```bash
# แก้บรรทัดในไฟล์
RUN_FFUF="yes"
```

**ผลลัพธ์**: `output_web_flag/pages/` (ทุก response), `found_200.txt`, `cookies.txt`, `jwt.txt`, `_FLAGS.txt`

---

## 6) `run_pipeline.py` — ตัวสั่งงานเดียว

```bash
python3 scripts/run_pipeline.py challenge.bin
python3 scripts/run_pipeline.py ./challenge
python3 scripts/run_pipeline.py http://target:8080
```

**มันทำอะไร**

```
ถ้าเป็น URL      -> web_flag.sh
ถ้าเป็นไฟล์      -> auto_triage.sh -> flag_hunt.sh -> crypto_pipeline.py (กับข้อความที่เจอ)
สุดท้าย          -> กวาดทุก output_*/ หา flag รวมเป็น _ALL_FLAGS.txt
```

ใช้เมื่อ **ขี้เกียจเลือก** หรืออยากได้ภาพรวมเร็ว ๆ ก่อนลงมืออ่านละเอียด

---

## 7) One-liner ที่ใช้บ่อย (คัดลอกไปรันได้เลย)

```bash
# 1) หา flag ทั้งโฟลเดอร์ (เร็วสุด)
grep -a -r -o 'CSG_FLAG{[^}]*}' . | sort -u

# 2) หา flag ใน strings ของทุกไฟล์
find . -type f -exec strings -n 6 {} + 2>/dev/null | grep -o 'CSG_FLAG{[^}]*}' | sort -u

# 3) base64 ซ้อน 3 ชั้น
python3 - <<'PY'
import base64
s = "PUT_BASE64_HERE"
for _ in range(3):
    s = base64.b64decode(s + "===").decode(errors="replace")
    print(s)
PY

# 4) แตก zip ที่ติดรหัส แล้ว crack
zip2john file.zip > h.txt && john --wordlist=/usr/share/wordlists/rockyou.txt h.txt

# 5) ดู spectrogram จากไฟล์เสียง
sox sound.wav -n spectrogram -o spec.png -x 2000 -y 1025 && echo "เปิด spec.png"

# 6) อ่าน QR
zbarimg -q --raw qr.png

# 7) pcap: ดึงไฟล์ที่โหลดผ่าน HTTP
mkdir -p objs && tshark -r cap.pcap --export-objects http,objs -q && ls objs

# 8) JWT: ถอด payload
python3 -c "import base64,json,sys;t=sys.argv[1].split('.')[1];print(json.loads(base64.urlsafe_b64decode(t+'===')))" '<token>'

# 9) หา secret ที่ซ่อนใน .git
git log --all -p | grep -i -E 'csg|flag|password'

# 10) ไฟล์ที่ถูก XOR 1 ไบต์
python3 - <<'PY'
d = open("cipher.bin","rb").read()
best = max(range(256), key=lambda k: sum(32 <= (b ^ k) < 127 for b in d))
print(bytes(b ^ best for b in d)[:200])
PY
```

---

## 8) วิธีเขียนสคริปต์เองให้เป็นแนวเดียวกัน

โครงที่ใช้ซ้ำได้ทุกตัว (คัดลอกไปต่อยอด):

```bash
#!/usr/bin/env bash
TARGET="${1:-challenge.bin}"          # ← แก้บรรทัดเดียว

OUT="output_$(basename "$0" .sh)"     # ← โฟลเดอร์ผลลัพธ์อัตโนมัติ
mkdir -p "$OUT"

need() {                              # ← เช็ก tool ก่อนใช้ + บอกวิธีติดตั้ง
  command -v "$1" >/dev/null 2>&1 && return 0
  echo "[!] ไม่มี $1 — sudo apt install -y ${2:-$1}"; return 1
}

need file && file "$TARGET" | tee "$OUT/file.txt"

grep -a -o -E 'CSG_FLAG\{[^}]*\}' "$OUT"/* 2>/dev/null | sort -u | tee "$OUT/_FLAGS.txt"
```

**หลัก 5 ข้อ**

1. ตัวแปรเดียวที่หัวไฟล์ + รับ `$1` เป็น override
2. `need()` ทุกครั้งก่อนเรียก tool
3. เขียนผลลง `output_<ชื่อสคริปต์>/` เสมอ
4. ปิดท้ายด้วยการ grep flag
5. อย่าอัปโหลดอะไรออกเน็ต

---

## 9) ข้อจำกัดที่ต้องรู้

| ข้อจำกัด | ผลคือ |
|---|---|
| `flag_hunt.sh` จำกัดไฟล์ < 300 MB | ไฟล์ใหญ่ (memory dump) ต้องรัน `strings` เอง |
| แตก archive แค่ 2 ชั้น | ซ้อน 5 ชั้นต้องรันซ้ำ |
| `crypto_pipeline.py` ถอด 3 ชั้น | ซ้อนกว่านั้นให้เพิ่ม `MAX_DEPTH` |
| `xor_crib` รองรับคีย์ ≤ 8 ไบต์ | คีย์ยาวกว่านั้นต้องเขียนเพิ่ม |
| `web_flag.sh` ใช้ path list ในตัว | ถ้าไม่เจอ ให้เปิด `RUN_FFUF="yes"` |
| automation ไม่ "คิด" แทน | มันแค่ทำสิ่งที่เราสั่งให้ครบและเร็วขึ้น |

---

## 10) ความปลอดภัย

- สคริปต์ทั้งหมดทำงานในเครื่อง ไม่ส่งไฟล์ออกเน็ต
- `web_flag.sh` ยิงเฉพาะ URL ที่คุณให้ (เฉพาะเป้าหมายในโจทย์)
- ไม่มีการรันไฟล์ตัวอย่าง (malware) — ใช้ `strings`/`file`/`capa` เท่านั้น
- ถ้าต้องรันไบนารีแปลก ๆ ให้ทำใน VM/WSL แยก
