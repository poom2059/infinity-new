import io
import os
import tarfile
from pathlib import Path

import paramiko

HOST = os.environ["CW_HOST"]
USER = os.environ["CW_USER"]
PASSWORD = os.environ["CW_PASS"]
LOCAL_ROOT = Path(os.environ["CW_LOCAL"])
REMOTE_ROOT = os.environ.get(
    "CW_REMOTE",
    "/home/1652179.cloudwaysapps.com/xjyuhxtgym/public_html",
)

if not LOCAL_ROOT.is_dir():
    raise SystemExit(f"Local pack missing: {LOCAL_ROOT}")

buf = io.BytesIO()
count = 0
with tarfile.open(fileobj=buf, mode="w:gz") as tar:
    for path in LOCAL_ROOT.rglob("*"):
        if path.is_file():
            arcname = path.relative_to(LOCAL_ROOT).as_posix()
            tar.add(path, arcname=arcname)
            count += 1
            print(f"  pack {arcname}")
buf.seek(0)
print(f"Packed {count} files ({buf.getbuffer().nbytes} bytes)")

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
print(f"Connecting to {HOST} as {USER} ...")
client.connect(
    HOST,
    username=USER,
    password=PASSWORD,
    timeout=30,
    allow_agent=False,
    look_for_keys=False,
)

# Clear and extract via shell (ACL-friendly)
remote_cmd = f"""
set -e
TARGET='{REMOTE_ROOT}'
test -d "$TARGET"
# remove old contents but keep directory
find "$TARGET" -mindepth 1 -maxdepth 1 -exec rm -rf {{}} +
tar -xzf - -C "$TARGET"
echo '--- remote listing ---'
ls -la "$TARGET" | head -n 40
test -f "$TARGET/index.html"
test -f "$TARGET/.htaccess"
test -f "$TARGET/main.dart.js"
echo UPLOAD_OK
"""
print(f"Uploading into {REMOTE_ROOT} ...")
stdin, stdout, stderr = client.exec_command(remote_cmd)
stdin.write(buf.read())
stdin.channel.shutdown_write()
out = stdout.read().decode(errors="replace")
err = stderr.read().decode(errors="replace")
print(out)
if err.strip():
    print("STDERR:", err)
if "UPLOAD_OK" not in out:
    raise SystemExit("Upload failed")
client.close()
print("Done.")
