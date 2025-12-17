#!/bin/bash
# Check Uptime Kuma monitors match expected services
# Returns warnings only - does not block commits

check_uptime_monitors() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    # Expected monitors (services that should be monitored)
    local expected=(
        "Bazarr"
        "duc"
        "FlareSolverr"
        "Jellyfin"
        "Jellyseerr"
        "Pi-hole"
        "Prowlarr"
        "qBittorrent"
        "qbit-scheduler"
        "Radarr"
        "Sonarr"
        "Traefik"
        "WireGuard"
    )

    # Try to get NAS host from config.local.md or use default
    local nas_host="yournas.local"
    local nas_user="admin"

    # Check if NAS is reachable (quick ping, 1 second timeout)
    if ! ping -c 1 -W 1 "$nas_host" &>/dev/null 2>&1; then
        echo "    SKIP: NAS not reachable"
        return 0
    fi

    # Check if SSH port is open (prevents hanging on firewall blocks)
    # Uses bash /dev/tcp with 2-second timeout via subshell
    if ! (exec 3<>/dev/tcp/"$nas_host"/22) 2>/dev/null; then
        echo "    SKIP: SSH port not reachable"
        return 0
    fi

    # Get actual monitors from Uptime Kuma
    # Use aggressive SSH timeouts to prevent hanging
    # Requires NAS_SSH_PASS env var or SSH key auth
    local actual
    local ssh_opts="-n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -o ConnectionAttempts=1 -o BatchMode=yes -o LogLevel=ERROR"

    local docker_cmd="docker exec uptime-kuma sqlite3 /app/data/kuma.db \"SELECT name FROM monitor ORDER BY name;\""

    if [[ -n "$NAS_SSH_PASS" ]] && command -v sshpass &>/dev/null; then
        actual=$(sshpass -p "$NAS_SSH_PASS" ssh $ssh_opts "$nas_user@$nas_host" "$docker_cmd" 2>/dev/null)
    else
        # Use publickey only to fail fast if no keys configured
        actual=$(ssh $ssh_opts -o PreferredAuthentications=publickey -o IdentitiesOnly=yes "$nas_user@$nas_host" "$docker_cmd" 2>/dev/null)
    fi

    if [[ -z "$actual" ]]; then
        echo "    SKIP: Could not query Uptime Kuma (docker access failed)"
        return 0
    fi

    local warnings=0

    # Check for missing monitors
    for service in "${expected[@]}"; do
        local service_lower=$(echo "$service" | tr '[:upper:]' '[:lower:]')
        local found=0
        while IFS= read -r monitor; do
            local monitor_lower=$(echo "$monitor" | tr '[:upper:]' '[:lower:]')
            if [[ "$monitor_lower" == "$service_lower" ]]; then
                found=1
                break
            fi
        done <<< "$actual"
        if [[ $found -eq 0 ]]; then
            echo "    WARNING: Missing monitor for '$service'"
            ((warnings++))
        fi
    done

    # Check for unexpected monitors (excluding known extras like Home Assistant, Reolink)
    local known_extras=("Home Assistant" "Reolink NVR")
    while IFS= read -r monitor; do
        [[ -z "$monitor" ]] && continue
        local found=0
        local monitor_lower=$(echo "$monitor" | tr '[:upper:]' '[:lower:]')
        for service in "${expected[@]}" "${known_extras[@]}"; do
            local service_lower=$(echo "$service" | tr '[:upper:]' '[:lower:]')
            if [[ "$monitor_lower" == "$service_lower" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "    WARNING: Unknown monitor '$monitor' (removed service?)"
            ((warnings++))
        fi
    done <<< "$actual"

    if [[ $warnings -eq 0 ]]; then
        echo "    OK: Monitors match expected services"
    fi

    return 0
}
