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
DASHBOARD_URL=http://127.0.0.1:8317/management.html

RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
GRAY='\033[90m'
WHITE='\033[97m'

ok()   { printf '%b\n' "  ${GREEN}✓${RESET} $*"; }
warn() { printf '%b\n' "  ${YELLOW}⚠${RESET} $*"; }
fail() { printf '%b\n' "  ${RED}✗${RESET} $*"; }

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
    HTTP_CLIENT=curl
    curl -fsS --max-time 3 "$URL" >/dev/null 2>&1
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    HTTP_CLIENT=wget
    wget -q -T 3 -O /dev/null "$URL" >/dev/null 2>&1
    return $?
  fi
  HTTP_CLIENT=none
  return 2
}

printf '%b\n' "${CYAN}═════════════════════════════════════════════════════════${RESET}"
printf '%b\n' "${BOLD}${WHITE}   CLIProxyAPI Control & Diagnostic Panel${RESET}"
printf '%b\n' "${CYAN}═════════════════════════════════════════════════════════${RESET}"
printf '%b\n' "${GRAY} Date: $(date)${RESET}"
echo

printf '%b\n' "${BOLD}${WHITE}[SYSTEM STATUS]${RESET}"

if [ -x "$BIN" ]; then
  ok "Binary Installed  : ${GRAY}$BIN${RESET}"
else
  fail "Binary Missing    : ${RED}$BIN${RESET}"
fi

if pid_alive "$APP_PID_FILE" "$BIN"; then
  app_pid=$(cat "$APP_PID_FILE" 2>/dev/null)
  ok "Service Daemon    : ${GREEN}RUNNING${RESET} ${GRAY}(PID: $app_pid)${RESET}"
else
  fail "Service Daemon    : ${RED}STOPPED / CRASHED${RESET}"
fi

if pid_alive "$WATCHDOG_PID_FILE" "$MODULE_DIR/watchdog.sh"; then
  wd_pid=$(cat "$WATCHDOG_PID_FILE" 2>/dev/null)
  ok "Watchdog Guard    : ${GREEN}ACTIVE${RESET} ${GRAY}(PID: $wd_pid)${RESET}"
else
  fail "Watchdog Guard    : ${RED}STOPPED${RESET}"
fi

if port_listening; then
  ok "TCP Listener      : ${GREEN}0.0.0.0:8317${RESET} ${GRAY}(ONLINE)${RESET}"
else
  fail "TCP Listener      : ${RED}OFFLINE (Port 8317)${RESET}"
fi

health_reachable
health_status=$?
case "$health_status" in
  0) ok "Health Endpoint   : ${GREEN}200 OK${RESET} ${GRAY}($URL via $HTTP_CLIENT)${RESET}" ;;
  2) warn "Health Endpoint   : ${YELLOW}NOT PROBED${RESET} ${GRAY}(curl/wget unavailable)${RESET}" ;;
  *) fail "Health Endpoint   : ${RED}UNREACHABLE${RESET} ${GRAY}($URL)${RESET}" ;;
esac

if [ -f "$DASHBOARD" ]; then
  ok "Dashboard WebUI   : ${GREEN}INSTALLED${RESET}"
else
  warn "Dashboard WebUI   : ${YELLOW}MISSING FILE${RESET}"
fi

if [ -f "$DATA_DIR/disable" ]; then
  warn "Boot Autostart    : ${YELLOW}DISABLED${RESET}"
else
  ok "Boot Autostart    : ${GREEN}ENABLED${RESET}"
fi

echo
printf '%b\n' "${BOLD}${WHITE}[QUICK SHORTCUTS]${RESET}"
printf '%b\n' "  ${CYAN}•${RESET} Web Dashboard     : ${WHITE}$DASHBOARD_URL${RESET}"
printf '%b\n' "  ${CYAN}•${RESET} Termux Command    : ${WHITE}cliproxyapi${RESET}"
printf '%b\n' "  ${CYAN}•${RESET} Change Password   : ${WHITE}cliproxyapi dashboard-password${RESET}"

echo
printf '%b\n' "${BOLD}${WHITE}[RECENT LOGS]${RESET}"

if [ -f "$WATCHDOG_LOG" ]; then
  last_wd=$(grep -E 'started|stopped|restarted' "$WATCHDOG_LOG" 2>/dev/null | tail -2 | sed 's/^/    /')
  if [ -n "$last_wd" ]; then
    printf '%b\n' "  ${CYAN}•${RESET} Watchdog Activity:"
    printf '%b\n' "${GRAY}$last_wd${RESET}"
  else
    printf '%b\n' "  ${CYAN}•${RESET} Watchdog Activity: ${GRAY}No recent events${RESET}"
  fi
else
  warn "Watchdog Log      : ${YELLOW}Not found${RESET}"
fi

if [ -f "$APP_LOG" ]; then
  last_app=$(grep -i 'started\|updated\|error' "$APP_LOG" 2>/dev/null | tail -3 | sed 's/^/    /')
  if [ -n "$last_app" ]; then
    printf '%b\n' "  ${CYAN}•${RESET} Service Activity:"
    printf '%b\n' "${GRAY}$last_app${RESET}"
  else
    printf '%b\n' "  ${CYAN}•${RESET} Service Activity: ${GRAY}No recent log entries${RESET}"
  fi
else
  warn "Service Log       : ${YELLOW}Not found${RESET}"
fi

printf '%b\n' "${CYAN}═════════════════════════════════════════════════════════${RESET}"
