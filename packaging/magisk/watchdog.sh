#!/system/bin/sh

export PATH=/system/bin:/system/xbin:/vendor/bin:$PATH

MODDIR=${0%/*}
DATADIR=/data/adb/cliproxyapi
BINARY="$MODDIR/bin/cli-proxy-api"
CONFIG="$DATADIR/config.yaml"
DEFAULT_CONFIG="$MODDIR/config/config.yaml"
STATIC_DIR="$DATADIR/static"
APP_LOG="$DATADIR/cliproxyapi.log"
WATCHDOG_LOG="$DATADIR/watchdog.log"
PIDFILE="$DATADIR/cliproxyapi.pid"
DISABLE="$DATADIR/disable"
STOP="$DATADIR/stop"
INTERVAL=10
BOOT_DELAY=20
STABLE_TIME=60
MAX_BACKOFF=300
backoff=0
started_at=0

rotate_log() {
  file=$1
  [ -f "$file" ] || return 0
  size=$(stat -c %s "$file" 2>/dev/null)
  case "$size" in ''|*[!0-9]*) return 0 ;; esac
  if [ "$size" -gt 2097152 ]; then
    tail -n 2000 "$file" > "${file}.tmp" 2>/dev/null && mv -f "${file}.tmp" "$file" 2>/dev/null
  fi
}

log() {
  rotate_log "$WATCHDOG_LOG"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

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

wait_for_exit() {
  wait_pid=$1
  wait_expected=$2
  wait_seconds=${3:-10}
  while [ "$wait_seconds" -gt 0 ] && pid_matches "$wait_pid" "$wait_expected"; do
    sleep 1
    wait_seconds=$((wait_seconds - 1))
  done
  ! pid_matches "$wait_pid" "$wait_expected"
}

start_app() {
  started_at=$(date +%s 2>/dev/null)
  case "$started_at" in ''|*[!0-9]*) started_at=0 ;; esac
  [ -x "$BINARY" ] || { log "missing binary: $BINARY"; return 1; }
  mkdir -p "$DATADIR/auths" "$DATADIR/logs" "$STATIC_DIR"
  [ -f "$CONFIG" ] || cp "$DEFAULT_CONFIG" "$CONFIG"
  if [ ! -f "$STATIC_DIR/management.html" ] && [ -f "$MODDIR/static/management.html" ]; then
    cp "$MODDIR/static/management.html" "$STATIC_DIR/management.html"
    chmod 0644 "$STATIC_DIR/management.html"
  fi
  rotate_log "$APP_LOG"
  cd "$DATADIR" || return 1
  GODEBUG=netdns=cgo MANAGEMENT_STATIC_PATH="$STATIC_DIR" nohup "$BINARY" --config "$CONFIG" >> "$APP_LOG" 2>&1 &
  app_pid=$!
  echo "$app_pid" > "$PIDFILE"
  log "started cli-proxy-api pid=$app_pid"
}

stop_app() {
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if pid_matches "$pid" "$BINARY"; then
      kill "$pid" 2>/dev/null
      if ! wait_for_exit "$pid" "$BINARY" 10; then
        log "cli-proxy-api did not stop gracefully; killing pid=$pid"
        kill -9 "$pid" 2>/dev/null
      fi
    elif [ -n "$pid" ]; then
      log "ignored stale or foreign app pid=$pid"
    fi
    rm -f "$PIDFILE"
  fi
}

shutdown() {
  trap - INT TERM EXIT
  stop_app
  rm -f "$DATADIR/watchdog.pid"
  exit 0
}

trap 'shutdown' INT TERM EXIT

sleep "$BOOT_DELAY"

while true; do
  if [ -f "$DISABLE" ] || [ -f "$STOP" ]; then
    stop_app
    log "disabled; watchdog exit"
    rm -f "$STOP"
    exit 0
  fi

  pid=""
  [ -f "$PIDFILE" ] && pid=$(cat "$PIDFILE" 2>/dev/null)

  if ! pid_matches "$pid" "$BINARY"; then
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac

    if [ -n "$pid" ]; then
      log "process dead or PID ownership mismatch pid=$pid"
      rm -f "$PIDFILE"
    fi

    if [ "$started_at" -gt 0 ] && [ "$now" -ge "$started_at" ] && [ $((now - started_at)) -ge "$STABLE_TIME" ]; then
      backoff=0
    elif [ "$started_at" -gt 0 ]; then
      if [ "$backoff" -eq 0 ]; then
        backoff=$INTERVAL
      else
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
      fi
    fi

    if [ "$backoff" -gt 0 ]; then
      log "restart delayed ${backoff}s after short-lived process"
      sleep "$backoff"
      if [ -f "$DISABLE" ] || [ -f "$STOP" ]; then
        continue
      fi
    fi

    start_app
  elif [ "$backoff" -gt 0 ]; then
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    if [ "$started_at" -gt 0 ] && [ "$now" -ge "$started_at" ] && [ $((now - started_at)) -ge "$STABLE_TIME" ]; then
      log "process stable; restart backoff reset"
      backoff=0
    fi
  fi

  sleep "$INTERVAL"
done
