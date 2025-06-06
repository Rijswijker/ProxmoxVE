#!/usr/bin/env bash

# Copyright (c) 2025 Robbert van den Berg
# Author: Robbert van den Berg (rijswijker)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/bakito/adguardhome-sync

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Create a temporary directory for the script to work in and ensure it's cleaned up on exit
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fetch the latest release info of adguardhome-sync from GitHub API
RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/bakito/adguardhome-sync/releases/latest)

# Extract the release tag name (e.g., v0.7.3) from the JSON response
RELEASE=$(echo "$RELEASE_JSON" | grep -Po '"tag_name": "\K.*?(?=")')

# Extract the browser download URL for the linux_amd64 binary tarball
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -Po '"browser_download_url": "\K.*linux_amd64.*(?=")')

# Define the path to download the tarball to
TAR_FILE="${TMPDIR}/adguardhome-sync.tar.gz"

# Download the tarball to the temporary directory
$STD curl -fsSL "${DOWNLOAD_URL}" -o "${TAR_FILE}"

# Extract the contents of the tarball if download was successful
$STD tar -zxvf "$TAR_FILE" -C "$TMPDIR"

# Create the installation directory
mkdir -p /opt/AdGuardHomeSync/

# Copy the extracted binary into the install directory and make it executable
cp "${TMPDIR}/adguardhome-sync" /opt/AdGuardHomeSync/adguardhome-sync
chmod +x /opt/AdGuardHomeSync/adguardhome-sync

msg_info "Creating Configuration"

# Define the path to the configuration file
CONFIG_FILE="/opt/AdGuardHomeSync/adguardhome-sync.yaml"

# If the config file does not exist, create a default one
if [[ ! -f "$CONFIG_FILE" ]]; then

cat << 'CONFIG' > $CONFIG_FILE
cron: "* */1 * * *"         # Run every hour
runOnStart: true            # Run immediately on start
continueOnError: true       # Don't stop on errors

origin:
  url: "http://127.0.0.1:3000"
  username: ""
  password: ""

replicas:
  - url: "http://127.0.0.2:3000"
    username: ""
    password: ""
# Additional replicas can be added below if needed
CONFIG

fi

# Save the release version info into a file for future reference
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt

msg_ok "Installed AdGuard-Sync ($RELEASE)"

msg_info "Creating Service"

# Create a systemd service unit to run adguardhome-sync as a background service
cat <<EOF >/etc/systemd/system/AdGuardHomeSync.service
[Unit]
Description=AdGuard Home Sync service
ConditionFileIsExecutable=/opt/AdGuardHomeSync/adguardhome-sync

Requires=network.target
After=network-online.target syslog.target

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHomeSync/adguardhome-sync "run" "--config" "/opt/AdGuardHomeSync/adguardhome-sync.yaml"
WorkingDirectory=/opt/AdGuardHomeSync

Restart=on-success
SuccessExitStatus=1 2 8 SIGKILL
RestartSec=120
EnvironmentFile=-/etc/sysconfig/GoServiceExampleLogging

StandardOutput=file:/var/log/AdGuardHomeSync.out
StandardError=file:/var/log/AdGuardHomeSync.err
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the systemd service immediately
systemctl enable -q --now AdGuardHomeSync
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
