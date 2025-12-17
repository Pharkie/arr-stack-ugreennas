#!/bin/bash
# Check if local .env.nas.backup matches NAS .env
# Warns if out of sync (non-blocking)

check_env_backup() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    local backup_file="$repo_root/.env.nas.backup"
    local nas_host="yournas.local"
    local nas_user="admin"

    # Skip if no backup file
    if [[ ! -f "$backup_file" ]]; then
        echo "    SKIP: No .env.nas.backup file"
        return 0
    fi

    # Try to reach NAS (quick ping, 1 second timeout)
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

    # Get NAS .env via SSH
    # Use aggressive SSH timeouts to prevent hanging
    # Requires NAS_SSH_PASS env var or SSH key auth
    local nas_env
    local ssh_opts="-n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -o ConnectionAttempts=1 -o BatchMode=yes -o LogLevel=ERROR"

    if [[ -n "$NAS_SSH_PASS" ]] && command -v sshpass &>/dev/null; then
        nas_env=$(sshpass -p "$NAS_SSH_PASS" ssh $ssh_opts "$nas_user@$nas_host" "cat /volume1/docker/arr-stack/.env" 2>/dev/null)
    else
        # Use publickey only to fail fast if no keys configured
        nas_env=$(ssh $ssh_opts -o PreferredAuthentications=publickey -o IdentitiesOnly=yes "$nas_user@$nas_host" "cat /volume1/docker/arr-stack/.env" 2>/dev/null)
    fi

    # Skip if SSH failed
    if [[ -z "$nas_env" ]]; then
        echo "    SKIP: Could not fetch NAS .env (SSH auth failed)"
        return 0
    fi

    # Compare
    local local_env
    local_env=$(cat "$backup_file")

    if [[ "$nas_env" != "$local_env" ]]; then
        echo "    WARNING: .env.nas.backup differs from NAS .env"
        echo "             Run: scp admin@yournas.local:/volume1/docker/arr-stack/.env .env.nas.backup"
        return 0  # Warning only, don't block
    fi

    echo "    OK: .env.nas.backup matches NAS"
    return 0
}
