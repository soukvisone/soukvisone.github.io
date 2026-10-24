# CTF-2026 — notes + automation

ชุด cheat sheet (เว็บ static) + สคริปต์ automation สำหรับไล่หา flag
ใช้ได้บน Kali / WSL — ไม่ต้องต่อเน็ตขณะใช้งาน ไม่มีการอัปโหลดไฟล์ออกภายนอก

```
CTF-2026/
├── README.md               ← ไฟล์นี้ (วิธี clone + ใช้งาน)
├── requirements.txt        ← รายการ tool ทั้งหมด (มี comment + ระดับ core/extra)
├── install.sh              ← ติดตั้งของที่ขาดตาม requirements.txt
├── .gitignore
├── scripts/                ← ★ ตัวที่ใช้จริงตอนแข่ง
│   ├── README.md
│   ├── check_tools.sh          ตรวจว่ามี tool ครบไหม
│   ├── run_pipeline.py         สั่งงานเดียว: เรียกทุกตัวให้ตามชนิดเป้าหมาย
│   ├── auto_triage.sh          ไฟล์เดียว → ตรวจทุกอย่างที่เกี่ยวข้อง
│   ├── flag_hunt.sh            โฟลเดอร์/ไฟล์ → grep/strings/base64/hex/archive
│   ├── web_flag.sh             URL → recon + path + cookie/JWT + grep flag
│   └── crypto_pipeline.py      ข้อความ → ถอดซ้อน 3 ชั้น + XOR
├── docs/                   ← เว็บ (เปิดอ่านได้ ไม่ต้อง build)
    ├── index.html              หน้าแรก + ค้นหา
    ├── tools.html              Tools Index
    ├── build.py                แก้ .md แล้วรันใหม่
    ├── assets/                 site.css, site.js
    └── Crypto/ Forensics/ Web/ Reverse/ OSINT/ Misc/ Automation/
└── extra/                  ← ชุดสคริปต์รุ่นก่อน (สำรอง — ดู extra/README.md)
    ├── ctf-toolkit/            รุ่น 1: 32 สคริปต์ แยก 7 หมวด
    └── ctf-toolkit-v2/         รุ่น 2: + สคริปต์เฉพาะทาง (vigenère/zip/UPX/…) 
```

> `docs/index.html` เป็นของแถม (อ่านบน GitHub Pages หรือเปิดในเครื่อง)
> ถ้าเอาไว้ใช้ตอนแข่งอย่างเดียว สนใจแค่ `scripts/` ก็พอ

---

## 1) Clone แล้วใช้ใน 3 คำสั่ง

```bash
git clone <repo-url> CTF-2026 && cd CTF-2026
chmod +x install.sh scripts/*.sh      # ครั้งเดียวหลัง clone (git/zip ไม่เก็บ +x)
bash install.sh                       # ติดตั้งของที่ขาด (core)
bash scripts/check_tools.sh           # ตรวจซ้ำว่าครบ
```

ถ้าต้องการใช้ของในเอกสารทั้งหมด (jadx, volatility3, floss, …):

```bash
bash install.sh --all
```

ติดตั้งเฉพาะบางอย่างไม่ได้ผ่าน `install.sh` (pycdc, RsaCtfTool, sage, chainsaw, hayabusa)
→ ดูหมายเหตุท้าย `requirements.txt`

---

## 2) เริ่มใช้งาน

```bash
# ไม่รู้จะเริ่มตรงไหน — ให้ pipeline ตัดสินใจให้
python3 scripts/run_pipeline.py challenge.bin
python3 scripts/run_pipeline.py http://10.10.10.5:8080

# หรือเรียกทีละตัว
bash scripts/auto_triage.sh challenge.bin      # ไฟล์เดียว
bash scripts/flag_hunt.sh ./challenge          # ทั้งโฟลเดอร์
python3 scripts/crypto_pipeline.py "UTFO{qrs}" # ข้อความ
bash scripts/web_flag.sh http://target         # เว็บ
```

ผลลัพธ์ทุกตัวอยู่ใน `output_<ชื่อสคริปต์>/` และมี `_FLAGS.txt` เมื่อเจอ

**ทุกสคริปต์แก้ได้ที่ตัวแปรบรรทัดเดียว** (หรือส่ง argument):

```bash
FILE="challenge.bin"      # ← แก้ตรงนี้
TARGET="."                # flag_hunt.sh
URL="http://target"       # web_flag.sh
DATA="..."                # crypto_pipeline.py
```

---

## 3) เอกสาร (เว็บ)

เปิดในเครื่อง:

```bash
xdg-open docs/index.html        # Linux
start docs\index.html           # Windows
```

หรืออัปขึ้น GitHub Pages:

```
Settings → Pages → Source: Deploy from a branch
Branch: main    Folder: /docs
→ https://<user>.github.io/<repo>/
```

แก้เนื้อหา:

```bash
nano docs/Crypto/crypto_cheatsheet.md
python3 docs/build.py            # สร้าง .html ใหม่ทั้งชุด
```

---

## 4) สิ่งที่อยู่ใน docs/

| หมวด | มีอะไร |
|---|---|
| Crypto | base64/hex/rot, Vigenère (เคส Plato), XOR, hash, RSA |
| Forensics | file signatures, binwalk/carving, strings, metadata |
| Web | ลำดับคิด, payloads (SQLi/XSS/LFI/SSTI/XXE/SSRF/JWT), commands |
| Reverse | แยกตามชนิดไฟล์ (ELF/PE/.NET/APK/.pyc/PHP/Go), commands |
| OSINT | รูป/ชื่อ/โดเมน/อีเมล/git |
| Misc | QR, เสียง/spectrogram, SQLite, evtx, pcap |
| Automation | คู่มือสคริปต์ทั้งหมด + one-liner recipes |

---

## 5) ปัญหาที่เจอบ่อย

| อาการ | วิธีแก้ |
|---|---|
| `bash: command not found` | อยู่บน Windows → ใช้ WSL หรือ Kali |
| `Permission denied` | `chmod +x scripts/*.sh install.sh` |
| `$'\r': command not found` | ไฟล์ถูกแปลง CRLF → `sed -i 's/\r$//' scripts/*.sh` |
| `[ขาด] xxx` หลังติดตั้ง | อ่านหมายเหตุท้าย `requirements.txt` (บางตัวต้องโหลดเอง) |
| สคริปต์ค้างนาน | memory dump / disk image ใช้เวลานานปกติ |
| ไม่เจอ flag | `bash scripts/flag_hunt.sh .` แล้วอ่าน `output_flag_hunt/hits.txt` |
| เปิดเว็บแล้วสไตล์ไม่ขึ้น | เปิดจากโฟลเดอร์ `docs/` ทั้งโฟลเดอร์ (ต้องมี `assets/` อยู่ข้าง ๆ) |

---

## 6) กติกาที่ออกแบบไว้

- ทำงานในเครื่องเท่านั้น (ยกเว้น `web_flag.sh` ที่ยิงไปเป้าหมายที่ระบุ)
- ใช้เฉพาะเครื่องมือที่อยู่ในรายการที่อนุญาตของสนาม (ไม่มี IDA Free / dirsearch / PEiD / บริการออนไลน์)
- ไม่รันไฟล์ตัวอย่างอันตราย — ใช้ `file`/`strings`/`capa` อ่านเท่านั้น
- สคริปต์ทุกตัวผ่าน `shellcheck -S warning`
