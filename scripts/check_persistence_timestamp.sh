#!/bin/bash

# Script: persistence_timestamp.sh
# Purpose: Analyze modification timestamps of critical system files and directories
# Author: Claude

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialize variables
CUSTOM_DIR=""
OUTPUT_FILE=""
VERBOSE=false
START_DATE=""

usage() {
    echo "Usage: $0 -d <directory> [options]"
    echo
    echo "Options:"
    echo "    -d, --directory DIR    Target directory to analyze (required)"
    echo "    -o, --output FILE     Save results to file"
    echo "    -v, --verbose        Show verbose output"
    echo "    -s, --start-date     Show files modified after this date/time"
    echo "                         Format: 'YYYY-MM-DD HH:MM:SS'"
    echo
    echo "Example:"
    echo "    $0 -d /mnt/root -o timestamps.txt"
    echo "    $0 -d /mnt/root -s '2024-01-01 15:30:00'"
    exit 1
}

log() {
    local level=$1
    shift
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
    
    case $level in
        "INFO") echo -e "${GREEN}${message}${NC}" ;;
        "WARN") echo -e "${YELLOW}${message}${NC}" ;;
        "ERROR") echo -e "${RED}${message}${NC}" ;;
    esac
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$message" >> "$OUTPUT_FILE"
    fi
}

is_modified_after_start_date() {
    local file_time=$1
    local start_time=$2
    
    # Convert times to seconds since epoch for comparison
    file_epoch=$(date -d "$file_time" +%s)
    start_epoch=$(date -d "$start_time" +%s)
    
    if [ $file_epoch -gt $start_epoch ]; then
        return 0  # true
    else
        return 1  # false
    fi
}

check_timestamps() {
    local dir=$1
    local path=$2
    local description=$3
    
    local full_path="${dir}${path}"
    
    if [ ! -e "$full_path" ]; then
        return
    fi

    local found_modifications=false

    find "$full_path" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
        # Get modification time
        modify=$(stat -c "%y" "$file")
        
        # Skip if start date is set and file is older
        if [ -n "$START_DATE" ]; then
            if ! is_modified_after_start_date "$modify" "$START_DATE"; then
                continue
            fi
        fi
        
        # If we get here, we found at least one modification
        if ! $found_modifications; then
            log "INFO" "Checking timestamps for ${description}..."
            found_modifications=true
        fi
        
        # Calculate days since modification
        current_time=$(date +%s)
        file_time=$(date -d "$modify" +%s)
        days_since=$(( (current_time - file_time) / 86400 ))
        
        # Print file information
        echo "File: $file"
        echo "  Modified: $modify"
        echo "  Days since modification: $days_since"
        
        # Check for suspicious timestamps
        current_year=$(date +%Y)
        file_year=$(date -d "$modify" +%Y)
        
        if [ $days_since -eq 0 ]; then
            echo -e "  ${YELLOW}Warning: Modified today${NC}"
        fi
        
        if [ $file_year -gt $current_year ]; then
            echo -e "  ${RED}Warning: Future timestamp detected${NC}"
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo "  File type: $(file "$file")"
            echo "  Preview (first 3 lines):"
            head -n 3 "$file" 2>/dev/null | sed 's/^/    /'
        fi
        
        echo ""
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            CUSTOM_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--start-date)
            START_DATE="$2"
            # Validate date format
            if ! date -d "$START_DATE" >/dev/null 2>&1; then
                echo "Error: Invalid date format. Use 'YYYY-MM-DD HH:MM:SS'"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$CUSTOM_DIR" ]; then
    echo "Error: Target directory is required"
    usage
fi

if [ ! -d "$CUSTOM_DIR" ]; then
    echo "Error: Directory $CUSTOM_DIR does not exist"
    exit 1
fi

# Initialize output file if specified
if [ -n "$OUTPUT_FILE" ]; then
    : > "$OUTPUT_FILE"
    log "INFO" "Starting timestamp analysis on $CUSTOM_DIR"
fi

# Critical paths to check (focused list)
PATHS=(
    "/etc/cron.d:System cron jobs"
    "/etc/cron.daily:Daily cron jobs"
    "/etc/cron.hourly:Hourly cron jobs"
    "/etc/cron.weekly:Weekly cron jobs"
    "/etc/cron.monthly:Monthly cron jobs"
    "/etc/crontab:System crontab"
    "/var/spool/cron:User crontabs"
    "/etc/init.d:Init scripts"
    "/etc/systemd/system:Systemd services"
    "/etc/rc.local:RC local script"
    "/root/.ssh:Root SSH directory"
    "/root/.bashrc:Root bash configuration"
    "/root/.bash_profile:Root bash profile"
    "/etc/passwd:Password file"
    "/etc/shadow:Shadow password file"
    "/etc/group:Group file"
    "/etc/sudoers:Sudoers file"
    "/etc/sudoers.d:Sudoers directory"
)

# Print header
log "INFO" "=== Timestamp Analysis Report ==="
log "INFO" "Target Directory: $CUSTOM_DIR"
log "INFO" "Date: $(date)"
if [ -n "$START_DATE" ]; then
    log "INFO" "Showing files modified after: $START_DATE"
fi
echo

# Check each path
for path_entry in "${PATHS[@]}"; do
    IFS=':' read -r path description <<< "$path_entry"
    check_timestamps "$CUSTOM_DIR" "$path" "$description"
done

log "INFO" "Timestamp analysis complete"

if [ -n "$OUTPUT_FILE" ]; then
    log "INFO" "Results saved to $OUTPUT_FILE"
fi
