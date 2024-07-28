#!/bin/bash

source "$(dirname "$0")/config.sh"

LATEST_ER=""

set_latest_er() {
  local converted_version
  # X.Y.Z becomes X_Y_Z
  converted_version=${SEAMLESS_VERSION//\./_}
  local compatdata_id_var="COMPATDATA_ID_${converted_version}"
  local compatdata_id="${!compatdata_id_var}"

  LATEST_ER="${BASE_PATH}/${compatdata_id}/${ER_PFX_PATH}/"

  gum log --structured --level debug -- "Attempting to backup a save on the remote"
  gum log --structured --level debug -- "BACKUP_DIR: $BACKUP_DIR"
  gum log --structured --level debug -- "LATEST_ER: $LATEST_ER"
  gum log --structured --level debug -- "SEAMLESS_VERSION: $SEAMLESS_VERSION"

  if [[ -z "$compatdata_id" ]]; then
    gum log --structured --level error "$compatdata_id_var is not set."
    exit 1
  fi
}

execute_remote() {
  local cmd="$1"
  ssh "$SSH_TARGET" "$cmd"
}

backup_save() {

  execute_remote "
    BACKUP_DIR='$BACKUP_DIR'
    LATEST_ER='$LATEST_ER'
    SEAMLESS_VERSION='$SEAMLESS_VERSION'
    
    backup_version_dir=\"\$BACKUP_DIR/\$SEAMLESS_VERSION\"
    [ ! -d \"\$backup_version_dir\" ] && mkdir -p \"\$backup_version_dir\"

    backup_file=\"\$backup_version_dir/ER0000-\$(date +'%Y-%m-%d-%H-%M').co2.bak\"
    cp \"\$LATEST_ER/ER0000.co2\" \"\$backup_file\" && echo \"Backup created at \$backup_file\"
  "
}

display_menu() {
  gum style --bold --border double --border-foreground 212 \
    --align center --width 50 --margin "1 2" --padding "1 1" "SeamlessCoop Backup Manager"

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

main() {
  set_latest_er
  display_menu
}

main