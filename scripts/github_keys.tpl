#!/bin/bash
set -e

# Array of GitHub users whose keys we want to fetch
USERS=(${join("\n", github_users)})
KEY_DIR="/home/pulsys/.ssh"
AUTH_KEYS="$${KEY_DIR}/authorized_keys"

# Ensure .ssh directory exists with correct permissions
mkdir -p "$${KEY_DIR}"
chmod 700 "$${KEY_DIR}"

# Create or clear authorized_keys file
touch "$${AUTH_KEYS}"
chmod 600 "$${AUTH_KEYS}"

# Fetch and add keys for each user
for user in "$${USERS[@]}"; do
    echo "Fetching keys for $${user}"
    curl -s "https://github.com/$${user}.keys" >> "$${AUTH_KEYS}"
done

# Set correct ownership
chown -R pulsys:pulsys "$${KEY_DIR}"
