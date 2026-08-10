#!/system/bin/sh

SKIPUNZIP=0
DATADIR=/data/adb/cliproxyapi
BIN="$MODPATH/bin/cli-proxy-api"

ui_print "- CLIProxyAPI"
ui_print "- Author: As-tsaqib"
ui_print "- Arch: $ARCH"

[ "$ARCH" = "arm64" ] || abort "Unsupported arch: $ARCH. Need arm64-v8a."

DEVICE_API=${API:-$(getprop ro.build.version.sdk 2>/dev/null)}
case "$DEVICE_API" in
  ''|*[!0-9]*) abort "Cannot determine Android API level." ;;
esac
[ "$DEVICE_API" -ge 24 ] || abort "Unsupported Android API $DEVICE_API. Need Android 7.0 / API 24 or newer."

[ -f "$BIN" ] || abort "Missing bundled binary: bin/cli-proxy-api"

mkdir -p "$DATADIR/auths" "$DATADIR/logs" "$DATADIR/static"
chmod 0700 "$DATADIR" "$DATADIR/auths" "$DATADIR/logs"
chmod 0755 "$DATADIR/static"

if [ -f "$MODPATH/static/management.html" ]; then
  cp "$MODPATH/static/management.html" "$DATADIR/static/management.html" || abort "Dashboard copy failed"
  chmod 0644 "$DATADIR/static/management.html"
  ui_print "- Installed dashboard: $DATADIR/static/management.html"
fi

if [ ! -f "$DATADIR/config.yaml" ]; then
  cp "$MODPATH/config/config.yaml" "$DATADIR/config.yaml" || abort "Config copy failed"
  UUID_ONE=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
  UUID_TWO=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
  CLIENT_API_KEY=$(printf '%s%s' "$UUID_ONE" "$UUID_TWO" | tr -d '-')
  case "$CLIENT_API_KEY" in
    *[!0-9a-f]*|'') abort "Secure client API key generation failed" ;;
  esac
  [ "${#CLIENT_API_KEY}" -eq 64 ] || abort "Generated client API key has an invalid length"
  sed -i "s/@GENERATED_API_KEY@/$CLIENT_API_KEY/" "$DATADIR/config.yaml" || abort "Client API key injection failed"
  grep -Fq '@GENERATED_API_KEY@' "$DATADIR/config.yaml" && abort "Client API key placeholder was not replaced"
  unset UUID_ONE UUID_TWO CLIENT_API_KEY
  ui_print "- Created config: $DATADIR/config.yaml"
  ui_print "- Generated a unique client API key in the config"
  ui_print "- Initial dashboard password: admin123 (change it immediately)"
else
  ui_print "- Kept config: $DATADIR/config.yaml"
fi

chmod 0755 "$BIN" "$MODPATH/service.sh" "$MODPATH/watchdog.sh" "$MODPATH/post-fs-data.sh" "$MODPATH/uninstall.sh" "$MODPATH/action.sh" "$MODPATH/set-dashboard-password.sh"
chmod 0600 "$DATADIR/config.yaml"
TERMUX_BIN=/data/data/com.termux/files/usr/bin
if [ -d "$TERMUX_BIN" ] && [ -f "$MODPATH/termux-wrapper.sh" ]; then
  TERMUX_WRAPPER="$TERMUX_BIN/cliproxyapi"
  WRAPPER_OWNED=0
  if [ -f "$TERMUX_WRAPPER" ] && [ ! -L "$TERMUX_WRAPPER" ]; then
    if grep -Fqx '# Managed by CLIProxyAPI-Magisk' "$TERMUX_WRAPPER" 2>/dev/null || {
      grep -Fqx 'BIN=/data/adb/modules/cliproxyapi/bin/cli-proxy-api' "$TERMUX_WRAPPER" 2>/dev/null &&
      grep -Fqx 'CONFIG=/data/adb/cliproxyapi/config.yaml' "$TERMUX_WRAPPER" 2>/dev/null
    }; then
      WRAPPER_OWNED=1
    fi
  fi

  if [ ! -e "$TERMUX_WRAPPER" ] && [ ! -L "$TERMUX_WRAPPER" ]; then
    cp "$MODPATH/termux-wrapper.sh" "$TERMUX_WRAPPER" 2>/dev/null && chmod 0755 "$TERMUX_WRAPPER" && ui_print "- Installed Termux wrapper: $TERMUX_WRAPPER"
  elif [ "$WRAPPER_OWNED" -eq 1 ]; then
    cp "$MODPATH/termux-wrapper.sh" "$TERMUX_WRAPPER" 2>/dev/null && chmod 0755 "$TERMUX_WRAPPER" && ui_print "- Updated Termux wrapper: $TERMUX_WRAPPER"
  else
    ui_print "! Kept existing Termux command (not owned by this module): $TERMUX_WRAPPER"
  fi
fi

ui_print "- Listener default: 0.0.0.0:8317"
ui_print "- Reboot to start service"
ui_print "- Disable: touch $DATADIR/disable"
