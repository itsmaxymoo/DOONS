#!/usr/bin/env python3

import shutil
import subprocess
from pathlib import Path
import zipfile

BUILD_DIR = Path("build")
EXPORT_DIR = Path("doons.bin")
P8_FILE = "doons.p8"

# Create build directory
shutil.rmtree(BUILD_DIR, ignore_errors=True)
BUILD_DIR.mkdir(exist_ok=True)

# Run Pico-8 exports
subprocess.run(
    ["pico8", P8_FILE, "-export", "doons.bin -i 64 -c 16"],
    check=True,
)

subprocess.run(
    ["pico8", P8_FILE, "-export", "doons.p8.png"],
    check=True,
)

subprocess.run(
    ["pico8", P8_FILE, "-export", "doons.html"],
    check=True,
)

Path("./doons.html").write_text(
    Path("./doons.html")
    .read_text(encoding="utf-8")
    .replace("PICO-8 Cartridge", "DOONS"),
    encoding="utf-8",
)

with zipfile.ZipFile("doons_web.zip", "w", compression=zipfile.ZIP_DEFLATED) as zf:
    zf.write("./doons.html", arcname="index.html")
    zf.write("./doons.js", arcname="doons.js")

shutil.move("doons_web.zip", BUILD_DIR / "doons_web.zip")

Path("./doons.html").unlink(missing_ok=True)
Path("./doons.js").unlink(missing_ok=True)

# Move ZIP files to build/
for zip_file in EXPORT_DIR.glob("*.zip"):
    shutil.move(str(zip_file), BUILD_DIR / zip_file.name)

# Move exported PNG
shutil.move("doons.p8.png", BUILD_DIR / "doons.p8.png")

# Remove export directory
if EXPORT_DIR.exists():
    shutil.rmtree(EXPORT_DIR)
