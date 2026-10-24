# วิธีเอาขึ้น GitHub Pages (ให้เว็บเปิดได้จริง)

> โฟลเดอร์นี้ **มี `index.html` อยู่ที่ root แล้ว** — ไม่ต้องตั้งค่าโฟลเดอร์เพิ่ม

## 1) อัปโหลด

**วิธี A — ทางเว็บ (ง่ายสุด)**

1. สร้าง repo ใหม่บน GitHub
2. กด **Add file → Upload files**
3. ลาก **ไฟล์และโฟลเดอร์ทั้งหมดที่อยู่ในโฟลเดอร์นี้** ขึ้นไป
   (ไม่ใช่ลากไฟล์ .zip ทั้งก้อน — GitHub ไม่แตก zip ให้)
4. Commit

**วิธี B — ทาง command line**

```bash
cd CTF-2026                 # โฟลเดอร์นี้
git init
git add .
git commit -m "ctf notes"
git branch -M main
git remote add origin https://github.com/<user>/<repo>.git
git push -u origin main
```

## 2) เปิด Pages

```
Settings → Pages
  Source : Deploy from a branch
  Branch : main
  Folder : / (root)          ← ต้องเป็น root เพราะ index.html อยู่ตรงนี้
  Save
```

รอ 1–2 นาที

## 3) URL ที่ถูกต้อง

| ชื่อ repo | URL |
|---|---|
| `soukvisone.github.io` | `https://soukvisone.github.io/` |
| ชื่ออื่น เช่น `notes` | `https://soukvisone.github.io/notes/` |

## ❌ URL ที่ใช้ไม่ได้

```
https://soukvisone.github.io/blob/main/CTF-2026-all-in-one.zip   ← ผิด (นี่คือหน้าดูไฟล์ใน repo)
https://github.com/<user>/<repo>/blob/main/index.html            ← ผิด (หน้าโค้ดบน GitHub)
https://soukvisone.github.io/<repo>/docs/                        ← ผิด (ถ้าตั้ง Pages เป็น / root)
```

## 4) ถ้าเปิดแล้ว 404

| อาการ | สาเหตุ |
|---|---|
| 404 ทั้งเว็บ | ยังไม่เปิด Pages หรือเลือก folder ผิด |
| 404 แต่ repo มีไฟล์ | อัปโหลดเป็น .zip ไม่ได้แตก → ต้องอัปโหลดไฟล์ข้างใน |
| เปิดได้แต่ไม่มีสไตล์ | ไม่ได้อัปโหลดโฟลเดอร์ `assets/` |
| เห็น README แทนเว็บ | ไม่มี `index.html` ที่ root |
| ยังเห็นเวอร์ชันเก่า | รอ ~1 นาที แล้วกด Ctrl+F5 |

## 5) ทดสอบในเครื่องก่อนอัป

เปิดไฟล์ `index.html` ด้วยเบราว์เซอร์ได้เลย (ดับเบิลคลิก)
ทุกอย่างเป็น static — ไม่ต้องมีเซิร์ฟเวอร์ ไม่ต้องต่อเน็ต
