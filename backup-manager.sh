#!/bin/bash

LATEST_COMPATDATA_PATH=""

# Menu options
BACKUP_OPTION="Create New Backup and Sync to Local"
FIND_OPTION="Find Elden Ring Dirs"
DOWNLOAD_OPTION="Download and Install Latest SeamlessCoop"
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

# We want variable expansion to happen locally, as that's where our env vars
# are defined.  Disable the corresponding shellcheck
# shellcheck disable=SC2029
execute_remote() {
  ssh "$SSH_TARGET" "$@"
}

backup_file_on_remote() {
  local source_file
  source_file="$1"

  local destination_dir
  destination_dir="$2"

  local destination_file
  destination_file="$3"

  local log_message
  log_message="$4"

  log debug "$log_message"

  log debug "$destination_dir will be created on the deck if it does not already exist."

  if execute_remote "
    destination_dir='$destination_dir'
    source_file='$source_file'
    destination_file='$destination_file'

    [ ! -d \"\$destination_dir\" ] && mkdir -p \"\$destination_dir\"

    cp \"\$source_file\" \"\$destination_file\"
  "; then
    log info "Backup created at $destination_file"
  else
    log error "Backup failed on remote."
  fi
}

backup_save() {
  local backup_version_dir
  backup_version_dir="$DECK_BACKUP_DIR/$SEAMLESS_VERSION"

  local backup_file
  backup_file="$backup_version_dir/ER0000-$(date +'%Y-%m-%d-%H-%M').co2.bak"

  local save_file
  save_file="$LATEST_COMPATDATA_PATH/ER0000.co2"

  backup_file_on_remote \
    "$save_file" \
    "$backup_version_dir" \
    "$backup_file" \
    "Attempting to backup save file $save_file"
}

backup_ersc_settings() {
  local settings_ini
  settings_ini="$SEAMLESS_COOP_DIR/$SETTINGS_FILE"

  local backup_dir
  backup_dir="$DECK_BACKUP_DIR/settings"

  local backup_file
  backup_file="$backup_dir/$SETTINGS_FILE-$(date +'%Y-%m-%d-%H-%M')"

  backup_file_on_remote \
    "$settings_ini" \
    "$backup_dir" \
    "$backup_file" \
    "Backing up settings file $settings_ini"
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

download_and_install_latest_seamless_coop_to_deck() {
  log debug "Fetching the latest release information from GitHub..."

  local repo
  repo="LukeYui/EldenRingSeamlessCoopRelease"

  local latest_release_info
  latest_release_info=$(curl -s https://api.github.com/repos/$repo/releases/latest)

  if echo "$latest_release_info" | grep -q '"message": "Not Found"'; then
    log error "Failed to fetch the latest release information."
    log error "Response from GitHub: $latest_release_info"
    exit 1
  fi

  # Extract the version number (tag name)
  local version
  version=$(echo "$latest_release_info" | grep '"tag_name":' | cut -d '"' -f 4)

  if [[ -z "$version" ]]; then
    echo "Failed to extract the version number."
    exit 1
  fi

  # Extract the download URL for the latest asset
  local download_url
  download_url=$(echo "$latest_release_info" | grep "browser_download_url" | head -n 1 | cut -d '"' -f 4)

  if [[ -z "$download_url" ]]; then
    log error "Failed to find a download URL for the latest release."
    exit 1
  fi

  local filename
  filename="seamless-${version}.zip"

  log debug "Downloading $download_url as $filename"

  curl -L -o "$filename" "$download_url"

  if [[ ! -f "$filename" ]]; then
    log error "Failed to download the release."
    exit 1
  fi

  log debug "Download complete.  Transferring the file to the Steam Deck."

  scp "$filename" "$SSH_TARGET:$ELDEN_RING_EXE_DIR"
}

# TODO: Currently only downloads and transfers the zip to the steam deck, but
# does not yet unpack it.
setup_latest_seamless_coop() {
  download_and_install_latest_seamless_coop_to_deck

  # TODO: merge the old settings with the new settings from the new release
  backup_ersc_settings
}

display_menu() {

  gum style --bold --border double --border-foreground 212 \
    --align center --width 50 --margin "1 2" --padding "1 1" \
    "SeamlessCoop Backup Manager for Steam Deck"

  local options=(
    "$BACKUP_OPTION"
    "$FIND_OPTION"
    "$DOWNLOAD_OPTION"
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
  "$DOWNLOAD_OPTION")
    setup_latest_seamless_coop
    ;;
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
