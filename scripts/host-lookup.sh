#!/usr/bin/env bash
set -euo pipefail

# IP/hostname resolver for NixOS fleet.
# Parses flake-modules/hosts.nix directly with awk (no nix eval overhead).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="${SCRIPT_DIR}/../flake-modules/hosts.nix"

if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "error: hosts.nix not found at $HOSTS_FILE" >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [query|--list]

Resolve hostnames and IPs from the NixOS fleet configuration.

  $(basename "$0") 192.168.5.49     Look up by IP address
  $(basename "$0") octoprint        Look up by hostname
  $(basename "$0") dns              Partial match on hostname
  $(basename "$0") --list           Show all hosts

Output format: hostname (displayName) - ip
EOF
}

# Parse NixOS host specs from hosts.nix.
# Detects host blocks by the presence of 'system =' which only appears in nixosHostSpecs entries.
# Output: hostname\tip\tdisplayName (tab-separated)
parse_hosts() {
  awk '
    # Match a host entry: "    hostname = {"
    /^[[:space:]]+[-a-zA-Z0-9]+ = \{[[:space:]]*$/ {
      name = $1
      ip = ""
      display = ""
      has_system = 0
      in_block = 1
      brace_depth = 1
      next
    }
    in_block {
      # Track brace depth
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") brace_depth++
        if (c == "}") brace_depth--
      }
      if (/usernames = /) has_system = 1
      if (/ip = "/) {
        match($0, /ip = "([^"]+)"/, m)
        if (m[1] != "") ip = m[1]
      }
      if (/displayName = "/) {
        match($0, /displayName = "([^"]+)"/, m)
        if (m[1] != "") display = m[1]
      }
      if (brace_depth <= 0) {
        if (has_system) {
          if (display == "") display = name
          if (ip == "") ip = "-"
          printf "%s\t%s\t%s\n", name, ip, display
        }
        in_block = 0
      }
    }
  ' "$HOSTS_FILE"
}

# Parse darwinConfigurations section
parse_darwin_hosts() {
  awk '
    /darwinConfigurations = \{/,/^[[:space:]]*};/ {
      if (match($0, /^[[:space:]]+([-a-zA-Z0-9]+) = darwinSystem/, m)) {
        printf "%s\t-\t%s\n", m[1], m[1]
      }
    }
  ' "$HOSTS_FILE"
}

all_hosts() {
  parse_hosts
  parse_darwin_hosts
}

do_lookup() {
  local query="$1"
  local found=false
  while IFS=$'\t' read -r name ip display; do
    if [[ "$ip" == "$query" ]] || [[ "$name" == "$query" ]]; then
      echo "${name} (${display}) - ${ip}"
      found=true
    elif echo "$name $display" | grep -iq "$query"; then
      echo "${name} (${display}) - ${ip}"
      found=true
    fi
  done < <(all_hosts)

  if ! $found; then
    echo "no match for '$query'" >&2
    return 1
  fi
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$1" == "--list" ]]; then
  printf "%-18s %-18s %s\n" "HOSTNAME" "DISPLAY NAME" "IP"
  printf "%-18s %-18s %s\n" "--------" "------------" "--"
  all_hosts | sort | while IFS=$'\t' read -r name ip display; do
    printf "%-18s %-18s %s\n" "$name" "$display" "${ip:--}"
  done
  exit 0
fi

do_lookup "$1"
