# CTF Toolkit — ชุดสคริปต์ช่วยทำโจทย์ CTF (CSG2026)

ชุดเครื่องมือสำหรับทำโจทย์ CTF แบบ Jeopardy บน **Kali Linux**
ออกแบบสำหรับคนที่ **อ่านโค้ดไม่เก่ง**: ทุกสคริปต์มีตัวแปรให้แก้ **บรรทัดเดียว** ที่หัวไฟล์
แล้วรันได้เลย

รูปแบบแฟล็กของงานนี้: `CSG_FLAG{...}`
ทุกสคริปต์จะค้นหาแฟล็กให้อัตโนมัติตอนจบ และเก็บผลไว้ในโฟลเดอร์ `output_<ชื่อสคริปต์>/`

---

## 0) ความปลอดภัย (อ่านก่อนใช้)

- สคริปต์ทั้งหมดทำงาน **ในเครื่องคุณเท่านั้น** ไม่มีการอัปโหลดไฟล์ ไม่ส่งไป VirusTotal
  ไม่ส่งไปเว็บถอดรหัสออนไลน์
- `hash_identify.sh` คำนวณ hash ในเครื่อง, `rsa_helper.py` แยกตัวประกอบในเครื่อง
- สิ่งเดียวที่ "ออกเน็ต" คือ `recon.sh` / `dir_bruteforce.sh` ที่ยิงไปยัง **เป้าหมายของโจทย์**
  (ซึ่งเป็นสิ่งที่โจทย์ต้องการให้ทำอยู่แล้ว)
- `image_osint.sh` แค่ **พิมพ์ลิงก์** Google Maps ให้คุณกดเปิดเอง
- ใช้กับเป้าหมายที่อยู่ในขอบเขตของ CTF เท่านั้น

---

## 1) เริ่มใช้งานใน 3 ขั้น

```bash
# ขั้นที่ 1: เข้าไปในโฟลเดอร์ toolkit
cd ~/ctf-toolkit

# ขั้นที่ 2: ให้สิทธิ์รันสคริปต์ทั้งหมด (ทำครั้งเดียว)
chmod +x *.sh */*.sh */*.py

# ขั้นที่ 3: ตรวจว่าเครื่องมีเครื่องมือครบไหม
bash setup.sh
```

ถ้า `setup.sh` บอกว่าขาดอะไร ให้คัดลอกคำสั่ง `sudo apt install ...` ที่มันพิมพ์ให้ไปรัน

---

## 2) วิธีใช้สคริปต์ (แบบสั้นที่สุด)

ทุกสคริปต์ใช้รูปแบบเดียวกัน:

1. เปิดไฟล์ด้วย editor (เช่น `nano forensics/file_triage.sh`)
2. แก้ **บรรทัดแรก ๆ ที่มีเครื่องหมาย `<<<`** เช่น
   ```bash
   FILE="challenge.bin"        # <<< แก้บรรทัดนี้บรรทัดเดียว
   ```
   เปลี่ยนเป็นชื่อไฟล์จริงของโจทย์
3. บันทึก (`Ctrl+O`, `Enter`, `Ctrl+X` ใน nano) แล้วรัน

```bash
bash forensics/file_triage.sh
```

หรือจะ **ไม่แก้ไฟล์** ก็ได้ พิมพ์ชื่อไฟล์ต่อท้ายตอนรันเลย:

```bash
bash forensics/file_triage.sh challenge.bin
```

> ถ้าไม่รู้จะเริ่มตรงไหน ให้ใช้ `triage.sh` — มันดูชนิดไฟล์ให้แล้วเรียกสคริปต์ที่ถูกให้เอง

---

## 3) ตาราง: "โจทย์ให้ไฟล์แบบนี้ -> ใช้สคริปต์นี้"

| โจทย์ให้อะไรมา | สคริปต์ที่ควรรัน | คำสั่ง |
|---|---|---|
| ไม่รู้ว่าไฟล์เป็นอะไร | `triage.sh` | `bash triage.sh ไฟล์` |
| ไฟล์ไบนารี/แปลก ๆ (ทุกชนิด) | `forensics/file_triage.sh` | `bash forensics/file_triage.sh ไฟล์` |
| รูปภาพ (.png .jpg .bmp) | `forensics/stego_image.sh` | `bash forensics/stego_image.sh รูป.png` |
| ไฟล์ .pcap / .pcapng | `forensics/pcap_summary.sh` | `bash forensics/pcap_summary.sh capture.pcap` |
| ไฟล์ memory dump (.raw .mem .vmem) | `forensics/memory_dump.sh` | `bash forensics/memory_dump.sh memory.raw` |
| อิมเมจดิสก์ (.img .dd .E01) | `forensics/disk_image.sh` | `bash forensics/disk_image.sh disk.img` |
| ไฟล์ .evtx (Windows log) | `forensics/windows_logs.sh` | `bash forensics/windows_logs.sh Security.evtx` |
| ไฟล์ .exe .dll (ไม่ต้องรัน) | `malware/static_info.sh` | `bash malware/static_info.sh sample.exe` |
| เอกสาร Office (.doc .docm .xlsm) | `malware/office_macro.sh` | `bash malware/office_macro.sh file.docm` |
| สคริปต์ที่ถูกอำพราง (.ps1 .js .vbs) | `malware/script_deobfuscate.py` | `python3 malware/script_deobfuscate.py script.ps1` |
| ไฟล์ต้องสงสัย + มีกฎ YARA | `malware/yara_scan.sh` | `bash malware/yara_scan.sh sample.bin` |
| URL ของเว็บโจทย์ | `web/recon.sh` | `bash web/recon.sh http://target` |
| ต้องหาหน้าที่ซ่อนในเว็บ | `web/dir_bruteforce.sh` | `bash web/dir_bruteforce.sh http://target` |
| ได้ JWT / คุกกี้มา | `web/cookie_jwt_decode.py` | `python3 web/cookie_jwt_decode.py` |
| ช่องกรอกข้อมูลบนเว็บ (SQLi/XSS/LFI) | `web/sqli_xss_lfi_payloads.txt` | เปิดอ่านแล้วคัดลอก payload |
| ไฟล์โปรแกรม ELF (Linux) | `reverse/bin_info.sh` | `bash reverse/bin_info.sh ./challenge` |
| ต้องดูว่าโปรแกรมทำอะไรตอนรัน | `reverse/dynamic_trace.sh` | `bash reverse/dynamic_trace.sh ./challenge` |
| ต้องไล่ทีละคำสั่งใน gdb | `reverse/gdb_cheatsheet.txt` | เปิดอ่าน |
| ไฟล์ .pyc (Python คอมไพล์แล้ว) | `reverse/python_pyc_decompile.sh` | `bash reverse/python_pyc_decompile.sh file.pyc` |
| รูปถ่าย + ถามสถานที่ | `osint/image_osint.sh` | `bash osint/image_osint.sh photo.jpg` |
| ชื่อคน / ชื่อผู้ใช้ / โดเมน | `osint/username_domain_notes.txt` | เปิดอ่านเป็นเช็กลิสต์ |
| ข้อความที่ถูกเข้ารหัส (base64 ฯลฯ) | `crypto/auto_decode.py` | `python3 crypto/auto_decode.py` |
| ข้อมูลไบต์ที่ถูก XOR | `crypto/xor_bruteforce.py` | `python3 crypto/xor_bruteforce.py` |
| ค่า hash ที่ต้อง crack | `crypto/hash_identify.sh` | `bash crypto/hash_identify.sh` |
| ค่า n, e, c ของ RSA | `crypto/rsa_helper.py` | `python3 crypto/rsa_helper.py` |
| รหัสคลาสสิก (Vigenere ฯลฯ) | `crypto/classic_cipher_notes.txt` | เปิดอ่าน |
| ไฟล์บีบอัดที่ใส่รหัสไว้ | `misc/archive_crack.sh` | `bash misc/archive_crack.sh file.zip` |
| ไม่รู้เลยว่าแฟล็กอยู่ไหน | `misc/find_flag_everywhere.sh` | `bash misc/find_flag_everywhere.sh โฟลเดอร์` |
| รูป QR code / บาร์โค้ด | `misc/qr_barcode_read.sh` | `bash misc/qr_barcode_read.sh qr.png` |
| ไฟล์เสียง (.wav .mp3 .flac) | `misc/audio_spectrogram.sh` | `bash misc/audio_spectrogram.sh sound.wav` |

---

## 4) โครงสร้างโฟลเดอร์

```
ctf-toolkit/
├── README.md              <- ไฟล์นี้
├── setup.sh               <- ตรวจเครื่องมือที่ขาด + บอกคำสั่งติดตั้ง
├── triage.sh              <- ดูชนิดไฟล์ แล้วเรียกสคริปต์ที่เหมาะสมให้
├── forensics/             <- รูปภาพ, pcap, memory, ดิสก์, log
│   ├── file_triage.sh
│   ├── stego_image.sh
│   ├── pcap_summary.sh
│   ├── memory_dump.sh
│   ├── disk_image.sh
│   └── windows_logs.sh
├── malware/               <- ไฟล์ต้องสงสัย, macro, สคริปต์อำพราง
│   ├── static_info.sh
│   ├── office_macro.sh
│   ├── script_deobfuscate.py
│   └── yara_scan.sh
├── web/                   <- เว็บโจทย์
│   ├── recon.sh
│   ├── dir_bruteforce.sh
│   ├── cookie_jwt_decode.py
│   └── sqli_xss_lfi_payloads.txt
├── reverse/               <- ถอดโค้ดโปรแกรม
│   ├── bin_info.sh
│   ├── dynamic_trace.sh
│   ├── gdb_cheatsheet.txt
│   └── python_pyc_decompile.sh
├── osint/                 <- ข้อมูลจากรูป/ชื่อ/โดเมน
│   ├── image_osint.sh
│   └── username_domain_notes.txt
├── crypto/                <- ถอดรหัส, XOR, hash, RSA
│   ├── auto_decode.py
│   ├── xor_bruteforce.py
│   ├── hash_identify.sh
│   ├── rsa_helper.py
│   └── classic_cipher_notes.txt
└── misc/                  <- เบ็ดเตล็ด
    ├── find_flag_everywhere.sh
    ├── archive_crack.sh
    ├── qr_barcode_read.sh
    └── audio_spectrogram.sh
```

---

## 5) สคริปต์ทุกตัวทำอะไร (สรุปสั้น)

### forensics/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `file_triage.sh` | `file`, `exiftool`, `strings`, `binwalk`, `xxd` — รู้จักไฟล์ก่อนลงมือ | `FILE` |
| `stego_image.sh` | `zsteg` + `steghide` (รหัสว่าง) + metadata + ไฟล์ที่ฝังในรูป | `FILE` |
| `pcap_summary.sh` | protocol, คุยกันระหว่างใคร, HTTP object, DNS, รหัสผ่านที่ไม่เข้ารหัส | `FILE` |
| `memory_dump.sh` | Volatility 3: imageinfo, pslist, cmdline, netscan, filescan | `FILE` |
| `disk_image.sh` | `mmls` + `fls` + `tsk_recover` กู้ไฟล์ที่ถูกลบ | `FILE` |
| `windows_logs.sh` | แปลง evtx -> ค้น event 4624/4625/4688/7045 (ถ้ามี chainsaw/hayabusa ก็ใช้) | `FILE` |

### malware/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `static_info.sh` | MD5/SHA256 ในเครื่อง, ชนิดไฟล์, strings, imports/sections ของ PE, entropy | `FILE` |
| `office_macro.sh` | `olevba` + `oledump` ดึงโค้ด VBA ออกมาอ่าน | `FILE` |
| `script_deobfuscate.py` | หา base64/hex/`-enc` ในสคริปต์แล้วถอดให้ | `FILE` |
| `yara_scan.sh` | สแกนด้วยกฎ YARA (ถ้าไม่มีกฎ จะสร้างกฎตัวอย่างให้) | `FILE` |

### web/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `recon.sh` | header, robots.txt, sitemap, path ที่มักลืมปิด, คุกกี้, คอมเมนต์ | `URL` |
| `dir_bruteforce.sh` | ffuf/gobuster หาโฟลเดอร์ซ่อน (เลือก wordlist ให้เอง) | `URL` |
| `cookie_jwt_decode.py` | ถอด JWT 3 ส่วน + บอกจุดอ่อน (alg=none, HS256 อ่อน) | `JWT` |
| `sqli_xss_lfi_payloads.txt` | รวม payload SQLi / XSS / LFI ที่ใช้บ่อย | — |

### reverse/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `bin_info.sh` | `file`, `checksec`, `strings`, `readelf`, `objdump -d` | `FILE` |
| `dynamic_trace.sh` | รันโปรแกรม + `ltrace`/`strace` ดูการเรียกฟังก์ชัน | `FILE` |
| `gdb_cheatsheet.txt` | คำสั่ง gdb/pwndbg ที่ใช้บ่อย อธิบายภาษาไทย | — |
| `python_pyc_decompile.sh` | ลอง `uncompyle6` / `decompyle3` / `pycdc` | `FILE` |

### osint/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `image_osint.sh` | exiftool + แปลง GPS เป็นลิงก์ Google Maps | `FILE` |
| `username_domain_notes.txt` | เช็กลิสต์ OSINT (username/domain/email/รูป) | — |

### crypto/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `auto_decode.py` | base64, base32, base58, hex, rot13, rot47, url, caesar, atbash, morse + ถอดซ้อน 3 ชั้น | `DATA` |
| `xor_bruteforce.py` | XOR 1 ไบต์ทั้ง 256 ค่า + XOR คีย์ซ้ำโดยใช้เบาะแส `CSG_FLAG{` | `DATA` |
| `hash_identify.sh` | ทายชนิด hash + พิมพ์คำสั่ง john/hashcat ให้คัดลอกไปรัน | `HASH` |
| `rsa_helper.py` | small-e, แยกตัวประกอบ (trial/Fermat/Pollard/sympy), Wiener attack | `N`, `E`, `C` |
| `classic_cipher_notes.txt` | วิธีแก้ Vigenere / substitution / rail fence ฯลฯ | — |

### misc/
| สคริปต์ | ทำอะไร | ตัวแปรที่แก้ |
|---|---|---|
| `find_flag_everywhere.sh` | grep + strings + base64 + แตก zip/tar/gz แล้วค้นซ้ำ 3 ชั้น | `TARGET` |
| `archive_crack.sh` | `unzip`/`7z`/`zip2john`+`john`/`fcrackzip` | `FILE` |
| `qr_barcode_read.sh` | `zbarimg` + ถอด base64/hex ที่อยู่ใน QR | `FILE` |
| `audio_spectrogram.sh` | `sox` สร้าง spectrogram + DTMF + เสียงย้อนกลับ | `FILE` |

---

## 6) ตัวอย่างการใช้งานจริง (คัดลอกได้เลย)

### 6.1 เจอไฟล์ชื่อ `challenge.bin` ไม่รู้ว่าคืออะไร

```bash
cd ~/ctf-toolkit
bash triage.sh ~/Downloads/challenge.bin
```

### 6.2 โจทย์ให้รูปมา 1 รูป

```bash
bash forensics/stego_image.sh ~/Downloads/photo.png
# ดูผลใน output_stego_image/
#   - exiftool.txt         เบาะแสใน metadata
#   - zsteg_all.txt        ข้อมูลในบิตของรูป
#   - extracted/           ไฟล์ที่ซ่อนอยู่ในรูป
```

ถ้ายังไม่ออก ลองต่อ:

```bash
bash misc/find_flag_everywhere.sh output_stego_image/extracted
```

### 6.3 โจทย์ให้ข้อความยาว ๆ ที่ดูเหมือน base64

```bash
nano crypto/auto_decode.py        # แก้บรรทัด DATA = "...."
python3 crypto/auto_decode.py
# ดูผลใน output_auto_decode/decoded_results.txt
```

หรือไม่ต้องแก้ไฟล์:

```bash
python3 crypto/auto_decode.py "SGVsbW8gV29ybGQ="
```

### 6.4 โจทย์ให้ไฟล์ .pcap

```bash
bash forensics/pcap_summary.sh capture.pcap
# ไฟล์ที่โหลดผ่าน HTTP จะถูกดึงออกมาที่ output_pcap_summary/http_objects/
```

### 6.5 โจทย์เว็บ

```bash
bash web/recon.sh http://10.10.10.5
bash web/dir_bruteforce.sh http://10.10.10.5
```

### 6.6 โจทย์เสียง

```bash
bash misc/audio_spectrogram.sh secret.wav
# เปิดดู output_audio_spectrogram/spectrogram.png ด้วยตา
```

### 6.7 โจทย์ RSA

```bash
nano crypto/rsa_helper.py     # แก้ N, E, C ด้านบน
python3 crypto/rsa_helper.py
```

---

## 7) ถ้าติดปัญหา

| อาการ | วิธีแก้ |
|---|---|
| `bash: command not found` | คุณอยู่บน Windows — ต้องรันใน Kali/WSL ไม่ใช่ PowerShell |
| `Permission denied` | `chmod +x ชื่อไฟล์.sh` แล้วรันใหม่ |
| `$'\r': command not found` | ไฟล์ถูกแปลงเป็น Windows line ending — รัน `sed -i 's/\r$//' ชื่อไฟล์.sh` |
| `ไม่พบคำสั่ง xxx` | รัน `bash setup.sh` แล้วติดตั้งตามที่มันบอก |
| สคริปต์ค้างนาน | memory dump / disk image ใช้เวลานานปกติ ให้รอ หรือกด `Ctrl+C` |
| ไม่เจอแฟล็ก | ลอง `misc/find_flag_everywhere.sh` กับโฟลเดอร์ผลลัพธ์ทั้งหมด |
| อยากได้ผลละเอียด | เปิดไฟล์ใน `output_<ชื่อสคริปต์>/` — มีข้อมูลดิบครบ |

---

## 8) ลำดับการคิดเมื่อเจอโจทย์ใหม่ ( cheat sheet )

```
1. ไฟล์คืออะไร?            -> bash triage.sh file
2. มีข้อความซ่อนไหม?       -> strings / exiftool / binwalk
3. ข้อความถูกเข้ารหัสไหม?   -> python3 crypto/auto_decode.py
4. ยังไม่ออก?              -> ดูหมวดตามชนิดไฟล์ในตารางข้อ 3
5. ไม่รู้เรื่องเลย?        -> bash misc/find_flag_everywhere.sh .
```

**หลักสำคัญ:** แฟล็กมักไม่ได้ซ่อนลึก — ส่วนใหญ่คือ
`strings` เจอ, metadata มี, หรือ base64 ชั้นเดียว
อย่าข้ามขั้นที่ง่ายที่สุด

---

## 9) เครดิต/หมายเหตุ

- สคริปต์ทั้งหมดเป็น bash/Python ธรรมดา ไม่ต้องติดตั้งอะไรเพิ่มนอกจากเครื่องมือที่ `setup.sh` ตรวจ
- ไม่มีไฟล์ config ภายนอก ทุกอย่างอยู่ในตัวสคริปต์
- ทุกสคริปต์เช็กก่อนใช้ tool ว่าเครื่องมีไหม ถ้าไม่มีจะบอกคำสั่งติดตั้งเป็นภาษาไทย
- ขอให้สนุกกับ CSG2026 🎉


---
# เพิ่มใน v2 (ทดสอบแล้วด้วยข้อมูลจำลองจาก write-up)

| ถ้าเจอแบบนี้ | รันอันนี้ |
|---|---|
| รันสคริปต์อะไรเสร็จแล้ว **อยากสแกนหา flag ให้ครบ** (รวม flag ไม่มี CSG_FLAG นำหน้า, flag ที่ยังเข้ารหัส, base64/hex/rot13) | `python3 misc/flagscan.py output_ชื่อสคริปต์` |
| ข้อความหน้าตา `OST_RLNS{...}` (ตัวอักษรเพี้ยนแต่ { } ยังอยู่) = Vigenere/Caesar | `python3 crypto/vigenere_solver.py` (แก้ DATA) |
| ไฟล์ PHP/สคริปต์ห่อหลายชั้น `eval(gzinflate(base64_decode(...)))` ไฟล์ใหญ่ | `python3 reverse/matryoshka.py` (แก้ FILE) |
| รูป/ไฟล์ที่ขนาดใหญ่ผิดปกติ มี zip ซ่อนท้ายไฟล์ (อาจมีรหัสผ่าน) | `python3 forensics/carve_zip.py` (แก้ FILE) |
| .exe/ELF ที่อ่านโค้ดไม่ได้ section น้อย (3 อัน) ชื่อแปลก (อาจเป็น UPX เปลี่ยนชื่อ) | `python3 reverse/upx_unpack.py` (แก้ FILE) แล้วค่อยใช้ bin_info.sh กับไฟล์ที่แกะ |
| ชิ้นส่วนรูปหลายไฟล์ (จิ๊กซอว์) เหมือนโจทย์ Plato | `python3 forensics/solve_plato_jigsaw.py ไฟล์.jpg` (เฉพาะโจทย์แนวนี้ ต้อง `pip install pillow numpy`) |

## เรื่องสำคัญ: ตอบ flag แบบไม่มี CSG_FLAG
บางโจทย์ (เช่น RFID ได้ `C0DEC0FFEE`, Ramen ได้ `13249397`) ผลที่ได้คือ "ข้างใน" เฉย ๆ
สคริปต์ `auto_decode.py` และ `flagscan.py` จะแสดงรายการ [?] พร้อมบอกว่า "ส่ง CSG_FLAG{...}" ให้
**ตรวจให้ชัดก่อนส่งว่าโจทย์ต้องการแบบไหน (อ่านคำอธิบายโจทย์)**

## สิ่งที่สคริปต์ชุดนี้ "ทำไม่ได้" (ต้องคิดเอง)
OSINT (หาที่ตั้งจากรูป/ค้นเว็บ), reverse ที่ต้องอ่าน assembly/หา key (เช่น ReverseMe หลังแกะ UPX),
.NET backdoor + memory dump (ต้องใช้ dnSpy), bitstream RFID/Manchester, custom crypto
