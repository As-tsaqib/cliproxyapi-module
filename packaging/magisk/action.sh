#!/system/bin/sh

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH

DATA_DIR=/data/adb/cliproxyapi
MODULE_DIR=/data/adb/modules/cliproxyapi
BIN=$MODULE_DIR/bin/cli-proxy-api
APP_PID_FILE=$DATA_DIR/cliproxyapi.pid
WATCHDOG_PID_FILE=$DATA_DIR/watchdog.pid
APP_LOG=$DATA_DIR/cliproxyapi.log
WATCHDOG_LOG=$DATA_DIR/watchdog.log
DASHBOARD=$DATA_DIR/static/management.html
URL=http://127.0.0.1:8317/healthz

pid_alive() {
  file=$1
  expected=$2
  [ -f "$file" ] || return 1
  pid=$(cat "$file" 2>/dev/null)
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ -r "/proc/$pid/cmdline" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  tr '\000' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -Fqx "$expected"
}

port_listening() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -Eq '(^|[[:space:]])[^[:space:]]*:8317([[:space:]]|$)' && return 0
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | grep -Eq '(^|[[:space:]])[^[:space:]]*:8317([[:space:]]|$)' && return 0
  fi
  for socket_table in /proc/net/tcp /proc/net/tcp6; do
    [ -r "$socket_table" ] || continue
    awk '$2 ~ /:207D$/ && $4 == "0A" { found=1 } END { exit !found }' "$socket_table" 2>/dev/null && return 0
  done
  return 1
}

health_reachable() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 3 "$URL" >/dev/null 2>&1
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -T 3 -O /dev/null "$URL" >/dev/null 2>&1
    return $?
  fi
  return 2
}

echo "===================================="
echo "   CLIProxyAPI Diagnostic Panel"
echo "===================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo

echo "[STATUS]"
if [ -x "$BIN" ]; then
  echo "✓ Binary    : Installed"
else
  echo "✗ Binary    : Missing"
fi

if pid_alive "$APP_PID_FILE" "$BIN"; then
  app_pid=$(cat "$APP_PID_FILE" 2>/dev/null)
  echo "✓ Daemon    : RUNNING (PID $app_pid)"
else
  echo "✗ Daemon    : STOPPED"
fi

if pid_alive "$WATCHDOG_PID_FILE" "$MODULE_DIR/watchdog.sh"; then
  wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
  echo "✓ Watchdog  : ACTIVE (PID $wd_pid)"
else
  echo "✗ Watchdog  : STOPPED"
fi

if port_listening; then
  echo "✓ TCP Port  : 8317 Listening"
else
  echo "✗ TCP Port  : 8317 Offline"
fi

health_reachable
case $? in
  0) echo "✓ Healthz   : 200 OK" ;;
  2) echo "⚠ Healthz   : Not Probed" ;;
  *) echo "✗ Healthz   : Unreachable" ;;
esac

if [ -f "$DATA_DIR/disable" ]; then
  echo "⚠ Autostart : Disabled"
else
  echo "✓ Autostart : Enabled"
fi

echo
echo "[SHORTCUTS]"
echo "• Dashboard : http://127.0.0.1:8317"
echo "• Command   : cliproxyapi"
echo "• Password  : cliproxyapi dashboard-password"

echo
echo "[RECENT LOGS]"

if [ -f "$WATCHDOG_LOG" ]; then
  last_wd=$(grep -E 'started|stopped|restarted' "$WATCHDOG_LOG" 2>/dev/null | tail -2 | sed 's/^/  /')
  if [ -n "$last_wd" ]; then
    echo "• Watchdog Events:"
    echo "$last_wd"
  else
    echo "• Watchdog Events: None"
  fi
else
  echo "• Watchdog Log: Missing"
fi

if [ -f "$APP_LOG" ]; then
  last_app=$(grep -i 'started\|updated\|error' "$APP_LOG" 2>/dev/null | tail -2 | sed 's/^/  /')
  if [ -n "$last_app" ]; then
    echo "• Service Events:"
    echo "$last_app"
  else
    echo "• Service Events: None"
  fi
else
  echo "• Service Log: Missing"
fi

echo "===================================="
