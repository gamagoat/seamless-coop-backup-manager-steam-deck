#!/bin/bash

LATEST_ER=""

set_latest_er() {
  local converted_version
  # X.Y.Z becomes X_Y_Z
  converted_version=${SEAMLESS_VERSION//\./_}
  local compatdata_id_var="COMPATDATA_ID_${converted_version}"
  local compatdata_id="${!compatdata_id_var}"

  LATEST_ER="${BASE_PATH}/${compatdata_id}/${ER_PFX_PATH}/"

  if [[ -z "$compatdata_id" ]]; then
    gum log --structured --level error "$compatdata_id_var is not set."
    exit 1
  fi
}

log() {
  local level="$1"
  shift
  gum log --structured --level "$level" -- "$@"
}

execute_remote() {
  local cmd="$1"
  ssh "$SSH_TARGET" "$cmd"
}

backup_save() {
  log debug "Attempting to backup a save on the remote"

  execute_remote "
    DECK_BACKUP_DIR='$DECK_BACKUP_DIR'
    LATEST_ER='$LATEST_ER'
    SEAMLESS_VERSION='$SEAMLESS_VERSION'
    
    backup_version_dir=\"\$DECK_BACKUP_DIR/\$SEAMLESS_VERSION\"
    [ ! -d \"\$backup_version_dir\" ] && mkdir -p \"\$backup_version_dir\"

    backup_file=\"\$backup_version_dir/ER0000-\$(date +'%Y-%m-%d-%H-%M').co2.bak\"
    cp \"\$LATEST_ER/ER0000.co2\" \"\$backup_file\" && echo \"Backup created at \$backup_file\"
  "
}

sync_saves_to_local() {
  log debug "Attempting to sync saves from the Deck to local"

  if [[ ! -d "$LOCAL_BACKUP_DIR" ]]; then
    if gum confirm --default="no" "Local backup directory $LOCAL_BACKUP_DIR does not exist. Create it?"; then
      mkdir -p "$LOCAL_BACKUP_DIR"
      gum log --structured --level debug -- "Created local backup directory: $LOCAL_BACKUP_DIR"
    else
      gum log --structured --level error "Local backup directory does not exist and was not created. Aborting sync."
      return
    fi
  fi

  if rsync -av --ignore-existing "$SSH_TARGET:$DECK_BACKUP_DIR/" "$LOCAL_BACKUP_DIR/"; then
    log debug "Sync completed from $DECK_BACKUP_DIR to $LOCAL_BACKUP_DIR"
  else
    log error "Sync failed from $DECK_BACKUP_DIR to $LOCAL_BACKUP_DIR"
  fi

}

display_menu() {
  gum style --bold --border double --border-foreground 212 \
    --align center --width 50 --margin "1 2" --padding "1 1" \
    "SeamlessCoop Backup Manager for Steam Deck"

  local options=("Create New Backup" "Sync Saves to Local" "Exit")
  local choice
  choice=$(gum choose "${options[@]}")

  case "$choice" in
  "Create New Backup")
    backup_save
    ;;
  "Sync Saves to Local")
    sync_saves_to_local
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

  log debug "DECK_BACKUP_DIR: $DECK_BACKUP_DIR"
  log debug "LATEST_ER: $LATEST_ER"
  log debug "SEAMLESS_VERSION: $SEAMLESS_VERSION"
  log debug "LOCAL_BACKUP_DIR: $LOCAL_BACKUP_DIR"

  display_menu
}

main
