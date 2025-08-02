#!/usr/bin/env bash
# ProxyChains manager - add, remove, list proxies safely

set -euo pipefail
IFS=$'\n\t'

# - Valid types and candidate config paths
VALID_TYPES=("http" "https" "socks4" "socks5")
CONFIG_CANDIDATES=("/etc/proxychains4.conf" "/etc/proxychains.conf")
LOCK_FILE="/var/lock/proxychains.lock"

detect_config() {
  for p in "${CONFIG_CANDIDATES[@]}"; do
    [[ -f "$p" ]] && { echo "$p"; return 0; }
  done
  echo "proxychains.conf or proxychains4.conf not found under /etc" >&2
  exit 1
}

CONFIG_PATH="$(detect_config)"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Root privileges required - re-running with sudo..."
    exec sudo -E -- "$0" "$@"
  fi
}

backup_config() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -a -- "$CONFIG_PATH" "${CONFIG_PATH}.bak.${ts}"
}

is_valid_type() {
  local t="${1,,}"
  for v in "${VALID_TYPES[@]}"; do
    [[ "$t" == "$v" ]] && return 0
  done
  return 1
}

is_valid_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]{1,5}$ ]] && (( p >= 1 && p <= 65535 ))
}

is_valid_host() {
  local h="$1"
  # IPv4
  if [[ "$h" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r o1 o2 o3 o4 <<< "$h"
    for o in "$o1" "$o2" "$o3" "$o4"; do
      (( o >= 0 && o <= 255 )) || return 1
    done
    return 0
  fi
  # Hostname
  [[ "$h" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

ensure_proxylist_section() {
  if ! grep -q '^\[ProxyList\]' "$CONFIG_PATH"; then
    {
      echo
      echo "[ProxyList]"
    } >> "$CONFIG_PATH"
  fi
}

extract_proxylist() {
  awk '
    /^\[ProxyList\]/{inpl=1; next}
    /^\[/{inpl=0}
    inpl && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {print}
  ' "$CONFIG_PATH"
}

exists_entry() {
  local type="$1" host="$2" port="$3" userpass="${4:-}"
  local pattern
  if [[ -n "$userpass" ]]; then
    pattern="^${type}[[:space:]]+${host}[[:space:]]+${port}[[:space:]]+${userpass}([[:space:]]|$)"
  else
    pattern="^${type}[[:space:]]+${host}[[:space:]]+${port}([[:space:]]|$)"
  fi
  extract_proxylist | grep -E -q "$pattern"
}

add_entry() {
  local type="$1" host="$2" port="$3" userpass="${4:-}"
  ensure_proxylist_section
  local tmp
  tmp="$(mktemp)"
  awk -v t="$type" -v h="$host" -v p="$port" -v up="$userpass" '
    BEGIN{ins=0}
    /^\[ProxyList\]/{print; getline;
      if (up != "") { print t " " h " " p " " up } else { print t " " h " " p }
      ins=1
      print
      next
    }
    {print}
    END{
      if (ins==0) {
        print "[ProxyList]"
        if (up != "") { print t " " h " " p " " up } else { print t " " h " " p }
      }
    }
  ' "$CONFIG_PATH" > "$tmp"
  mv -- "$tmp" "$CONFIG_PATH"
}

remove_entry_exact() {
  local type="$1" host="$2" port="$3" userpass="${4:-}"
  local tmp
  tmp="$(mktemp)"
  awk -v t="$type" -v h="$host" -v p="$port" -v up="$userpass" '
    BEGIN{inpl=0}
    /^\[ProxyList\]/{inpl=1; print; next}
    /^\[/{inpl=0; print; next}
    {
      if (inpl==1) {
        line=$0
        gsub(/[[:space:]]+/," ",line)
        if (up != "") { target=t " " h " " p " " up } else { target=t " " h " " p }
        if (line==target) next
      }
      print
    }
  ' "$CONFIG_PATH" > "$tmp"
  mv -- "$tmp" "$CONFIG_PATH"
}

remove_entry_index() {
  local idx="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v rmidx="$idx" '
    BEGIN{inpl=0; n=0}
    /^\[ProxyList\]/{inpl=1; print; next}
    /^\[/{inpl=0; print; next}
    {
      if (inpl==1) {
        line=$0
        if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) { print; next }
        n++
        if (n==rmidx) next
      }
      print
    }
  ' "$CONFIG_PATH" > "$tmp"
  mv -- "$tmp" "$CONFIG_PATH"
}

list_entries() {
  echo "Proxies under [ProxyList] in ${CONFIG_PATH}:"
  awk '
    /^\[ProxyList\]/{inpl=1; next}
    /^\[/{inpl=0}
    inpl && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {print}
  ' "$CONFIG_PATH" | nl -ba
}

main_menu() {
  echo
  echo "Running as $(whoami) - config: $CONFIG_PATH"
  echo "Choose an option:"
  echo "1) Add a proxy"
  echo "2) Remove a proxy by values"
  echo "3) Remove a proxy by index"
  echo "4) List all proxies"
  echo "5) Exit"
  read -r choice
  case "$choice" in
    1) add_proxy ;;
    2) remove_proxy_exact ;;
    3) remove_proxy_index ;;
    4) list_entries ;;
    5) exit 0 ;;
    *) echo "Invalid option" ;;
  esac
}

add_proxy() {
  read -r -p "Proxy type http, https, socks4, socks5: " proxytype
  proxytype="${proxytype,,}"
  is_valid_type "$proxytype" || { echo "Invalid proxy type"; return; }

  read -r -p "IP or hostname: " host
  is_valid_host "$host" || { echo "Invalid host"; return; }

  read -r -p "Port: " port
  is_valid_port "$port" || { echo "Invalid port - must be 1-65535"; return; }

  read -r -p "Username and password if any in format 'user pass' - leave blank if none: " user pass || true
  local userpass=""
  if [[ -n "${user:-}" && -n "${pass:-}" ]]; then
    userpass="$user $pass"
  fi

  if exists_entry "$proxytype" "$host" "$port" "$userpass"; then
    echo "Entry already exists - not adding a duplicate."
    return
  fi

  backup_config
  # serialize changes with flock
  exec 9>"$LOCK_FILE"
  flock 9
  add_entry "$proxytype" "$host" "$port" "$userpass"
  echo "Proxy added."
}

remove_proxy_exact() {
  read -r -p "Type host port: " rtype rhost rport
  is_valid_type "$rtype" || { echo "Invalid proxy type"; return; }
  is_valid_host "$rhost" || { echo "Invalid host"; return; }
  is_valid_port "$rport" || { echo "Invalid port"; return; }

  read -r -p "Username and password if used for this entry - format 'user pass' - leave blank if none: " user pass || true
  local userpass=""
  if [[ -n "${user:-}" && -n "${pass:-}" ]]; then
    userpass="$user $pass"
  fi

  backup_config
  exec 9>"$LOCK_FILE"
  flock 9
  remove_entry_exact "$rtype" "$rhost" "$rport" "$userpass"
  echo "If the entry existed, it has been removed."
}

remove_proxy_index() {
  list_entries
  read -r -p "Enter index to remove: " idx
  [[ "$idx" =~ ^[0-9]+$ ]] || { echo "Index must be a positive integer"; return; }
  backup_config
  exec 9>"$LOCK_FILE"
  flock 9
  remove_entry_index "$idx"
  echo "If the index existed, it has been removed."
}

# - Kick off
require_root "$@"
while true; do
  main_menu
done
