#!/bin/bash

# Check if a custom directory is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <custom_directory>"
    echo "Example: $0 /mnt/root"
    exit 1
fi

CUSTOM_DIR="$1"
PASSWD_FILE="$CUSTOM_DIR/etc/passwd"

# Verify that the passwd file exists in the specified directory
if [ ! -f "$PASSWD_FILE" ]; then
    echo "Error: $PASSWD_FILE not found. Please check the directory."
    exit 1
fi

echo "=== Suspicious User Accounts Check for $PASSWD_FILE ==="

# Check for users with UID 0 (should only be root)
echo "[1] Checking for additional UID 0 accounts..."
awk -F: '($3 == 0) {print "Suspicious UID 0 account:", $1}' "$PASSWD_FILE"

# Check for users with login shells that should not have them
echo "[2] Checking for users with login shells..."
awk -F: '($7 ~ /bash|sh/) && ($1 !~ /^(root|admin|user)/) {print "Interactive shell for user:", $1, "Shell:", $7}' "$PASSWD_FILE"

# Check for users with non-standard home directories
echo "[3] Checking for non-standard home directories..."
awk -F: '($6 !~ /^\/home\/|^\/root$/) {print "Non-standard home directory:", $1, "Home:", $6}' "$PASSWD_FILE"

# Check for duplicate UIDs
echo "[4] Checking for duplicate UIDs..."
awk -F: '{print $3}' "$PASSWD_FILE" | sort | uniq -d | while read uid; do
    echo "Duplicate UID found:" $uid
    grep ":$uid:" "$PASSWD_FILE"
done

# Check for duplicate GIDs
echo "[5] Checking for duplicate GIDs..."
awk -F: '{print $4}' "$PASSWD_FILE" | sort | uniq -d | while read gid; do
    echo "Duplicate GID found:" $gid
    grep ":.*:$gid:" "$PASSWD_FILE"
done

# Check for last modification time of the passwd file
echo "[6] Checking last modification time of $PASSWD_FILE..."
stat "$PASSWD_FILE"

echo "=== Check Complete ==="
