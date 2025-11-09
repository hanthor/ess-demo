#!/bin/bash
# Shared checksum verification utilities
# Used by both download-installers.sh and verify-installers scripts

# Calculate SHA256 checksum
calculate_checksum() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Verify checksum for a file
verify_checksum() {
    local file="$1"
    local checksum_file="${file}.sha256"
    
    # Check if checksum file exists
    if [ ! -f "$checksum_file" ]; then
        return 1  # No checksum to verify
    fi
    
    # Calculate local checksum
    local local_checksum=$(calculate_checksum "$file")
    
    if [ -z "$local_checksum" ]; then
        return 2  # Could not calculate checksum
    fi
    
    # Extract checksum from file (handle both "checksum filename" and just "checksum" formats)
    local stored_checksum=$(head -1 "$checksum_file" | awk '{print $1}')
    
    if [ "$local_checksum" = "$stored_checksum" ]; then
        return 0  # Checksum matches
    else
        return 3  # Checksum mismatch
    fi
}

# Verify all checksums in a directory
verify_directory_checksums() {
    local dir="$1"
    local verified_count=0
    local failed_count=0
    local results=""
    
    if [ ! -d "$dir" ]; then
        return 1
    fi
    
    for file in "$dir"/*; do
        # Skip checksum files themselves
        if [[ "$file" == *.sha256 ]]; then
            continue
        fi
        
        if [ -f "$file" ]; then
            verify_checksum "$file"
            local result=$?
            
            if [ $result -eq 0 ]; then
                results+="✓ $(basename "$file")\n"
                ((verified_count++))
            elif [ $result -eq 1 ]; then
                # No checksum file exists
                :
            else
                results+="⚠ $(basename "$file") - checksum mismatch\n"
                ((failed_count++))
            fi
        fi
    done
    
    echo -e "$results"
    echo "Verified: $verified_count | Failed: $failed_count"
    
    # Return non-zero if any failed
    [ $failed_count -eq 0 ]
}
