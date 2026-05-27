import os, gzip, hashlib, tarfile, lzma, bz2, io

REPO = os.path.dirname(os.path.abspath(__file__))
DEBS = os.path.join(REPO, "debs")
PACKAGES = os.path.join(REPO, "Packages")

def read_ar_members(path):
    with open(path, "rb") as f:
        data = f.read()
    if not data.startswith(b"!<arch>\n"):
        raise Exception("Not a valid .deb/ar file")
    pos = 8
    members = {}
    while pos < len(data):
        header = data[pos:pos+60]
        name = header[:16].decode(errors="ignore").strip().rstrip("/")
        size = int(header[48:58].decode().strip())
        pos += 60
        members[name] = data[pos:pos+size]
        pos += size
        if pos % 2:
            pos += 1
    return members

def extract_control(deb_path):
    members = read_ar_members(deb_path)
    control_name = next((n for n in members if n.startswith("control.tar")), None)
    if not control_name:
        raise Exception("control.tar not found")

    data = members[control_name]

    if control_name.endswith(".xz"):
        data = lzma.decompress(data)
    elif control_name.endswith(".gz"):
        data = gzip.decompress(data)
    elif control_name.endswith(".bz2"):
        data = bz2.decompress(data)

    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        for m in tar.getmembers():
            if m.name.endswith("control"):
                return tar.extractfile(m).read().decode("utf-8", errors="ignore").strip()

    raise Exception("control file not found")

entries = []

for file in os.listdir(DEBS):
    if file.endswith(".deb"):
        full = os.path.join(DEBS, file)
        control = extract_control(full)
        size = os.path.getsize(full)

        with open(full, "rb") as f:
            content = f.read()

        md5 = hashlib.md5(content).hexdigest()
        sha1 = hashlib.sha1(content).hexdigest()
        sha256 = hashlib.sha256(content).hexdigest()

        entry = control + f"""
Filename: ./debs/{file}
Size: {size}
MD5sum: {md5}
SHA1: {sha1}
SHA256: {sha256}
"""
        entries.append(entry.strip())

with open(PACKAGES, "w", encoding="utf-8") as f:
    f.write("\n\n".join(entries) + "\n")

with open(PACKAGES, "rb") as f:
    with gzip.open(PACKAGES + ".gz", "wb") as gz:
        gz.write(f.read())

release = """Origin: Master Repo
Label: Master Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: Custom iOS 12 Tweaks
"""

with open(os.path.join(REPO, "Release"), "w", encoding="utf-8") as f:
    f.write(release)

index = """<!DOCTYPE html>
<html>
<head><title>Master Repo</title></head>
<body style="background:#050505;color:white;font-family:Arial;text-align:center;padding:50px;">
<h1>Master Repo</h1>
<p>Custom iOS 12 Tweaks</p>
</body>
</html>
"""

with open(os.path.join(REPO, "index.html"), "w", encoding="utf-8") as f:
    f.write(index)

print("Repo generated successfully!")
print("Created: Packages, Packages.gz, Release, index.html")