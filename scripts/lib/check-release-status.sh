#!/bin/bash
# Check if latest GitHub release is a draft (which is usually a mistake)

check_release_status() {
    local latest=$(gh release list --limit 1 2>/dev/null)
    
    if [ -z "$latest" ]; then
        echo "    SKIP: Could not fetch releases"
        return 0
    fi
    
    if echo "$latest" | grep -q "Draft"; then
        echo "    WARNING: Latest release is a DRAFT!"
        echo "    Fix with: gh release edit <tag> --draft=false --latest"
        return 1
    fi
    
    echo "    OK: Latest release is published"
    return 0
}
