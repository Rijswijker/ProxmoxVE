#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/rijswijker/ProxmoxVE/refs/heads/adguard-sync/misc/build.func)

APP="AdGuard-Sync"
var_tags="${var_tags:-adguard-sync}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if installation is present | -f for file, -d for folder
  if [[ ! -f "/opt/AdGuardHomeSync/adguardhome-sync" ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

    # Crawling the latest release info of adguardhome-sync from GitHub to check for updates
    RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/bakito/adguardhome-sync/releases/latest)

    # Extract the release tag name (e.g., v0.7.3) from the JSON response
    RELEASE=$(echo "$RELEASE_JSON" | grep -Po '"tag_name": "\K.*?(?=")')

    # Extract the browser download URL for the linux_amd64 binary tarball
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -Po '"browser_download_url": "\K.*linux_amd64.*(?=")')

  if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt 2>/dev/null)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    # Stopping Services
    msg_info "Stopping $APP"
    systemctl stop AdGuardHomeSync
    msg_ok "Stopped $APP"

    # Creating Backup
    # msg_info "Creating Backup"
    # tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" [IMPORTANT_PATHS]
    # msg_ok "Backup Created"

    # Execute Update
    msg_info "Updating $APP to v${RELEASE}"

    # Create a temporary directory for the script to work in and ensure it's cleaned up on exit
    TMPDIR=$(mktemp -d)

    # Define the path to download the tarball to
    TAR_FILE="${TMPDIR}/adguardhome-sync.tar.gz"

    # Download the tarball to the temporary directory
    $STD curl -fsSL "${DOWNLOAD_URL}" -o "${TAR_FILE}"

    # Extract the contents of the tarball if download was successful
    $STD tar -zxvf "$TAR_FILE" -C "$TMPDIR"

    # Copy the extracted binary into the install directory and make it executable
    cp "${TMPDIR}/adguardhome-sync" /opt/AdGuardHomeSync/adguardhome-sync
    chmod +x /opt/AdGuardHomeSync/adguardhome-sync

    msg_ok "Updated $APP to ${RELEASE}"

    # Starting Services
    msg_info "Starting $APP"
    systemctl start AdGuardHomeSync
    msg_ok "Started $APP"

    # Cleaning up
    msg_info "Cleaning Up"
    $STD rm -rf "$TMPDIR"
    msg_ok "Cleanup Completed"

    # Last Action
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
# echo -e "${INFO}${YW} Access it using the following URL:${CL}"
# echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
