#!/bin/bash
# Port and IP conflict detection for compose files

check_conflicts() {
    local errors=0
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    # Check each compose file individually for internal conflicts
    for compose_file in "$repo_root"/docker-compose*.yml; do
        [[ -f "$compose_file" ]] || continue
        local filename
        filename=$(basename "$compose_file")

        # Extract host ports (the left side of port mappings like "8080:80")
        local ports
        ports=$(grep -E '^\s+-\s*"?[0-9]+:[0-9]+"?\s*$' "$compose_file" 2>/dev/null | \
            sed -E 's/^[[:space:]]*-[[:space:]]*"?([0-9]+):.*/\1/' | sort)

        # Check for duplicate ports
        local dup_ports
        dup_ports=$(echo "$ports" | uniq -d)
        if [[ -n "$dup_ports" ]]; then
            echo "    ERROR: Duplicate ports in $filename:"
            echo "$dup_ports" | while read -r port; do
                echo "      - Port $port is used multiple times"
            done
            ((errors++))
        fi

        # Extract static IPs (ipv4_address: X.X.X.X)
        local ips
        ips=$(grep -E 'ipv4_address:\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$compose_file" 2>/dev/null | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort)

        # Check for duplicate IPs
        local dup_ips
        dup_ips=$(echo "$ips" | uniq -d)
        if [[ -n "$dup_ips" ]]; then
            echo "    ERROR: Duplicate static IPs in $filename:"
            echo "$dup_ips" | while read -r ip; do
                echo "      - IP $ip is assigned to multiple services"
            done
            ((errors++))
        fi
    done

    # ── Cross-file duplicate detection ──────────────────────────────
    # Collect ALL ports and IPs across every compose file and flag duplicates
    local all_ports_with_files=""
    local all_ips_with_files=""

    for compose_file in "$repo_root"/docker-compose*.yml; do
        [[ -f "$compose_file" ]] || continue
        local fname
        fname=$(basename "$compose_file")

        # Collect ports with their source file
        local file_ports
        file_ports=$(grep -E '^\s+-\s*"?[0-9]+:[0-9]+"?\s*$' "$compose_file" 2>/dev/null | \
            sed -E 's/^[[:space:]]*-[[:space:]]*"?([0-9]+):.*/\1/')
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            all_ports_with_files+="$p $fname"$'\n'
        done <<< "$file_ports"

        # Collect IPs with their source file
        local file_ips
        file_ips=$(grep -E 'ipv4_address:\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$compose_file" 2>/dev/null | \
            grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            all_ips_with_files+="$ip $fname"$'\n'
        done <<< "$file_ips"
    done

    # Check for cross-file port duplicates
    local dup_cross_ports
    dup_cross_ports=$(echo "$all_ports_with_files" | awk '{print $1}' | sort | uniq -d)
    while IFS= read -r port; do
        [[ -z "$port" ]] && continue
        local files_with_port
        files_with_port=$(echo "$all_ports_with_files" | awk -v p="$port" '$1 == p {print $2}' | sort -u)
        local file_count
        file_count=$(echo "$files_with_port" | wc -l | tr -d ' ')
        if [[ "$file_count" -gt 1 ]]; then
            echo "    ERROR: Port $port used across multiple files:"
            echo "$files_with_port" | while read -r f; do
                echo "      - $f"
            done
            ((errors++))
        fi
    done <<< "$dup_cross_ports"

    # Check for cross-file IP duplicates
    local dup_cross_ips
    dup_cross_ips=$(echo "$all_ips_with_files" | awk '{print $1}' | sort | uniq -d)
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        local files_with_ip
        files_with_ip=$(echo "$all_ips_with_files" | awk -v i="$ip" '$1 == i {print $2}' | sort -u)
        local file_count
        file_count=$(echo "$files_with_ip" | wc -l | tr -d ' ')
        if [[ "$file_count" -gt 1 ]]; then
            echo "    ERROR: IP $ip used across multiple files:"
            echo "$files_with_ip" | while read -r f; do
                echo "      - $f"
            done
            ((errors++))
        fi
    done <<< "$dup_cross_ips"

    return $errors
}
