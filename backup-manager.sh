#!/bin/bash

LATEST_COMPATDATA_PATH=""

# Menu options
BACKUP_OPTION="Create New Backup and Sync to Local"
FIND_OPTION="Find Elden Ring Dirs"
#DOWNLOAD_OPTION="Download and Install Latest SeamlessCoop"
EXIT_OPTION="Exit"

set_latest_compatdata_path() {
  local converted_version
  # X.Y.Z becomes X_Y_Z
  converted_version=${SEAMLESS_VERSION//\./_}
  local compatdata_id_var="COMPATDATA_ID_${converted_version}"
  local compatdata_id="${!compatdata_id_var}"

  LATEST_COMPATDATA_PATH="${BASE_PATH}/${compatdata_id}/${ER_PFX_PATH}/"

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

# shellcheck disable=SC2029
execute_remote() {
  ssh "$SSH_TARGET" "$@"
}

backup_save() {
  log debug "Attempting to backup a save on the remote"

  local backup_version_dir
  backup_version_dir="$DECK_BACKUP_DIR/$SEAMLESS_VERSION"

  log debug "$backup_version_dir will be created on the deck if it does not already exist."

  local backup_file
  backup_file="$backup_version_dir/ER0000-$(date +'%Y-%m-%d-%H-%M').co2.bak"

  if execute_remote "
    DECK_BACKUP_DIR='$DECK_BACKUP_DIR'
    LATEST_COMPATDATA_PATH='$LATEST_COMPATDATA_PATH'
    SEAMLESS_VERSION='$SEAMLESS_VERSION'
    backup_file='$backup_file'
    backup_version_dir='$backup_version_dir'

    [ ! -d \"\$backup_version_dir\" ] && mkdir -p \"\$backup_version_dir\"

    cp \"\$LATEST_COMPATDATA_PATH/ER0000.co2\" \"\$backup_file\"
  "; then
    log info "Backup created at $backup_file"
  else
    log error "Backup failed on remote."
  fi
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

find_eldenring_dirs() {
  log debug "Attempting to find Elden Ring related directories."

  if result=$(execute_remote "find /home/deck -type d -path '*/EldenRing/*'"); then
    if [[ -n "$result" ]]; then
      while IFS= read -r line; do
        log info "$line"
      done <<<"$result"
    else
      log error "No Elden Ring directories found on remote"
    fi
  else
    log error "Unable to complete the search."
  fi
}

display_menu() {

  gum style --bold --border double --border-foreground 212 \
    --align center --width 50 --margin "1 2" --padding "1 1" \
    "SeamlessCoop Backup Manager for Steam Deck"

  local options=(
    "$BACKUP_OPTION"
    "$FIND_OPTION"
    #    "$DOWNLOAD_OPTION"
    "$EXIT_OPTION"
  )

  local choice
  choice=$(gum choose "${options[@]}")

  case "$choice" in
  "$BACKUP_OPTION")
    backup_save
    sync_saves_to_local
    ;;
  "$FIND_OPTION")
    find_eldenring_dirs
    ;;
    #  "$DOWNLOAD_OPTION")
    #    download_and_deploy_seamless_coop
    #    ;;
  "$EXIT_OPTION")
    exit 1
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
  esac

}

main() {
  set_latest_compatdata_path

  log debug "DECK_BACKUP_DIR: $DECK_BACKUP_DIR"
  log debug "LATEST_COMPATDATA_PATH: $LATEST_COMPATDATA_PATH"
  log debug "SEAMLESS_VERSION: $SEAMLESS_VERSION"
  log debug "LOCAL_BACKUP_DIR: $LOCAL_BACKUP_DIR"

  while true; do
    display_menu
  done
}

main
