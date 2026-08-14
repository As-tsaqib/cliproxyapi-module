#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PKG="$ROOT/packaging/magisk"
OUT="$ROOT/dist/magisk"
STAGE="$OUT/stage"
ZIP="$OUT/cliproxyapi-magisk.zip"
VERSION=${VERSION:-v0.0.0}
VERSION_CODE=${VERSION_CODE:-0}

[ -x "$PKG/bin/cli-proxy-api" ] || { echo "missing executable: packaging/magisk/bin/cli-proxy-api" >&2; exit 1; }
[ -f "$PKG/static/management.html" ] || { echo "missing dashboard: packaging/magisk/static/management.html" >&2; exit 1; }
[ -f "$ROOT/README.md" ] || { echo "missing repository README" >&2; exit 1; }
[ -f "$ROOT/LICENSE" ] || { echo "missing repository LICENSE" >&2; exit 1; }
[ -f "$ROOT/THIRD_PARTY_NOTICES.md" ] || { echo "missing third-party notices" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$STAGE"
cp -a \
  "$PKG/customize.sh" \
  "$PKG/post-fs-data.sh" \
  "$PKG/service.sh" \
  "$PKG/watchdog.sh" \
  "$PKG/uninstall.sh" \
  "$PKG/action.sh" \
  "$PKG/set-dashboard-password.sh" \
  "$PKG/config" \
  "$PKG/static" \
  "$PKG/webroot" \
  "$PKG/META-INF" \
  "$PKG/update.json" \
  "$STAGE/"
mkdir -p "$STAGE/bin"
cp "$PKG/bin/cli-proxy-api" "$STAGE/bin/cli-proxy-api"
cp "$ROOT/packaging/termux/cliproxyapi" "$STAGE/termux-wrapper.sh"
cp "$ROOT/README.md" "$STAGE/README.md"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGE/THIRD_PARTY_NOTICES.md"
[ -f "$ROOT/cliproxyapi-banner.png" ] && cp "$ROOT/cliproxyapi-banner.png" "$STAGE/cliproxyapi-banner.png"
sed \
  -e "s/@VERSION@/$VERSION/g" \
  -e "s/@VERSION_CODE@/$VERSION_CODE/g" \
  "$PKG/module.prop.in" > "$STAGE/module.prop"
chmod 0755 "$STAGE/bin/cli-proxy-api" "$STAGE/customize.sh" "$STAGE/post-fs-data.sh" "$STAGE/service.sh" "$STAGE/watchdog.sh" "$STAGE/uninstall.sh" "$STAGE/action.sh" "$STAGE/set-dashboard-password.sh" "$STAGE/termux-wrapper.sh" "$STAGE/META-INF/com/google/android/update-binary"

python3 - "$STAGE" "$ZIP" <<'PY'
from pathlib import Path
from sys import argv
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

stage = Path(argv[1])
zip_path = Path(argv[2])
with ZipFile(zip_path, "w") as archive:
    for path in sorted(stage.rglob("*")):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        rel = path.relative_to(stage).as_posix()
        info = ZipInfo(rel)
        info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, path.read_bytes())
PY

echo "$ZIP"
