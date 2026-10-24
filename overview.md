# ภาพรวมทั้งหมด

> cheat sheet + คำสั่งพร้อมรัน + automation สำหรับไล่หา flag
> ทุกหน้าอยู่ในเครื่อง เปิดได้แบบ offline (ไม่ต้องต่อเน็ต)

---

## 1) เริ่มตรงไหน

| เวลา | ทำอะไร |
|---|---|
| **30 วินาที** | `cd Automation && python3 run_pipeline.py <ไฟล์>` — ให้มันไล่หาให้ก่อน |
| **5 นาที** | เปิดตารางข้อ 3 ด้านล่าง แล้วเลือกหน้าให้ตรงกับสิ่งที่โจทย์ให้มา |
| **ก่อนแข่ง** | `bash install.sh` ติดตั้งของที่ขาด |
| **อ่านลึก** | เปิดหมวดซ้ายมือ (Crypto / Forensics / Web / Reverse / OSINT / Misc) |

---

## 2) ตาราง: ได้อะไรมา → เปิดหน้าไหน

| โจทย์ให้ | หน้า | คำสั่งแรก |
|---|---|---|
| ไฟล์ไม่รู้ชนิด | [File Signatures](Forensics/file_signatures.md) | `file` + `xxd -l 64` |
| รูปภาพ | [Metadata](Forensics/metadata.md) | `exiftool -a -u -g1` |
| ไฟล์ที่มีอะไรซ่อนอยู่ | [binwalk & Carving](Forensics/binwalk_commands.md) | `binwalk -e` |
| ไฟล์ไบนารี | [strings](Forensics/strings_commands.md) | `strings -n 6 \| grep -i csg` |
| ข้อความเข้ารหัส | [Crypto Cheatsheet](Crypto/crypto_cheatsheet.md) | CyberChef Magic / `crypto_pipeline.py` |
| n, e, c (RSA) | [Crypto Cheatsheet](Crypto/crypto_cheatsheet.md) | `RsaCtfTool` |
| ค่า hash | [Crypto Cheatsheet](Crypto/crypto_cheatsheet.md) | `hashid` → `john` |
| URL เว็บ | [Web Cheatsheet](Web/web_cheatsheet.md) | `curl -i` |
| ช่องกรอกบนเว็บ | [Common Payloads](Web/common_payloads.md) | ดูชนิดช่องโหว่ |
| ต้องยิงคำสั่งเว็บเยอะ | [Web Commands](Web/commands.md) | `ffuf` |
| .exe / ELF / .pyc / .apk | [Reversing Notes](Reverse/reversing_notes.md) | `file` → `strings` → `ltrace` |
| ต้องใช้ gdb/ghidra | [Reverse Commands](Reverse/common_commands.md) | ตารางท้ายหน้า |
| รูป/ชื่อ/โดเมน | [OSINT Methodology](OSINT/methodology.md) | `exiftool` → `git log` |
| เสียง/QR/DB/log | [Useful Commands](Misc/useful_commands.md) | ตารางข้อ 13 |
| อยากให้สคริปต์ไล่หาให้ | [Automation](Automation/automation_guide.md) | `python3 scripts/run_pipeline.py <target>` |

---

## 3) กฎ 5 ข้อของสนาม (จากรายการ tools ที่อนุญาต)

1. **ห้ามใช้บริการออนไลน์วิเคราะห์ไฟล์** — VirusTotal, CrackStation, dCode, online decompiler อยู่ในรายการที่ไม่อนุมัติ
2. **ห้ามใช้ AI/ML library** — Python เพิ่มไลบรารีได้ แต่ห้ามพวก LLM / ML framework
3. **เครื่องมือที่ถูกตัดออก** — IDA Free, PEiD, dirsearch, stegdetect (ใช้ Ghidra/r2, DIE, ffuf, zsteg แทน)
4. **ใช้ได้ทั้ง Windows และ Kali** — Windows มี CyberChef/HxD/Wireshark/x64dbg/dnSpy/Autopsy, Kali มี tool ครบกว่า
5. **tool อาจไม่ครบตามที่ขอ** — มี Plan B ทุกครั้ง (ไม่มี r2 → ใช้ objdump; ไม่มี chainsaw → evtx_dump)

---

## 4) โครงสร้าง

```
docs/                        เว็บชุดนี้ (เปิด index.html ได้เลย)
├── index.html               หน้าแรก + ค้นหา
├── tools.html               Tools Index — tool ทุกตัว → หน้าที่ใช้
├── assets/                  site.css, site.js (ไม่ใช้ CDN)
├── build.py                 สร้าง .html จาก .md
├── Automation/              คู่มือสคริปต์ + one-liner recipes
├── Crypto/                  base64 → Vigenère → XOR → hash → RSA
├── Forensics/               file signatures · binwalk · strings · metadata
├── Web/                     cheatsheet · payloads · commands
├── Reverse/                 notes · commands
├── OSINT/                   methodology
└── Misc/                    useful commands

scripts/                     ตัวที่ใช้จริงตอนแข่ง (ดู scripts/README.md)
├── check_tools.sh           ตรวจ tool ที่ขาด
├── run_pipeline.py          สั่งงานเดียว
├── auto_triage.sh           ไฟล์เดียว
├── flag_hunt.sh             ทั้งโฟลเดอร์
├── web_flag.sh              เว็บ
└── crypto_pipeline.py       ถอดรหัส

requirements.txt             รายการ tool + comment (core/extra)
install.sh                   ติดตั้งตาม requirements.txt
```

---

## 5) เทคนิคจากโจทย์จริงที่อ้างถึงในเอกสาร

| โจทย์ | หมวด | เทคนิค |
|---|---|---|
| C2 Plato | Crypto | zip ซ่อนใน jpg + จิ๊กซอว์ 4×3 + Vigenère (คีย์จาก crib) |
| C4 forgotten password | Crypto | john `--mask` สำหรับรหัสตัวเลข |
| OT1 RFID | Crypto | ถอดบิต EM4100 ตามกติกา |
| S2 Cutest Cat | Stegano | exiftool → รหัสใน UserComment → unzip |
| S3 Hidden in Plain Sight | Stegano | stego decoder + base64 ×2 + reverse |
| Cat Tail | Stegano | LSB ช่องฟ้า + metadata + ท้ายไฟล์ |
| O1 Japan / geoguess | OSINT | อ่านป้าย/ภาษา/พืช + แผนที่ |
| OSINT github | OSINT | `git log`, `git show -s --format='%ae'` |
| SMB3overKerberos | Network | impacket AS-REP → hashcat |
| N1 Man in the flag | Network | replay S3 request พร้อม header SSE-C |
| Packer | Reversing | `upx -d` |
| Hunt4C2 | Reversing | YARA + capa |
| matryoshka | Reversing | ถอด eval(gzinflate(base64)) หลายชั้น |
| corrupted | Reversing | ซ่อม header ไฟล์ |
| memory forensics | Forensics | `strings dump \| grep SECRET` → TLS key |

---

## 6) แก้เนื้อหายังไง

```bash
# 1) แก้ไฟล์ .md ที่ต้องการ
nano docs/Crypto/crypto_cheatsheet.md

# 2) สร้าง html ใหม่
python3 docs/build.py

# 3) เปิดดู
xdg-open docs/index.html
```
