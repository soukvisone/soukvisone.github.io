# Crypto Cheatsheet — CSG CTF 2026

> ใช้เมื่อ: ได้ข้อความ/ตัวเลข/ไฟล์ที่ดู "ถูกเข้ารหัส" มา แล้วต้องถอดให้เป็น `CSG_FLAG{...}`
> เครื่องมือที่อนุญาต: `python3`, `CyberChef` (เบราว์เซอร์), `openssl`, `RsaCtfTool`, `sage`, `PARI/GP`, `john`, `hashcat`, `hashid`, `xxd`, `base64`
> **ห้าม**: เว็บถอดรหัสออนไลน์ / CrackStation / dCode (อยู่ใน Unapproved List)

---

## 0) ตัดสินใจใน 10 วินาที

```
ข้อความหน้าตาเป็นอะไร ?
├─ A-Za-z0-9+/= ลงท้ายด้วย =            -> base64
├─ A-Z2-7 (ตัวใหญ่ล้วน) + =             -> base32
├─ 0-9a-fA-F ยาวเป็นคู่                -> hex
├─ ตัวเลข 0/1 กลุ่มละ 8                -> binary
├─ .- และ - เท่านั้น                   -> morse
├─ ตัวอักษรล้วน อ่านไม่ออก แต่ความถี่คล้ายภาษา -> Caesar / Vigenere / Substitution
├─ สัญลักษณ์ 33-126 กระจาย            -> ROT47
├─ ตัวเลขก้อนใหญ่ ๆ (n e c)            -> RSA
├─ ค่า hash 32/40/64 ตัวอักษร           -> hash (ไปข้อ 6)
└─ ไฟล์ .txt/.bin ที่เปิดมาเจอไบต์แปลก  -> XOR (ข้อ 5)
```

**ลำดับที่เร็วที่สุด:** โยนใส่ CyberChef ก่อน 1 รอบ (Magic mode) แล้วค่อยลงมือเขียนสคริปต์

---

## 1) CyberChef — ใช้ยังไงให้เร็ว (โหมด Magic)

เปิด `https://gchq.github.io/CyberChef/` (อยู่ใน Approved List)

1. ลาก **Input** มาวางข้อความ
2. คลิก **Magic** (ไอคอนไม้เท้า) → ตั้ง `Intensive mode` = เปิด
3. รอผล — มันจะไล่ base64/hex/rot13/gzip ให้เอง
4. ถ้าเจอ `CSG_FLAG{` ให้กด Copy

> ข้อควรระวัง: CyberChef ทำงานในเบราว์เซอร์ (ไม่ส่งไฟล์ขึ้นเซิร์ฟเวอร์) แต่ถ้าแข่งแบบห้ามเน็ต ให้ใช้คำสั่ง Python ด้านล่างแทน

**สูตรที่ใช้บ่อยใน CyberChef:**

| ต้องทำอะไร | ลาก operation นี้ |
|---|---|
| base64 → ข้อความ | `From Base64` |
| base64 ซ้อนหลายชั้น | `From Base64` ต่อกัน 2-3 อัน |
| hex → ข้อความ | `From Hex` |
| กลับด้านข้อความ | `Reverse` |
| ROT13 | `ROT13` |
| XOR ด้วยคีย์ | `XOR` (ใส่ key เป็น hex) |
| แตก gzip | `Gunzip` |
| ดูว่าเป็นอะไร | `Magic` |

---

## 2) Base64 / Base32 / Hex — คำสั่งในเครื่อง

```bash
# base64 (ชั้นเดียว)
echo 'Q1NHX0ZMQUd7dGVzdH0=' | base64 -d

# base64 ที่ตัด = ออก (ต้องเติมเอง)
echo 'Q1NHX0ZMQUd7dGVzdH0' | base64 -d 2>/dev/null || \
  python3 -c "import base64,sys;print(base64.b64decode(sys.argv[1]+'===').decode())" 'Q1NHX0ZMQUd7dGVzdH0'

# ถอดซ้อน 3 ชั้นแบบรวดเดียว
python3 - <<'PY'
import base64
s = "UTFO4856TFdWN2RHVjBlSFIwYzNSOQ=="
for i in range(3):
    s = base64.b64decode(s).decode(errors="replace")
    print(i + 1, s)
PY

# base32
echo 'IFBEGRCFNZUWC2LPNZSCA===' | base32 -d

# hex
echo '4353475f464c41477b746573747d' | xxd -r -p

# กลับด้านข้อความ (โจทย์ชอบ Reverse ก่อน base64)
echo '}dGVzdHtHQUxfR1ND' | rev | base64 -d 2>/dev/null
```

**จาก writeup 2025 — S3: Hidden in Plain Sight (Stegano)**
โจทย์ให้รูป แล้วเฉลยคือ *"ใช้ decoder ออนไลน์กับรูป แล้วเอาไปเข้า CyberChef ถอด base64 2 ครั้ง + reverse string"*
เวอร์ชันรันในเครื่อง (ไม่ต้องใช้ออนไลน์):

```bash
zsteg -a S3.png | head -40            # หา base64 ที่ซ่อนในบิต
# เจอ string แล้วทำแบบนี้
python3 -c "
import base64
s='<string ที่ได้>'
for _ in range(2):
    s=base64.b64decode(s+'===').decode(errors='replace')
print(s[::-1])
"
```

---

## 3) Caesar / ROT13 / ROT47 / Atbash

```bash
# Caesar ทุก shift (0-25) — ดูอันที่อ่านออก
python3 - <<'PY'
s = "PGS_SYNT{grfg}"
for k in range(26):
    out = "".join(chr((ord(c)-65-k)%26+65) if c.isupper() else
                  chr((ord(c)-97-k)%26+97) if c.islower() else c for c in s)
    if "CSG" in out or "{" in out:
        print(k, out)
PY

# ROT13
echo 'PGS_SYNT{grfg}' | tr 'A-Za-z' 'N-ZA-Mn-za-m'

# ROT47
python3 -c "print(''.join(chr(33+(ord(c)-33+47)%94) for c in 'abc'))"

# Atbash (A<->Z)
echo 'XHT_UOZMG{tivg}' | tr 'A-Za-z' 'ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkjihgfedcba'
```

---

## 4) Vigenère — โจทย์คลาสสิกที่ออกทุกปี

**จาก writeup 2025 — C2: Plato (Crypto)**
โจทย์ให้ `Plato.jpg` → ข้างในมี zip (รหัส `man`) → ได้รูป 12 ชิ้น (4×3) → ต่อเป็นจิ๊กซอว์ → แต่ละชิ้นมีข้อความเข้ารหัส → รวมกันได้:

```
OST_RLNS{Ynk!==Ybg-aeq-shocressglyk-...}
```

จุดสำคัญ: **เบาะแสคือรูปแบบแฟล็ก** `OST_RLNS` มี 8 ตัว เท่ากับ `CSG_FLAG` → เอาไปหาคีย์ได้ทันที
`O→C = -12`, `S→S = 0`, `G→G = 0`, `_` คงเดิม, `R→F = -12`... → คีย์วนซ้ำ `"man"` (ซึ่งก็คือรหัส zip นั่นเอง)

```bash
python3 - <<'PY'
ct  = "OST_RLNS{Ynk!==Ybg-aeq-shocressglyk-drooqqd}"
key = "man"                     # เดาจาก: รหัส zip / คำในโจทย์ / ชื่อไฟล์

out, i = [], 0
for c in ct:
    if c.isalpha():
        b = 65 if c.isupper() else 97
        out.append(chr((ord(c) - b - (ord(key[i % len(key)].upper()) - 65)) % 26 + b))
        i += 1                 # คีย์ขยับเฉพาะตัวอักษร (ข้าม { } _ !)
    else:
        out.append(c)
print("".join(out))
PY
```

**กฎที่ต้องจำ:** Vigenère ขยับคีย์เฉพาะ `isalpha()` — เครื่องหมาย `{`, `}`, `_`, ตัวเลข ไม่กินคีย์
ถ้าขยับผิดจุด ผลจะเพี้ยนตั้งแต่ตัวแรกหลัง `{`

**หาคีย์จากเบาะแสอัตโนมัติ** (เมื่อรู้ว่า plaintext ขึ้นต้นด้วย `CSG_FLAG`):

```bash
python3 - <<'PY'
ct  = "OST_RLNS{...}"
crib = "CSGFLAG"
letters = [c for c in ct if c.isalpha()]
sh = [(ord(letters[i].upper()) - ord(crib[i])) % 26 for i in range(len(crib))]
print("shift ต่อตัวอักษร:", sh)
print("คีย์ (เดา):", "".join(chr(65 + x) for x in sh))
PY
```

---

## 5) XOR — ถ้าไฟล์ดูสุ่ม ให้คิดถึง XOR ก่อน

```bash
# คีย์ 1 ไบต์: ลองทั้ง 256 แล้วหาอันที่อ่านออก
python3 - <<'PY'
data = bytes.fromhex("1b37373331363f78")     # หรือ open("cipher.bin","rb").read()
best = []
for k in range(256):
    out = bytes(b ^ k for b in data)
    score = sum(32 <= c < 127 for c in out) / len(out)
    best.append((score, k, out))
best.sort(reverse=True)
for score, k, out in best[:5]:
    print(f"key=0x{k:02x} ({k:3d}) {score:.2f}  {out[:80]!r}")
PY
```

```bash
# คีย์ซ้ำหลายไบต์ + รู้ว่า plaintext มี CSG_FLAG{ -> เดาคีย์จากตำแหน่งที่พบ
python3 - <<'PY'
data = open("cipher.bin","rb").read()
crib = b"CSG_FLAG{"
for pos in range(len(data) - len(crib) + 1):
    key = bytes(data[pos+i] ^ crib[i] for i in range(len(crib)))
    # ลองคีย์ที่ได้ว่าใช้ทั้งไฟล์แล้วอ่านออกไหม
    out = bytes(data[i] ^ key[i % len(key)] for i in range(len(data)))
    printable = sum(32 <= c < 127 for c in out) / len(out)
    if printable > 0.95:
        print("ตำแหน่ง", pos, "key:", key, out[:80])
PY
```

หรือใช้สคริปต์ในชุดนี้: `python3 scripts/crypto_pipeline.py '<hex หรือข้อความ>'`

---

## 6) Hash — ระบุชนิดแล้ว crack

```bash
# 1) ระบุชนิด
hashid '5f4dcc3b5aa765d61d8327deb882cf99'
hashid -m -j '5f4dcc3b5aa765d61d8327deb882cf99'    # -m = hashcat mode, -j = john format

# 2) crack ด้วย john (wordlist)
echo '5f4dcc3b5aa765d61d8327deb882cf99' > h.txt
john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt h.txt
john --show h.txt

# 3) crack ด้วย hashcat
hashcat -m 0 -a 0 h.txt /usr/share/wordlists/rockyou.txt
hashcat -m 0 h.txt --show
```

**จาก writeup 2025 — C4: Analyze the forgotten password (Crypto)**
เฉลยใช้ **mask attack** เพราะรู้ว่ารหัสเป็นตัวเลขล้วน:

```bash
john --format=raw-md5 --mask=?d?d?d?d?d?d?d?d 8-number.txt   # 8 หลัก
john --format=raw-md5 --mask=?a?a?a?a 4-digit.txt            # 4 ตัวอะไรก็ได้
```

ตาราง mode ที่เจอบ่อย:

| hash | hashcat -m | john --format |
|---|---|---|
| MD5 | 0 | raw-md5 |
| NTLM | 1000 | nt |
| SHA1 | 100 | raw-sha1 |
| SHA256 | 1400 | raw-sha256 |
| SHA512 | 1700 | raw-sha512 |
| bcrypt | 3200 | bcrypt |
| /etc/shadow ($6$) | 1800 | sha512crypt |
| ZIP | 17200 | zip |
| Kerberos AS-REP | 18200 | krb5asrep |

---

## 7) RSA — สูตรที่ออกบ่อย

ได้รับ `n`, `e`, `c` มา → ไล่ตามลำดับนี้

```bash
# 0) ลอง RsaCtfTool ก่อนเลย (ไล่ทุกวิธีให้อัตโนมัติ)
python3 RsaCtfTool.py --publickey pub.pem --uncipherfile cipher.bin
python3 RsaCtfTool.py -n <n> -e <e> --uncipher <c>
```

ถ้าไม่มี RsaCtfTool / อยากเข้าใจเอง:

```bash
# 1) e เล็ก (e=3) + ไม่มี padding -> ถอดรากที่ 3 ตรง ๆ
python3 -c "
import gmpy2
c = <c>
m, exact = gmpy2.iroot(c, 3)
print(exact, int(m).to_bytes(64,'big'))
"

# 2) แยกตัวประกอบ n (p กับ q ใกล้กัน -> Fermat / ตัวเล็ก -> trial division)
python3 - <<'PY'
from math import isqrt
n = <n>
a = isqrt(n)
if a*a < n: a += 1
for _ in range(1000000):
    b2 = a*a - n
    b = isqrt(b2)
    if b*b == b2:
        print("p =", a-b); print("q =", a+b); break
    a += 1
PY

# 3) มี p, q แล้ว -> หา d -> ถอด
python3 - <<'PY'
n, e, c = <n>, <e>, <c>
p, q = <p>, <q>
d = pow(e, -1, (p-1)*(q-1))
m = pow(c, d, n)
print(m.to_bytes((m.bit_length()+7)//8, "big"))
PY
```

**กรณีพิเศษที่เจอบ่อย**

| สภาพโจทย์ | วิธี |
|---|---|
| `e=3` และ `m^3 < n` | ถอดรากที่ 3 ตรง ๆ (small-e) |
| ให้ `n` มาแต่ `p,q` ใกล้กัน | Fermat factorization |
| `d` เล็กมาก | Wiener attack (RsaCtfTool ทำให้) |
| ให้ `n, e, c` 2 ชุด ใช้ `n` เดียวกัน | Common modulus attack |
| ให้ `p` หรือ `q` มาให้เลย | คำนวณ `d` ตรง ๆ |
| `n` ซ้ำกันหลายข้อความ (`e=3`) | Håstad broadcast |

**จาก writeup 2025 — OT1: Decode the RFID Tag (Crypto)**
เป็นการถอดข้อมูล RFID (EM4100) ไม่ใช่ RSA — แต่หลักคิดเดียวกัน: ดูว่าข้อมูลถูกเข้ารหัสด้วยกติกาอะไร แล้วถอดตามกติกานั้น (bits → hex → ASCII)

---

## 8) ไฟล์ที่ต้องถอดหลายชั้น

ถ้าเจอ `.gz` → `.tar` → `.txt` → base64 → ยังไม่ออก

```bash
# แตกซ้อนแบบอัตโนมัติ (สูงสุด 5 ชั้น)
for i in 1 2 3 4 5; do
  file out.bin | grep -q gzip   && gunzip -c out.bin > out2.bin && mv out2.bin out.bin && continue
  file out.bin | grep -q tar    && tar -xf out.bin && continue
  file out.bin | grep -q Zip    && unzip -o out.bin && continue
  break
done
file out.bin
```

หรือใช้ `python3 scripts/crypto_pipeline.py '<ข้อความ>'` (ถอด base64/base32/base58/hex/rot/caesar/atbash/morse ซ้อน 3 ชั้น)

---

## 9) Checklist ก่อนส่ง flag

- [ ] รูปแบบตรงเป๊ะ: `CSG_FLAG{...}` (ตัว C S G ใหญ่ทั้งหมด, มี `_` ระหว่าง CSG กับ FLAG)
- [ ] ไม่มีช่องว่าง/ขึ้นบรรทัดใหม่ติดมา (ใช้ `| tr -d '\n'`)
- [ ] ตัวพิมพ์เล็ก-ใหญ่ถูก (บางโจทย์ flag มีตัวพิมพ์ผสม)
- [ ] ถ้า flag มี `}` อยู่ข้างใน ให้ตัดที่ `}` ตัวสุดท้าย
- [ ] ส่งแล้วไม่ผ่าน → ลองถอดซ้ำอีกชั้น (หลายโจทย์ซ่อน 2 ชั้น)
