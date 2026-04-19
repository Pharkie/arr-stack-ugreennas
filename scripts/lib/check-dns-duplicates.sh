#!/bin/bash
# Check for duplicate .lan domains between dnsmasq and pihole.toml
# Returns warnings only - does not block commits

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

check_dns_duplicates() {
    # Skip if NAS config not available
    if ! has_nas_config; then
        echo "    SKIP: No NAS host in .claude/config.local.md"
        return 0
    fi

    # Check if NAS is reachable
    if ! is_nas_reachable; then
        echo "    SKIP: NAS not reachable"
        return 0
    fi

    # Check if SSH port is open
    if ! is_ssh_available; then
        echo "    SKIP: SSH port not reachable"
        return 0
    fi

    # Get domains from dnsmasq config
    local dnsmasq_domains
    local stack_dir
    stack_dir=$(get_nas_stack_dir)
    dnsmasq_domains=$(ssh_to_nas "grep -oP 'address=/\K[^/]+(?=\.lan/)' $stack_dir/pihole/dnsmasq.d/02-local-dns.conf 2>/dev/null | sort -u") || true

    if [[ -z "$dnsmasq_domains" ]]; then
        echo "    SKIP: Could not read dnsmasq config"
        return 0
    fi

    # Get domains from pihole.toml
    local pihole_domains
    pihole_domains=$(ssh_to_nas "docker exec pihole cat /etc/pihole/pihole.toml 2>/dev/null | grep -oP '\"[0-9.]+\s+\K[^\"]+(?=\.lan)' | sort -u") || true

    # Find duplicates
    local duplicates=""
    for domain in $dnsmasq_domains; do
        if echo "$pihole_domains" | grep -qw "$domain" 2>/dev/null; then
            duplicates="$duplicates $domain.lan"
        fi
    done

    if [[ -n "$duplicates" ]]; then
        echo "    WARNING: Duplicate .lan domains (defined in both dnsmasq and pihole.toml):"
        for dup in $duplicates; do
            echo "      - $dup"
        done
        return 0  # Warning only, don't block
    else
        echo "    OK: No duplicate DNS entries"
    fi

    return 0
}
