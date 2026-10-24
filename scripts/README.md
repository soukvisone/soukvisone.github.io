# scripts/ — เครื่องมือไล่หา flag

สคริปต์ทุกตัว **แก้ตัวแปรบรรทัดเดียว** ที่หัวไฟล์ หรือส่ง argument มาก็ได้
ผลลัพธ์ลง `output_<ชื่อสคริปต์>/` เสมอ และปิดท้ายด้วยการค้นหา flag ให้

## เริ่มเร็ว

```bash
bash install.sh                 # จาก root ของ repo (ติดตั้งของที่ขาด)
bash scripts/check_tools.sh     # ตรวจว่าครบไหม

python3 scripts/run_pipeline.py challenge.bin      # สั่งงานเดียว
python3 scripts/run_pipeline.py http://target:8080 # โหมดเว็บ
```

## รายการ

| ไฟล์ | ใช้เมื่อ | ต้องมี |
|---|---|---|
| `check_tools.sh` | ตรวจเครื่องมือก่อนเริ่ม | — |
| `run_pipeline.py` | ไม่อยากเลือกเอง — เรียกทุกตัวตามชนิด | bash, python3 |
| `auto_triage.sh` | ไฟล์เดียว ไม่รู้ว่าอะไร | file, strings, exiftool, binwalk |
| `flag_hunt.sh` | โฟลเดอร์เต็มไปด้วยไฟล์ | grep, strings, base64, xxd, unzip |
| `web_flag.sh` | ได้ URL มา | curl (ffuf ถ้าเปิดใช้) |
| `crypto_pipeline.py` | ข้อความดูถูกเข้ารหัส | python3 |

## ตัวอย่าง

```bash
# 1) ไฟล์ปริศนา
bash scripts/auto_triage.sh challenge.bin

# 2) ทั้งโฟลเดอร์
bash scripts/flag_hunt.sh ./challenge

# 3) ข้อความเข้ารหัส
python3 scripts/crypto_pipeline.py "UTFO{qrs123}"

# 4) เว็บ
bash scripts/web_flag.sh http://10.10.10.5:8080
```

## หลักการเขียนที่ใช้ร่วมกัน

1. ตัวแปรเดียวที่หัวไฟล์ + รับ `$1` เป็น override
2. เช็ก tool ด้วย `command -v` ก่อนใช้ ถ้าขาดบอกวิธีติดตั้งแล้วข้ามขั้นนั้น
3. เขียนผลลง `output_<ชื่อสคริปต์>/`
4. จบด้วยการ grep `CSG_FLAG{...}` และรูปแบบอื่นที่น่าสงสัย
5. ไม่อัปโหลดอะไรออกอินเทอร์เน็ต (ยกเว้น `web_flag.sh` ที่ยิงไปเป้าหมายที่ระบุ)
6. ผ่าน `shellcheck` ทุกไฟล์ (ตรวจด้วย `shellcheck -S warning scripts/*.sh`)
