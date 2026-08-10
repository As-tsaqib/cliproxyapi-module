#!/system/bin/sh

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH

MODDIR=${0%/*}
DATADIR=/data/adb/cliproxyapi
WATCHDOG="$MODDIR/watchdog.sh"
PIDFILE="$DATADIR/watchdog.pid"
LOG="$DATADIR/watchdog.log"

pid_matches() {
  pid=$1
  expected=$2
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ -r "/proc/$pid/cmdline" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  tr '\000' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -Fqx "$expected"
}

ensure_termux_wrapper() {
  TERMUX_BIN=/data/data/com.termux/files/usr/bin
  WRAPPER_SRC="$MODDIR/termux-wrapper.sh"
  [ -d "$TERMUX_BIN" ] || return 0
  [ -f "$WRAPPER_SRC" ] || return 0

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
    cp "$WRAPPER_SRC" "$TERMUX_WRAPPER" 2>/dev/null && chmod 0755 "$TERMUX_WRAPPER"
  elif [ "$WRAPPER_OWNED" -eq 1 ]; then
    cp "$WRAPPER_SRC" "$TERMUX_WRAPPER" 2>/dev/null && chmod 0755 "$TERMUX_WRAPPER"
  fi
}

[ -f "$DATADIR/disable" ] && exit 0
[ -x "$WATCHDOG" ] || exit 0

mkdir -p "$DATADIR/auths" "$DATADIR/logs" "$DATADIR/static"
ensure_termux_wrapper

if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null)
  pid_matches "$pid" "$WATCHDOG" && exit 0
  rm -f "$PIDFILE"
fi

nohup "$WATCHDOG" >> "$LOG" 2>&1 &
echo $! > "$PIDFILE"
