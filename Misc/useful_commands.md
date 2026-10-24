# Misc — Useful Commands (รวมคำสั่งที่ใช้บ่อยนอกหมวดอื่น)

> ใช้เมื่อ: โจทย์ไม่เข้าหมวดไหนเลย (ไฟล์แปลก, เสียง, QR, ฐานข้อมูล, log, การจัดการไฟล์)
> เครื่องมือ: `file`, `strings`, `binwalk`, `zbarimg`, `sox`, `ffmpeg`, `multimon-ng`, `sqlite3`, `jq`, `git`, `ImageMagick`, `7z`, `unzip`, `steghide`, `stegseek`, `stegsolve`, `OpenStego`, `stegsnow`

---

## 1) ไล่หา flag ทั้งเครื่อง/ทั้งโฟลเดอร์

```bash
# grep ตรง ๆ (รวมไฟล์ไบนารี)
grep -a -r -o 'CSG_FLAG{[^}]*}' . 2>/dev/null | sort -u

# ripgrep (เร็วกว่า)
rg -a -o 'CSG_FLAG\{[^}]*\}' . | sort -u

# ใน strings ของทุกไฟล์
find . -type f -exec strings -n 6 {} + 2>/dev/null | grep -o 'CSG_FLAG{[^}]*}' | sort -u

# ในไฟล์ที่ถูก base64
for f in $(find . -type f); do
  strings -n 20 "$f" | grep -E '^[A-Za-z0-9+/]{20,}={0,2}$' | while read -r b; do
    printf '%s' "$b" | base64 -d 2>/dev/null | grep -q 'CSG_FLAG' && echo "[$f] $b"
  done
done
```

สคริปต์สำเร็จรูป: `bash scripts/flag_hunt.sh .`

---

## 2) QR code / บาร์โค้ด

```bash
zbarimg qr.png                    # อ่านทั้งหมด
zbarimg -q --raw qr.png           # เอาแค่ข้อความ
zbarimg -q --raw *.png            # หลายไฟล์

# ถ้าอ่านไม่ได้ ให้ขยายก่อน
convert qr.png -resize 400% qr_big.png && zbarimg -q --raw qr_big.png

# ถ้าเป็น QR ที่ถูกแบ่ง/บิด
convert qr.png -rotate 90 qr_r90.png && zbarimg -q --raw qr_r90.png
```

> เนื้อหาใน QR มักเป็น base64/hex อีกชั้น → `echo '<ข้อความ>' | base64 -d`

---

## 3) ไฟล์เสียง — หา spectrogram / DTMF / SSTV

### 3.1 สร้าง spectrogram (เทคนิคที่ออกบ่อยสุด)

```bash
sox sound.wav -n spectrogram -o spec.png -x 2000 -y 1025
sox sound.wav -n spectrogram -o spec_wide.png -x 4000 -y 513
sox sound.wav -n spectrogram -o spec_tall.png -x 1200 -y 2049 -z 120
```

เปิด `spec.png` ดูด้วยตา — ข้อความมักเขียนด้วยคลื่นเสียง

**จาก writeup 2025 — LINE to PLAIN / Cat Tail (Stegano)**
โจทย์แนวเสียงจะซ่อนข้อความใน spectrogram หรือซ่อนเป็น LSB ของไฟล์ wav

```bash
# ดู LSB ของ wav
python3 - <<'PY'
import wave
w = wave.open("sound.wav")
data = w.readframes(w.getnframes())
bits = "".join(str(b & 1) for b in data[:8000])
print("".join(chr(int(bits[i:i+8], 2)) for i in range(0, len(bits), 8)))
PY
```

### 3.2 DTMF (เสียงกดปุ่มโทรศัพท์)

```bash
multimon-ng -t wav -a DTMF sound.wav
# ได้ตัวเลข -> อาจเป็นรหัสผ่านของไฟล์อื่น
```

### 3.3 SSTV (ภาพที่ส่งทางวิทยุ — โจทย์สาย OT/radio)

```bash
# เปิด GUI
qsstv
# หรือ decode ด้วย command line
sstv -d sound.wav -o out.png
```

### 3.4 ฟังย้อนกลับ / เร่งความเร็ว / เปลี่ยนความถี่

```bash
sox sound.wav reversed.wav reverse
sox sound.wav fast.wav speed 2.0
sox sound.wav slow.wav speed 0.5
sox sound.wav shifted.wav pitch 400
```

### 3.5 ข้อมูลเสียงพื้นฐาน

```bash
sox --i sound.wav
ffprobe sound.mp3
mediainfo sound.mp3
```

---

## 4) รูปภาพ — ต่อจิ๊กซอว์ / รวมภาพ

**จาก writeup 2025 — C2: Plato (Crypto)** มีรูป 12 ชิ้น (4×3) ต้องต่อเป็นภาพเดียว

```bash
# ต่อเป็นแถว (แนวนอน)
convert tile1.jpg tile2.jpg tile3.jpg tile4.jpg +append row1.png

# ต่อแนวตั้ง
convert row1.png row2.png row3.png -append full.png

# หรือทำทีเดียวทั้ง 12 (สมมติชื่อ 01.jpg ... 12.jpg เรียงถูกแล้ว)
montage 01.jpg 02.jpg 03.jpg 04.jpg 05.jpg 06.jpg \
        07.jpg 08.jpg 09.jpg 10.jpg 11.jpg 12.jpg \
        -tile 4x3 -geometry +0+0 full.png
```

ถ้าต้องเรียงเอง ให้ใช้ `montage -tile 4x3` แล้วสลับชื่อไฟล์ตามลำดับที่ถูก

```bash
# ดูขนาดรูปทั้งหมด (ต้องเท่ากันก่อนต่อ)
identify *.jpg | awk '{print $3}' | sort | uniq -c
```

---

## 5) Steganography ในรูป — คำสั่งครบชุด

```bash
# zsteg (PNG/BMP)
zsteg -a image.png | head -40
zsteg -E 'b1,rgb,lsb,xy' image.png > lsb.bin     # ดึงบิตออกมา

# steghide (JPEG/BMP/WAV)
steghide info image.jpg
steghide extract -sf image.jpg -p ''             # รหัสว่าง
steghide extract -sf image.jpg -p 'password' -f

# stegseek (ไล่รหัส steghide ด้วย wordlist — เร็วมาก)
stegseek image.jpg /usr/share/wordlists/rockyou.txt

# OpenStego (GUI/CLI)
openstego extract -sf image.png -xd out/

# stegsnow (ข้อความในช่องว่างของ text)
stegsnow -C secret.txt

# StegSolve (GUI) — ไล่ดู bit plane ด้วยตา
stegsolve
```

**LSB ด้วย Python (เมื่อ tool ไม่พอ):**

```python
from PIL import Image
img = Image.open("image.png").convert("RGB")
bits = [str(p[i] & 1) for p in img.getdata() for i in range(3)]
s = "".join(chr(int("".join(bits[i:i+8]), 2)) for i in range(0, len(bits) - 8, 8))
print(s[:500])
```

---

## 6) ฐานข้อมูล SQLite

```bash
file data.db
sqlite3 data.db ".tables"
sqlite3 data.db ".schema"
sqlite3 data.db "SELECT * FROM users LIMIT 10;"
sqlite3 data.db ".dump" | grep -i csg
sqlite3 data.db "SELECT name FROM sqlite_master WHERE type='table';"
```

ถ้าไฟล์เสีย/ถูกลบ → `fqlite` (กู้ record ที่ถูกลบ)

```bash
fqlite data.db
```

---

## 7) Log / Event (Windows)

```bash
# evtx -> ข้อความ
chainsaw dump Security.evtx > sec.txt
hayabusa csv-timber -f Security.evtx -o out.csv --no-wizard

# ค้น event ที่สำคัญ
grep -E '4624|4625|4688|7045|1102|4720' sec.txt | head -30
```

ความหมาย Event ID ที่ต้องจำ:

| ID | หมายถึง |
|---|---|
| 4624 | login สำเร็จ |
| 4625 | login ผิด |
| 4672 | ให้สิทธิ์ admin |
| 4688 | มีการรันโปรเซส (มี command line) |
| 4720 | สร้าง user ใหม่ |
| 7045 | ติดตั้ง service ใหม่ |
| 1102 | ล้าง log (น่าสงสัยสุด) |

---

## 8) pcap แบบเร็ว (ไม่ต้องเปิด Wireshark)

```bash
tshark -r capture.pcap -q -z io,phs                  # protocol ทั้งหมด
tshark -r capture.pcap -q -z conv,tcp                # ใครคุยกับใคร
tshark -r capture.pcap -Y http.request -T fields \
       -e http.host -e http.request.uri              # URL ที่ถูกขอ
tshark -r capture.pcap -Y dns -T fields -e dns.qry.name | sort -u
tshark -r capture.pcap --export-objects http,out/ -q # ดึงไฟล์ที่โหลด
tshark -r capture.pcap -Y 'frame contains "CSG_FLAG"' -T fields -e frame.number
```

**จาก writeup 2025 — N2: Silent Call / N3: Silent Signals**
โจทย์แนว VoIP/RTP: ดึงเสียงออกมาจาก pcap แล้วฟัง/ทำ spectrogram

```bash
tshark -r call.pcap -Y rtp -T fields -e rtp.payload > rtp.hex
# หรือใช้ rtptools
rtpdump -F payload -f call.pcap > audio.raw
```

---

## 9) ข้อความ/เข้ารหัสพื้นฐานในเชลล์

```bash
echo 'SGVsbG8=' | base64 -d
echo -n 'Hello' | base64
echo '48656c6c6f' | xxd -r -p
echo -n 'Hello' | xxd -p
echo 'uryyb' | tr 'A-Za-z' 'N-ZA-Mn-za-m'          # rot13
rev <<< 'olleh'                                     # กลับด้าน
printf '%b' '\x43\x53\x47'                          # \x escape
python3 -c "print(ord('C'), hex(ord('C')), bin(ord('C')))"
```

---

## 10) JSON / jq

```bash
curl -s http://target/api | jq
curl -s http://target/api | jq '.users[] | .name'
cat data.json | jq -r '.. | strings' | grep -i csg
```

---

## 11) ไฟล์บีบอัด (สรุปเร็ว)

```bash
unzip -l file.zip           # ดูข้างใน
unzip -P 'pass' file.zip    # แตกด้วยรหัส
7z x file.7z -oout/         # 7z
tar -tvf file.tar           # ดูข้างใน tar
tar -xf file.tar -C out/    # แตก tar
gunzip -c file.gz > out     # gz
```

รายละเอียดการ crack รหัส → `../Forensics/binwalk_commands.md`

---

## 12) เคล็ดลับการทำงาน

```bash
# ทำงานในโฟลเดอร์แยก ไม่ให้รก
mkdir -p work && cd work

# บันทึกทุกอย่างที่ทำ
script -a session.log

# ดูขนาดไฟล์ทั้งหมดเรียงจากใหญ่
du -ah . | sort -rh | head -20

# หาไฟล์ที่เพิ่งถูกแก้ (อาจเป็นไฟล์ที่โจทย์เพิ่งสร้าง)
find . -type f -newermt '-1 hour'

# คัดลอกไฟล์ผ่าน HTTP (ส่งออกจากเครื่องเป้าหมาย)
python3 -m http.server 8000
wget http://YOUR_IP:8000/file
```

---

## 13) ตาราง "โจทย์ให้อะไร → ใช้คำสั่งไหน"

| โจทย์ให้ | เริ่มที่ |
|---|---|
| รูป QR | `zbarimg -q --raw qr.png` |
| ไฟล์เสียง | `sox ... spectrogram` + `multimon-ng -a DTMF` |
| รูปหลายชิ้น | `montage -tile 4x3` |
| รูปปกติ | `zsteg -a` + `steghide` + `stegseek` |
| ไฟล์ .db | `sqlite3` + `fqlite` |
| ไฟล์ .evtx | `chainsaw dump` |
| ไฟล์ .pcap | `tshark -z io,phs` แล้วค่อยเจาะ |
| ข้อความยาว ๆ | `base64 -d` / `../Crypto/crypto_cheatsheet.md` |
| ไม่รู้อะไรเลย | `grep -a -r -o 'CSG_FLAG{[^}]*}' .` |

---

## 14) กฎความปลอดภัย

- อย่ารันไฟล์ที่สงสัยว่าเป็นมัลแวร์บนเครื่องตัวเอง — ใช้ `strings`/`capa`/sandbox แทน
- อย่าอัปโหลดไฟล์โจทย์ขึ้นบริการออนไลน์ (ผิดกติกา)
- ถ้าต้องรัน binary แปลก ๆ ให้รันใน VM/WSL ที่แยกออกมา
