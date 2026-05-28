import os, hashlib, bz2, gzip, time, re
from pathlib import Path

ROOT = Path(__file__).parent
DEBS = sorted(ROOT.glob("*.deb"))

if not DEBS:
    raise SystemExit("ERROR: No .deb file found in this folder.")

deb = DEBS[0]
data = deb.read_bytes()

size = len(data)
md5 = hashlib.md5(data).hexdigest()
sha1 = hashlib.sha1(data).hexdigest()
sha256 = hashlib.sha256(data).hexdigest()

m = re.search(r'_(\d+(?:\.\d+)+)_', deb.name)
version = m.group(1) if m else "1.0.9"

package_text = f"""Package: com.glitchlord.silentpillhud
Name: SilentPillHUD
Version: {version}
Architecture: iphoneos-arm
Description: Realistic compact Silent Mode HUD for iOS 12.
Maintainer: GlitchLord
Author: GlitchLord
Section: Tweaks
Depends: mobilesubstrate, firmware (>= 11.0)
Filename: {deb.name}
Size: {size}
Installed-Size: 64
MD5sum: {md5}
SHA1: {sha1}
SHA256: {sha256}
"""

(ROOT / "Packages").write_text(package_text, encoding="utf-8", newline="\n")

with bz2.open(ROOT / "Packages.bz2", "wb") as f:
    f.write(package_text.encode("utf-8"))

with gzip.open(ROOT / "Packages.gz", "wb") as f:
    f.write(package_text.encode("utf-8"))

release_text = f"""Origin: GlitchLord Repo
Label: GlitchLord Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: GlitchLord Cydia Repo
Date: {time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.gmtime())}
"""

(ROOT / "Release").write_text(release_text, encoding="utf-8", newline="\n")

print("Repo generated successfully.")
print("DEB:", deb.name)
print("Version:", version)
print("Size:", size)
print("MD5:", md5)
print("SHA1:", sha1)
print("SHA256:", sha256)
