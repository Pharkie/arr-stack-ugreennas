#!/bin/bash
# Check for duplicate .lan domains between dnsmasq and pihole.toml
# Run on NAS after making DNS changes to catch conflicts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"

DNSMASQ_CONF="$STACK_DIR/pihole/dnsmasq.d/02-local-dns.conf"
get_pihole_toml() {
    docker exec pihole cat /etc/pihole/pihole.toml 2>/dev/null
}

echo "Checking for duplicate .lan domains..."
echo

# Extract domains from dnsmasq config
if [[ -f "$DNSMASQ_CONF" ]]; then
    dnsmasq_domains=$(grep -oP 'address=/\K[^/]+(?=\.lan/)' "$DNSMASQ_CONF" 2>/dev/null | sort -u || true)
else
    echo "Warning: $DNSMASQ_CONF not found"
    dnsmasq_domains=""
fi

# Extract domains from pihole.toml hosts array
pihole_toml=$(get_pihole_toml) || {
    echo "Warning: Could not read pihole.toml from container"
    exit 0
}
pihole_domains=$(echo "$pihole_toml" | grep -oP '"\d+\.\d+\.\d+\.\d+ \K[^"]+(?=\.lan)' 2>/dev/null | sort -u || true)

# Find duplicates
duplicates=""
for domain in $dnsmasq_domains; do
    if echo "$pihole_domains" | grep -qw "$domain"; then
        duplicates="$duplicates $domain.lan"
    fi
done

if [[ -n "$duplicates" ]]; then
    echo -e "${RED}CONFLICT: These domains are defined in BOTH places:${NC}"
    for dup in $duplicates; do
        echo "  - $dup"
    done
    echo
    echo "Fix: Remove from one location (preferably pihole.toml via web UI)"
    echo "     Stack domains should stay in 02-local-dns.conf"
    exit 1
else
    echo -e "${GREEN}OK: No duplicate domains found${NC}"
    echo
    echo "dnsmasq (02-local-dns.conf): $(echo $dnsmasq_domains | wc -w | tr -d ' ') domains"
    echo "pihole.toml: $(echo $pihole_domains | wc -w | tr -d ' ') domains"
    exit 0
fi
