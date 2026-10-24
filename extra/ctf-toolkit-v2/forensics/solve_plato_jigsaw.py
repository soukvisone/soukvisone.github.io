#!/usr/bin/env python3
"""C2: Plato - full solver.  Usage: python3 solve_plato.py Plato.jpg
Needs: pip install pillow numpy"""
import sys, re, io, string, itertools, zipfile, zlib
import numpy as np
from PIL import Image

jpg = open(sys.argv[1] if len(sys.argv) > 1 else "Plato.jpg", "rb").read()

# 1) carve the hidden zip: it starts at the first 'PK\x03\x04' signature
zip_bytes = jpg[jpg.find(b"PK\x03\x04"):]
z = zipfile.ZipFile(io.BytesIO(zip_bytes))
names = [n for n in z.namelist() if n.endswith(".jpg")]
print("hidden files:", len(names))

# 2) crack the password (tiny word -> brute-force every a-z string up to 3 letters)
pwd = None
for n in range(1, 4):
    for t in itertools.product(string.ascii_lowercase, repeat=n):
        try:
            z.read(names[0], pwd="".join(t).encode()); pwd = "".join(t); break
        except (RuntimeError, zlib.error, zipfile.BadZipFile):   # wrong password (sometimes only caught later)
            pass
    if pwd: break
print("zip password:", pwd)
raw = {int(re.search(r"/(\d+) ", n).group(1)): z.read(n, pwd=pwd.encode()) for n in names}

# 3) rebuild the jigsaw: neighbouring tiles have nearly identical pixel columns/rows
img = {k: np.asarray(Image.open(io.BytesIO(v)).convert("RGB")).astype(float) for k, v in raw.items()}
def right_cost(a, b): return np.abs(img[a][:, -1] - img[b][:, 0]).mean()
def below_cost(a, b): return np.abs(img[a][-1] - img[b][0]).mean()
ids = list(img)
right = {a: min((b for b in ids if b != a), key=lambda b: right_cost(a, b)) for a in ids}
below = {a: min((b for b in ids if b != a), key=lambda b: below_cost(a, b)) for a in ids}
top_left = [a for a in ids if a not in right.values() and a not in below.values()][0]
grid, row_start = [], top_left
for _ in range(3):
    row, t = [], row_start
    for _ in range(4):
        row.append(t); t = right[t]
    grid.append(row); row_start = below[row_start]
print("grid (tile numbers):", grid)

# 4) read the secret chunk that sits between >>>>> and <<<<<  inside each tile file
def chunk(data): return re.search(rb">>>>>\s*(\S+)\s*<<<<<", data).group(1).decode("latin1")
ciphertext = "".join(chunk(raw[t]) for row in grid for t in row)
print("ciphertext:", ciphertext)

# 5) Vigenere decrypt; key = the zip password; key only advances on letters
def vigenere_decrypt(ct, key):
    out, i = [], 0
    for c in ct:
        if c.isalpha():
            base = ord("A") if c.isupper() else ord("a")
            out.append(chr((ord(c) - base - (ord(key[i % len(key)].upper()) - 65)) % 26 + base)); i += 1
        else:
            out.append(c)
    return "".join(out)
print("FLAG:", vigenere_decrypt(ciphertext, pwd))
