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

[ -f "$DATADIR/disable" ] && exit 0
[ -x "$WATCHDOG" ] || exit 0

mkdir -p "$DATADIR/auths" "$DATADIR/logs" "$DATADIR/static"

if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null)
  pid_matches "$pid" "$WATCHDOG" && exit 0
  rm -f "$PIDFILE"
fi

nohup "$WATCHDOG" >> "$LOG" 2>&1 &
echo $! > "$PIDFILE"
