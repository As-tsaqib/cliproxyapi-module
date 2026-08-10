#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 ASSET_DIR [--android-arm64]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
ASSET_DIR=$1
MODE=${2:-}
[ -z "$MODE" ] || [ "$MODE" = "--android-arm64" ] || usage

ZIP="$ASSET_DIR/cliproxyapi-magisk.zip"
CHECKSUMS="$ASSET_DIR/checksums.txt"
PROVENANCE="$ASSET_DIR/provenance.json"
UPDATE_METADATA="$ASSET_DIR/update.json"
RELEASE_NOTES="$ASSET_DIR/release-notes.md"

[ -f "$ZIP" ] || { echo "missing release ZIP: $ZIP" >&2; exit 1; }
[ -f "$CHECKSUMS" ] || { echo "missing checksums: $CHECKSUMS" >&2; exit 1; }
[ -f "$PROVENANCE" ] || { echo "missing provenance: $PROVENANCE" >&2; exit 1; }
[ -f "$UPDATE_METADATA" ] || { echo "missing update metadata: $UPDATE_METADATA" >&2; exit 1; }
[ -s "$RELEASE_NOTES" ] || { echo "missing or empty release notes: $RELEASE_NOTES" >&2; exit 1; }

(
  cd "$ASSET_DIR"
  sha256sum --check --strict checksums.txt
)
unzip -t "$ZIP" >/dev/null

python3 - "$ZIP" "$PROVENANCE" "$UPDATE_METADATA" "$RELEASE_NOTES" <<'PY'
import json
import stat
import sys
from pathlib import Path
from zipfile import ZipFile

zip_path = Path(sys.argv[1])
provenance_path = Path(sys.argv[2])
update_metadata_path = Path(sys.argv[3])
release_notes_path = Path(sys.argv[4])
required = {
    "LICENSE",
    "META-INF/com/google/android/update-binary",
    "META-INF/com/google/android/updater-script",
    "README.md",
    "THIRD_PARTY_NOTICES.md",
    "action.sh",
    "bin/cli-proxy-api",
    "config/config.yaml",
    "customize.sh",
    "module.prop",
    "post-fs-data.sh",
    "service.sh",
    "set-dashboard-password.sh",
    "static/management.html",
    "termux-wrapper.sh",
    "uninstall.sh",
    "update.json",
    "watchdog.sh",
    "webroot/index.html",
}
executables = {
    "META-INF/com/google/android/update-binary",
    "action.sh",
    "bin/cli-proxy-api",
    "customize.sh",
    "post-fs-data.sh",
    "service.sh",
    "set-dashboard-password.sh",
    "termux-wrapper.sh",
    "uninstall.sh",
    "watchdog.sh",
}

with ZipFile(zip_path) as archive:
    entries = set(archive.namelist())
    missing = sorted(required - entries)
    if missing:
        raise SystemExit("missing ZIP entries: " + ", ".join(missing))
    if any(name.startswith("/") or ".." in Path(name).parts for name in entries):
        raise SystemExit("ZIP contains an unsafe path")
    for name in executables:
        mode = archive.getinfo(name).external_attr >> 16
        if not mode & stat.S_IXUSR:
            raise SystemExit(f"ZIP entry is not executable: {name}")

    module_prop = archive.read("module.prop").decode("utf-8")
    if "@VERSION@" in module_prop or "@VERSION_CODE@" in module_prop:
        raise SystemExit("module.prop contains unresolved placeholders")
    properties = dict(
        line.split("=", 1)
        for line in module_prop.splitlines()
        if line and not line.startswith("#") and "=" in line
    )
    if properties.get("id") != "cliproxyapi":
        raise SystemExit("module.prop has an unexpected module id")

    default_config = archive.read("config/config.yaml").decode("utf-8")
    for expected in (
        'host: "0.0.0.0"',
        '  - "@GENERATED_API_KEY@"',
        "  allow-remote: true",
        '  secret-key: "admin123"',
    ):
        if expected not in default_config:
            raise SystemExit(f"default config is missing: {expected}")

    update = json.loads(archive.read("update.json"))
    for key in ("version", "versionCode", "zipUrl", "changelog"):
        if key not in update:
            raise SystemExit(f"update.json is missing {key}")
    if update["version"] != properties.get("version"):
        raise SystemExit("module.prop and update.json versions differ")
    if update["versionCode"] != int(properties.get("versionCode", "-1")):
        raise SystemExit("module.prop and update.json version codes differ")
    expected_changelog_suffix = (
        f"/releases/download/{update['version']}/release-notes.md"
    )
    if not update["changelog"].endswith(expected_changelog_suffix):
        raise SystemExit(
            "update.json changelog must point to the versioned release-notes.md asset"
        )

external_update = json.loads(update_metadata_path.read_text(encoding="utf-8"))
if external_update != update:
    raise SystemExit("release update.json differs from the copy inside the ZIP")

provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
for key in ("releaseTag", "source", "models", "dashboard", "toolchain"):
    if key not in provenance:
        raise SystemExit(f"provenance.json is missing {key}")
if provenance["releaseTag"] != update["version"]:
    raise SystemExit("provenance releaseTag differs from update.json version")

release_notes = release_notes_path.read_text(encoding="utf-8")
release_notes_lower = release_notes.lower()
if "Changelog" not in release_notes and "## Upstream changes" not in release_notes:
    raise SystemExit("release notes do not include upstream changes")
if any(
    marker in release_notes_lower
    for marker in ("<!doctype", "<html", "data-color-mode=")
):
    raise SystemExit("release notes contain an HTML page instead of Markdown text")
PY

TMPDIR_ROOT=${RUNNER_TEMP:-${TMPDIR:-/tmp}}
tmp=$(mktemp -d "$TMPDIR_ROOT/cliproxyapi-validate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
unzip -p "$ZIP" bin/cli-proxy-api > "$tmp/cli-proxy-api"
chmod 0755 "$tmp/cli-proxy-api"
readelf -h "$tmp/cli-proxy-api" | grep -Eq 'Class:[[:space:]]+ELF64'

if [ "$MODE" = "--android-arm64" ]; then
  readelf -h "$tmp/cli-proxy-api" | grep -Eq 'Machine:[[:space:]]+AArch64'
  readelf -l "$tmp/cli-proxy-api" | grep -q '/system/bin/linker64'
  readelf -d "$tmp/cli-proxy-api" | grep -q 'libc.so'
fi

echo "Validated release assets in $ASSET_DIR"
