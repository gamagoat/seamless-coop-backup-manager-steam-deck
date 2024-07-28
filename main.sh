#!/bin/bash

source "$(dirname "$0")/config.sh"

LATEST_ER=""

set_latest_er() {
  local converted_version
  converted_version=$(echo "$SEAMLESS_VERSION" | sed 's/\./_/g')

  local compatdata_id_var="COMPATDATA_ID_${converted_version}"
  local compatdata_id="${!compatdata_id_var}"

  LATEST_ER="${BASE_PATH}/${compatdata_id}/${ER_PFX_PATH}"

  if [[ -n "$compatdata_id" ]]; then
    LATEST_ER="${BASE_PATH}/${compatdata_id}${ER_PFX_PATH}"
  else
    echo "Error: No path found for version $SEAMLESS_VERSION." >&2
    exit 1
  fi
}

execute_remote() {
  local cmd="$1"
  ssh "$SSH_TARGET" "$cmd"
}

backup_save() {
  set_latest_er

  execute_remote "
    BACKUP_DIR='$BACKUP_DIR'
    LATEST_ER='$LATEST_ER'
    SEAMLESS_VERSION='$SEAMLESS_VERSION'

    echo \"Remote BACKUP_DIR: \$BACKUP_DIR\"
    echo \"Remote LATEST_ER: \$LATEST_ER\"

    backup_version_dir=\"\$BACKUP_DIR/\$SEAMLESS_VERSION\"
    [ ! -d \"\$backup_version_dir\" ] && mkdir -p \"\$backup_version_dir\"

    backup_file=\"\$backup_version_dir/ER0000-\$(date +'%Y-%m-%d-%H-%M').co2.bak\"
    echo \"Backup file: \$backup_file\"
    cp \"\$LATEST_ER/ER0000.co2\" \"\$backup_file\" && echo \"Backup created at \$backup_file\"
  "
}

display_menu() {
  gum style --bold --border double --foreground 212 --border-foreground 57 \
    --align center --width 50 --margin "1 2" --padding "2 2" "SeamlessCoop Backup Manager"

  local options=("Create New Backup" "Exit")
  local choice
  choice=$(gum choose "${options[@]}")

  case "$choice" in
  "Create New Backup")
    backup_save
    ;;
  "Exit")
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
  esac
}

display_menu
