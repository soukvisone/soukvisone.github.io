#!/usr/bin/env python3
# ==========================================================================
#  build.py — สร้างเว็บ static จากไฟล์ .md (ไม่ต้องใช้ framework อะไร)
#  วิธีใช้:   python3 build.py
#  ผลลัพธ์:  index.html, tools.html และ .html ของทุกหน้า (วางข้างไฟล์ .md)
#  หมายเหตุ: ไฟล์ .md ยังเป็นต้นฉบับ แก้ .md แล้วรัน build.py ใหม่
# ==========================================================================

import html
import re
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent

SITE_TITLE = "Personal Notes"
SITE_SUB = "Cheat sheets · Automation · Tools"

# ---------- โครงเว็บ ----------
# แต่ละหน้า: ไฟล์ .md, ชื่อ, คำอธิบายสั้น, tool ที่ใช้, คำค้น
CATS = [
    {
        "name": "เริ่มต้น",
        "icon": "📌",
        "pages": [
            {"file": "README.md", "title": "ภาพรวมทั้งหมด",
             "sub": "ตาราง “ได้อะไรมา → เปิดหน้าไหน” + กฎการใช้ tools",
             "tools": [], "tags": ["overview", "index", "ตาราง"]},
        ],
    },
    {
        "name": "Automation",
        "icon": "🚀",
        "pages": [
            {"file": "Automation/automation_guide.md",
             "title": "Automation — หา Flag ด้วยคำสั่งเดียว",
             "sub": "สคริปต์ pipeline 6 ตัว: triage, flag hunt, web, crypto, orchestrator",
             "tools": ["bash", "python3", "ffuf", "strings", "binwalk", "jq"],
             "tags": ["automation", "pipeline", "one-command", "script"]},
        ],
    },
    {
        "name": "Crypto",
        "icon": "🔐",
        "pages": [
            {"file": "Crypto/crypto_cheatsheet.md",
             "title": "Crypto Cheatsheet",
             "sub": "base64 → Vigenère → XOR → hash → RSA (สูตรครบพร้อมเคสจริง)",
             "tools": ["CyberChef", "python3", "openssl", "RsaCtfTool", "john", "hashcat", "hashid", "sage"],
             "tags": ["base64", "hex", "vigenere", "xor", "rsa", "hash"]},
        ],
    },
    {
        "name": "Forensics",
        "icon": "🧪",
        "pages": [
            {"file": "Forensics/file_signatures.md",
             "title": "File Signatures",
             "sub": "magic bytes 20 ชนิด + ซ่อมไฟล์เสีย + ของที่ซ่อนท้ายไฟล์",
             "tools": ["file", "xxd", "hexdump", "pngcheck", "HxD"],
             "tags": ["magic bytes", "header", "corrupted", "polyglot"]},
            {"file": "Forensics/binwalk_commands.md",
             "title": "binwalk & Carving",
             "sub": "หาไฟล์ซ่อนในไฟล์ + แตก zip/7z ที่ล็อกรหัส",
             "tools": ["binwalk", "foremost", "testdisk", "dd", "unzip", "7z", "bkcrack", "fcrackzip", "john"],
             "tags": ["carving", "zip", "password", "extract"]},
            {"file": "Forensics/strings_commands.md",
             "title": "strings",
             "sub": "ขุดข้อความในไบนารี: UTF-16, base64 ในไฟล์, FLOSS, ripgrep",
             "tools": ["strings", "FLOSS", "ripgrep", "xxd"],
             "tags": ["strings", "utf-16", "grep", "memory dump"]},
            {"file": "Forensics/metadata.md",
             "title": "Metadata",
             "sub": "exiftool / PDF / Office / git — จุดที่คนลืมและมักซ่อนรหัส",
             "tools": ["exiftool", "pdfid", "pdf-parser", "mutool", "qpdf", "pdftotext", "olemeta", "olevba", "git"],
             "tags": ["exif", "gps", "pdf", "office", "git"]},
        ],
    },
    {
        "name": "Web",
        "icon": "🌐",
        "pages": [
            {"file": "Web/web_cheatsheet.md",
             "title": "Web Cheatsheet",
             "sub": "ลำดับคิด 8 ขั้น + ชนิดช่องโหว่ + เคสจาก writeup",
             "tools": ["curl", "Burp", "ffuf", "feroxbuster", "gobuster", "katana", "sqlmap", "jwt_tool", "nmap", "hydra"],
             "tags": ["recon", "sqli", "lfi", "jwt", "upload"]},
            {"file": "Web/common_payloads.md",
             "title": "Common Payloads",
             "sub": "SQLi / XSS / LFI / SSTI / XXE / SSRF / JWT / upload bypass",
             "tools": ["curl", "sqlmap", "jwt_tool"],
             "tags": ["payload", "injection", "bypass", "waf"]},
            {"file": "Web/commands.md",
             "title": "Web Commands",
             "sub": "curl / ffuf / sqlmap / jwt_tool / hydra / reverse shell",
             "tools": ["curl", "ffuf", "feroxbuster", "gobuster", "katana", "sqlmap", "jwt_tool", "hydra", "nc"],
             "tags": ["commands", "curl", "ffuf", "sqlmap"]},
        ],
    },
    {
        "name": "Reverse",
        "icon": "🧩",
        "pages": [
            {"file": "Reverse/reversing_notes.md",
             "title": "Reversing Notes",
             "sub": "แยกตามชนิดไฟล์: ELF / PE / .NET / APK / .pyc / PHP / Go",
             "tools": ["file", "strings", "checksec", "ltrace", "strace", "gdb", "ghidra", "r2", "upx", "pycdc", "jadx", "dnSpy", "capa", "YARA", "DIE"],
             "tags": ["elf", "pe", "dotnet", "apk", "pyc", "upx"]},
            {"file": "Reverse/common_commands.md",
             "title": "Reverse Commands",
             "sub": "readelf / objdump / gdb / ghidra / radare2 / patch ไฟล์",
             "tools": ["readelf", "objdump", "nm", "ldd", "ROPgadget", "x64dbg", "pycdc", "jadx"],
             "tags": ["commands", "gdb", "ghidra", "patch"]},
        ],
    },
    {
        "name": "OSINT",
        "icon": "🔍",
        "pages": [
            {"file": "OSINT/methodology.md",
             "title": "OSINT Methodology",
             "sub": "รูป / ชื่อผู้ใช้ / โดเมน / อีเมล / git history",
             "tools": ["exiftool", "git", "whois", "dig", "subfinder", "curl", "Chrome"],
             "tags": ["geoguess", "gps", "username", "domain", "email"]},
        ],
    },
    {
        "name": "Misc",
        "icon": "🧰",
        "pages": [
            {"file": "Misc/useful_commands.md",
             "title": "Useful Commands",
             "sub": "QR / เสียง / SQLite / evtx / pcap / จัดการไฟล์",
             "tools": ["zbarimg", "sox", "ffmpeg", "multimon-ng", "sqlite3", "jq", "ImageMagick", "steghide", "stegseek", "zsteg", "chainsaw", "tshark"],
             "tags": ["qr", "audio", "sqlite", "evtx", "pcap"]},
        ],
    },
]

BRAND_RE = re.compile(r"\s*(?:—|–|-)?\s*(?:AJCCBC\s*)?(?:CSG\s*CTF\s*20\d\d|CTF-20\d\d|CSG20\d\d|AJCCBC)\s*")


def md_to_html(text: str) -> str:
    """แปลง markdown -> html (ตาราง/โค้ด/หัวข้อมี id ให้ link ได้)"""
    return markdown.markdown(
        text,
        extensions=["fenced_code", "tables", "toc", "sane_lists", "attr_list"],
        extension_configs={"toc": {"permalink": False}},
    )


def clean_headings(md_text: str) -> str:
    """ลบชื่อรายการออกจากหัวข้อ (ตามที่ขอ) แต่เนื้อหายังอ้างอิงได้"""
    out = []
    for line in md_text.splitlines():
        if line.startswith("#"):
            line = BRAND_RE.sub(" ", line)
            line = re.sub(r"\s{2,}", " ", line).rstrip()
        out.append(line)
    return "\n".join(out)


def fix_links(html_text: str) -> str:
    """ลิงก์ .md -> .html และห่อตารางให้เลื่อนแนวนอนได้"""
    html_text = re.sub(r'href="([^"]+?)\.md(#[^"]*)?"', r'href="\1.html\2"', html_text)
    html_text = html_text.replace("<table>", '<div class="table-wrap"><table>')
    html_text = html_text.replace("</table>", "</table></div>")
    return html_text


def build_nav(prefix: str, current: str) -> str:
    parts = [
        f'<a href="{prefix}index.html"><span class="ico">🏠</span> หน้าแรก</a>'
    ]
    for cat in CATS:
        parts.append('<div class="nav-group">')
        parts.append(f'<div class="label">{cat["icon"]} {html.escape(cat["name"])}</div>')
        for page in cat["pages"]:
            url = page["file"].replace(".md", ".html")
            cls = "" if url == current else ""
            parts.append(
                f'<a class="sub{(" active" if url == current else "")}" '
                f'href="{prefix}{url}">{html.escape(page["title"])}</a>'
            )
        parts.append("</div>")
    parts.append(
        f'<div class="nav-group"><div class="label">🔎 ค้นหา</div>'
        f'<a class="sub" href="{prefix}tools.html">Tools Index</a>'
        f'<a class="sub" href="{prefix}index.html#search">ค้นหาทั้งหมด</a></div>'
    )
    return "\n".join(parts)


PAGE_TPL = """<!doctype html>
<html lang="th" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}} · {{SITE}}</title>
<meta name="description" content="{{DESC}}">
<link rel="stylesheet" href="{{PREFIX}}assets/site.css">
</head>
<body>
<div class="wrap">
  <aside class="sidebar">
    <a class="brand" href="{{PREFIX}}index.html">
      <span class="logo">PN</span>
      <span><b>{{SITE}}</b><small>{{SUB}}</small></span>
    </a>
    <nav class="nav">
{{NAV}}
    </nav>
  </aside>
  <div class="main">
    <header class="topbar">
      <button class="icon-btn menu-btn" id="menu-btn" aria-label="เมนู">☰</button>
      <div class="crumb">{{CRUMB}}</div>
      <button class="icon-btn" id="theme-btn" aria-label="ธีม">🌙</button>
    </header>
    <main class="content">
{{TOOLS}}
{{BODY}}
{{PAGER}}
      <div class="footer">แก้ไขเนื้อหาได้ที่ไฟล์ <code>{{SRC}}</code> แล้วรัน <code>python3 build.py</code> ใหม่ · หน้านี้สร้างแบบ static ไม่ต้องต่อเน็ต</div>
    </main>
  </div>
</div>
<script src="{{PREFIX}}assets/site.js"></script>
</body>
</html>
"""


def tool_chips(tools) -> str:
    if not tools:
        return ""
    items = "".join(
        f'<a href="{{P}}tools.html#{html.escape(t.lower().replace(" ", "-"))}">{html.escape(t)}</a>'
        for t in tools
    )
    return f'<div class="toolrow">{items}</div>'


def render_page(page, cat, all_pages, idx) -> str:
    src = ROOT / page["file"]
    text = src.read_text(encoding="utf-8")
    text = clean_headings(text)
    body = fix_links(md_to_html(text))

    depth = len(Path(page["file"]).parts) - 1
    prefix = "../" * depth
    url = page["file"].replace(".md", ".html")

    tools_html = tool_chips(page["tools"]).replace("{P}", prefix)
    crumb = f'{cat["icon"]} {html.escape(cat["name"])} / <b>{html.escape(page["title"])}</b>'

    pager = ""
    prev_page = all_pages[idx - 1] if idx > 0 else None
    next_page = all_pages[idx + 1] if idx + 1 < len(all_pages) else None
    if prev_page or next_page:
        bits = ['<div class="pager">']
        if prev_page:
            bits.append(
                f'<a class="prev" href="{prefix}{prev_page["file"].replace(".md", ".html")}">'
                f'<span>ก่อนหน้า</span>{html.escape(prev_page["title"])}</a>'
            )
        else:
            bits.append("<span></span>")
        if next_page:
            bits.append(
                f'<a class="next" href="{prefix}{next_page["file"].replace(".md", ".html")}">'
                f'<span>ถัดไป</span>{html.escape(next_page["title"])}</a>'
            )
        bits.append("</div>")
        pager = "".join(bits)

    out = (PAGE_TPL
           .replace("{{TITLE}}", html.escape(page["title"]))
           .replace("{{SITE}}", SITE_TITLE)
           .replace("{{SUB}}", SITE_SUB)
           .replace("{{DESC}}", html.escape(page["sub"]))
           .replace("{{PREFIX}}", prefix)
           .replace("{{NAV}}", build_nav(prefix, url))
           .replace("{{CRUMB}}", crumb)
           .replace("{{TOOLS}}", tools_html)
           .replace("{{BODY}}", body)
           .replace("{{PAGER}}", pager)
           .replace("{{SRC}}", page["file"]))
    dest = ROOT / url
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(out, encoding="utf-8", newline="\n")
    return url


QUICKSTART = """
<section class="quickstart" id="quickstart">
  <h2>🚀 เริ่มใช้ใน 3 คำสั่ง</h2>

  <div class="steps">
    <div class="step">
      <div class="n">1</div>
      <div>
        <h3>โคลนโปรเจกต์ลงเครื่อง</h3>
        <pre><code>git clone &lt;repo-url&gt; CTF-2026
cd CTF-2026</code></pre>
        <p class="hint">ถ้าได้มาเป็นไฟล์ zip: <code>unzip CTF-2026-all-in-one.zip &amp;&amp; cd CTF-2026</code></p>
      </div>
    </div>

    <div class="step">
      <div class="n">2</div>
      <div>
        <h3>ให้สิทธิ์รัน + ติดตั้งของที่ขาด</h3>
        <pre><code>chmod +x install.sh scripts/*.sh
bash install.sh              # ติดตั้ง apt/pip/gem ที่ขาด
bash scripts/check_tools.sh  # ตรวจซ้ำว่าครบ</code></pre>
        <p class="hint">git กับ zip <b>ไม่เก็บสิทธิ์ +x</b> → ต้องรัน <code>chmod</code> ครั้งเดียวหลัง clone
        (หรือเรียกด้วย <code>bash ชื่อไฟล์</code> ก็ได้ ไม่ต้อง chmod)</p>
      </div>
    </div>

    <div class="step">
      <div class="n">3</div>
      <div>
        <h3>เริ่มไล่หา flag</h3>
        <pre><code>python3 scripts/run_pipeline.py challenge.bin
bash scripts/auto_triage.sh challenge.bin
bash scripts/flag_hunt.sh .
bash scripts/web_flag.sh http://target
python3 scripts/crypto_pipeline.py "UTFO{...}"</code></pre>
        <p class="hint">ผลลัพธ์ทุกตัวอยู่ใน <code>output_&lt;ชื่อสคริปต์&gt;/</code> และมี <code>_FLAGS.txt</code> เมื่อเจอ</p>
      </div>
    </div>
  </div>
</section>

"""


def render_home(all_pages) -> str:
    blocks = []
    for cat in CATS:
        cards = []
        for page in cat["pages"]:
            url = page["file"].replace(".md", ".html")
            chips = "".join(f'<span class="chip">{html.escape(t)}</span>' for t in page["tools"][:6])
            hay = " ".join([page["title"], page["sub"], cat["name"], " ".join(page["tools"]), " ".join(page["tags"])])
            cards.append(
                f'<a class="card" href="{url}" data-search="{html.escape(hay, quote=True)}">'
                f'<h3>{html.escape(page["title"])}</h3>'
                f'<p>{html.escape(page["sub"])}</p>'
                f'<div class="tools">{chips}</div></a>'
            )
        blocks.append(
            f'<section class="cat-block"><div class="cat-head">'
            f'<h2>{cat["icon"]} {html.escape(cat["name"])}</h2>'
            f'<span class="count">{len(cat["pages"])} หน้า</span></div>'
            f'<div class="grid">{"".join(cards)}</div></section>'
        )

    total_pages = sum(len(c["pages"]) for c in CATS)
    body = f"""
<section class="hero">
  <h1>Personal Notes</h1>
  <p class="lead">cheat sheet + คำสั่งพร้อมรัน + สคริปต์ automation สำหรับไล่หา flag
  ทุกหน้าคัดจากโจทย์จริงและ tools ที่อนุญาตในสนาม — เลือกหมวดด้านล่างหรือพิมพ์ค้นหา</p>
  <div class="searchbar">
    <input id="search" type="search" placeholder="ค้นหา: exiftool, xor, lfi, upx, spectrogram, zip …  (กด / เพื่อโฟกัส)" autocomplete="off">
  </div>
  <p class="hint">มี {total_pages} หน้า · เริ่มเร็ว: เปิด <a href="Automation/automation_guide.html">Automation</a> ถ้าอยากให้สคริปต์ไล่หาให้ หรือ <a href="README.html">ภาพรวม</a> ถ้าอยากได้ตารางเลือกเอง</p>
</section>
<p id="no-result" class="hint hidden">ไม่พบหน้าที่ตรงกับคำค้น — ลองคำสั้นลง เช่น <code>xor</code>, <code>zip</code>, <code>jwt</code></p>
""" + QUICKSTART + "".join(blocks)
    nav = build_nav("", "index.html")
    out = (PAGE_TPL
           .replace("{{TITLE}}", "หน้าแรก")
           .replace("{{SITE}}", SITE_TITLE)
           .replace("{{SUB}}", SITE_SUB)
           .replace("{{DESC}}", "cheat sheet + automation สำหรับไล่หา flag")
           .replace("{{PREFIX}}", "")
           .replace("{{NAV}}", nav)
           .replace("{{CRUMB}}", "<b>หน้าแรก</b>")
           .replace("{{TOOLS}}", "")
           .replace("{{BODY}}", body)
           .replace("{{PAGER}}", "")
           .replace("{{SRC}}", "README.md"))
    (ROOT / "index.html").write_text(out, encoding="utf-8", newline="\n")
    return "index.html"


def render_tools() -> str:
    """หน้ารวม tool ทั้งหมด -> หน้าที่ใช้ tool นั้น"""
    index = {}
    for cat in CATS:
        for page in cat["pages"]:
            for tool in page["tools"]:
                index.setdefault(tool, []).append((cat, page))

    rows = []
    for tool in sorted(index, key=str.lower):
        uses = index[tool]
        links = " · ".join(
            f'<a href="{p["file"].replace(".md", ".html")}#tools">{html.escape(p["title"])}</a>'
            for _, p in uses
        )
        anchor = tool.lower().replace(" ", "-")
        rows.append(
            f'<tr id="{html.escape(anchor)}"><td><code>{html.escape(tool)}</code></td>'
            f'<td>{len(uses)}</td><td>{links}</td></tr>'
        )

    body = f"""
<h1>Tools Index</h1>
<p>Click ชื่อ tool เพื่อไปยังหน้าที่พูดถึง tool นั้น (ทุกหน้าอยู่ในเครื่องทั้งหมด ไม่ต้องต่อเน็ต)</p>
<p class="hint">ทั้งหมด {len(index)} tools</p>
<div class="table-wrap"><table>
<thead><tr><th style="width:190px">Tool</th><th style="width:70px">หน้า</th><th>ใช้ใน</th></tr></thead>
<tbody>{"".join(rows)}</tbody>
</table></div>
"""
    out = (PAGE_TPL
           .replace("{{TITLE}}", "Tools Index")
           .replace("{{SITE}}", SITE_TITLE)
           .replace("{{SUB}}", SITE_SUB)
           .replace("{{DESC}}", "รวม tool ทั้งหมดและหน้าที่ใช้")
           .replace("{{PREFIX}}", "")
           .replace("{{NAV}}", build_nav("", "tools.html"))
           .replace("{{CRUMB}}", "<b>Tools Index</b>")
           .replace("{{TOOLS}}", "")
           .replace("{{BODY}}", body)
           .replace("{{PAGER}}", "")
           .replace("{{SRC}}", "build.py"))
    (ROOT / "tools.html").write_text(out, encoding="utf-8", newline="\n")
    return "tools.html"


def main() -> int:
    all_pages = [(cat, page) for cat in CATS for page in cat["pages"]]
    flat = [p for _, p in all_pages]

    missing = [p["file"] for p in flat if not (ROOT / p["file"]).exists()]
    if missing:
        print("[!] ไม่พบไฟล์:", missing)
        return 1

    for idx, (cat, page) in enumerate(all_pages):
        url = render_page(page, cat, flat, idx)
        print(f"  page  {url}")

    render_home(flat)
    render_tools()
    print("  page  index.html")
    print("  page  tools.html")
    print(f"\n[ok] สร้างเสร็จ {len(flat) + 2} หน้า")
    return 0


if __name__ == "__main__":
    sys.exit(main())
