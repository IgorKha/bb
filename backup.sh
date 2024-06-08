#!/usr/bin/env bash

###############################################################################
# SPDX-License-Identifier: MIT                                                #
# File: backup.sh                                                             #
# File Created: Friday, June 7th 2024, 16:19:50                               #
# Author: Igor Kha                                                            #
# --------------------------------------------------------------------------- #
# Last Modified: 2024-06-07, 16:20:09                                         #
# Modified By: Igor Kha                                                       #
# --------------------------------------------------------------------------- #
# License: MIT License https://opensource.org/licenses/MIT                    #
###############################################################################

# ! TODO: Change to your backup prefix
# Backup archive prefix and name
BACKUP_PREFIX="${BACKUP_PREFIX:-backup}"
BACKUP_NAME="$BACKUP_PREFIX-$(date +%Y-%m-%d_%H%M%S).tar.gz"

# ! TODO: Change to your directories
# Default directories
BACKUP_DIR="${BACKUP_DIR:-./backup}"
SOURCE_DIR="${SOURCE_DIR:-./source}"
TARGET_DIR="${TARGET_DIR:-./target}"

# LOGGER CONFIGURATION
LOG_TO_FILE="${LOG_TO_FILE:-True}"
LOG_FILE="${LOG_FILE:-backup.log}"

# Global variables
LATEST_BACKUP=""
declare -i UNZIP_ARCHIVE_SIZE
declare -i PARTITION_SPACE_AVAILABLE

###############################################################################
# SERVICE FUNCTIONS AND HELPERS                                               #
###############################################################################

# Error function
error() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") ERROR: $1" >&2
  help
  exit 1
}

# Logger function
logger() {
  echo "$(date +"%Y-%m-%d %H:%M:%S")# $1"
  if [ "$LOG_TO_FILE" = True ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S")# $1" >> "$LOG_FILE"
  fi
}

# Function to check dependencies
check_dependencies() {
  local cmds=("$@")
  [ ${#cmds[@]} -eq 0 ] && cmds=(tar mkdir cat find awk grep date sort tail head basename file)
  for cmd in "${cmds[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      logger "ERROR: $cmd is not installed." >&2
      exit 1
    fi
  done
}

# Function to convert bytes to human-readable format
bytesto() {
  local value=$1
  local -a powers=(B KB MB GB TB PB EB ZB YB)
  local power=0
  local size=${#powers[@]}

  while [ "$size" -gt 1 ] && [ "$value" -ge 1024 ]; do
    ((value /= 1024))
    ((power++))
    ((size--))
  done

  echo "$value ${powers[$power]}"
}

# Function to get the available space in a partition
get_partition_space() {
  check_dependencies df
  if [ ! -d "$TARGET_DIR" ]; then
    logger "ERROR: Directory $TARGET_DIR does not exist." >&2
    exit 1
  fi
  local size_human
  partition_space=$(df -k "$TARGET_DIR" | tail -1 | awk '{print $4}')
  # Convert to bytes
  partition_space=$((partition_space * 1024))
  PARTITION_SPACE_AVAILABLE="$partition_space"
  size_human=$(bytesto "$partition_space")
  logger "Available space in the partition of $TARGET_DIR: $PARTITION_SPACE_AVAILABLE bytes [$size_human]"
}

compare_partition_space() {
  if [ "$UNZIP_ARCHIVE_SIZE" -gt "$PARTITION_SPACE_AVAILABLE" ]; then
    logger "ERROR: Not enough space in $TARGET_PARTITION to extract the backup." >&2
    exit 1
  fi
}

# Help function
help() {
  cat << EOF
Usage:
  -c --create     Create a backup
  -r --restore    Restore the latest backup

Create options:
  -s    Source directory to backup
  -b    Backup directory
  -v    Verify backup after creation

Restore options:
  -b    Backup directory
  -t    Target directory to restore

Examples:
  $0 -c                       # Create backup in the default directory
  $0 -c -v                    # Verify backup after creation
  $0 -c -s /path/to/source    # Create backup of a specific directory
  $0 -c -b /path/to/backup    # Create backup in a specific directory
  $0 -c -s /path/to/source -b /path/to/backup
  $0 -c -s /path/to/source -b /path/to/backup -v

  $0 -r                      # Restore the latest backup in the default directory
  $0 -r -b /path/to/backup   # Restore the latest backup in a specific directory
  $0 -r -b /path/to/backup -t /path/to/target
EOF
}

###############################################################################
# CREATE BACKUP FUNCTIONS                                                     #
###############################################################################

# Function to create a backup of a directory
backup() {
  if [ ! -d "$SOURCE_DIR" ]; then
    logger "ERROR: Source directory $SOURCE_DIR does not exist." >&2
    exit 1
  fi

  # Create backup directory if it does not exist
  mkdir -p "$BACKUP_DIR"
  # Create backup
  tar -czf "$BACKUP_DIR"/"$BACKUP_NAME" -C "$SOURCE_DIR" .

  logger "SUCCESS: Backup $BACKUP_NAME created in $BACKUP_DIR"
}

# Function to verify the backup
verify_backup() {
  if [ -z "$BACKUP_DIR" ] || [ -z "$BACKUP_NAME" ]; then
    logger "ERROR: Backup directory or name is not set." >&2
    exit 1
  fi

  if [ ! -f "$BACKUP_DIR"/"$BACKUP_NAME" ]; then
    logger "ERROR: Backup file $BACKUP_DIR/$BACKUP_NAME does not exist." >&2
    exit 1
  fi

  if ! file "$BACKUP_DIR"/"$BACKUP_NAME" | grep -q tar; then
    logger "ERROR: Backup file $BACKUP_DIR/$BACKUP_NAME is not a tar archive." >&2
    exit 1
  fi

  if tar -tzf "$BACKUP_DIR"/"$BACKUP_NAME" &> /dev/null; then
    logger "SUCCESS: Backup $BACKUP_NAME is valid"
  else
    logger "ERROR: Backup $BACKUP_NAME is not valid" >&2
    exit 1
  fi
}

###############################################################################
# RESTORE BACKUP FUNCTIONS                                                    #
###############################################################################

# Function to get the latest backup archive name
get_latest_backup() {
  if [ ! -d "$BACKUP_DIR" ]; then
    logger "ERROR: Backup directory $BACKUP_DIR does not exist." >&2
    exit 1
  fi

  max_date_file=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}*.tar.gz" -exec basename {} \; | sort -r | head -n 1)

  if [ -z "$max_date_file" ]; then
    logger "ERROR: No backup files found in $BACKUP_DIR" >&2
    exit 1
  fi
  # Assign the value to a global variable
  LATEST_BACKUP="$max_date_file"
}

# Function to get the archive and estimate the space needed for extraction
get_unzip_archive_size() {
    if [ -z "$BACKUP_DIR" ] || [ -z "$LATEST_BACKUP" ]; then
    logger "ERROR: Backup directory or name is not set." >&2
    exit 1
  fi

  if [ ! -f "$BACKUP_DIR"/"$LATEST_BACKUP" ]; then
    logger "ERROR: Backup file $BACKUP_DIR/$LATEST_BACKUP does not exist." >&2
    exit 1
  fi

  if ! file "$BACKUP_DIR"/"$LATEST_BACKUP" | grep -q tar; then
    logger "ERROR: Backup file $BACKUP_DIR/$LATEST_BACKUP is not a tar archive." >&2
    exit 1
  fi

  logger "Checking archive size..."

  # Estimate the size of the extracted files
  size_in_bytes=$(tar -tvf "$BACKUP_DIR"/"$LATEST_BACKUP" | awk '{s+=$5} END {print s}')
  size_in_megabytes=$(bytesto "$size_in_bytes")

  UNZIP_ARCHIVE_SIZE="$size_in_bytes"

  logger "Latest backup: $LATEST_BACKUP :: requires $UNZIP_ARCHIVE_SIZE bytes [$size_in_megabytes] of disc space."
}

# Function to restore the latest backup
restore_backup() {
  if [ ! -d "$TARGET_DIR" ]; then
    logger "ERROR: Directory $TARGET_DIR does not exist." >&2
    exit 1
  fi

  # ! TODO: RESTORE
  # Extract the latest backup
  tar -xzf "$BACKUP_DIR"/"$LATEST_BACKUP" -C "$TARGET_DIR"

  logger "SUCCESS: Restored backup $LATEST_BACKUP in $TARGET_DIR"
}

###############################################################################
# MAIN FUNCTION                                                               #
###############################################################################

main() {
  logger ""
  logger "------------------------------------ Backup script ------------------------------------"
  # Check dependencies
  check_dependencies

  # Parse command-line options
  case "$1" in
  -h|--help)
    help
    exit 0
    ;;
  -c|--create)
    VERIFY=false
    shift
    while getopts ":s:b:v" opt; do
      case ${opt} in
        s )
          SOURCE_DIR=$OPTARG
          ;;
        b )
          BACKUP_DIR=$OPTARG
          ;;
        v )
          VERIFY=true
          ;;
        \? )
          error "Invalid option: -$OPTARG"
          ;;
        : )
          error "Option -$OPTARG requires an argument."
          ;;
      esac
    done
    logger "MODE: Start creating backup..."
    backup
    if [ "$VERIFY" = true ]; then
      verify_backup
    fi
    logger "Done!"
    ;;
  -r|--restore)
    shift
    while getopts ":b:t:" opt; do
      case ${opt} in
        b )
          BACKUP_DIR=$OPTARG
          ;;
        t )
          TARGET_DIR=$OPTARG
          ;;
        \? )
          error "Invalid option: -$OPTARG"
          ;;
        : )
          error "Option -$OPTARG requires an argument."
          ;;
      esac
    done
    logger "MODE: Start restoring backup..."
    get_latest_backup
    get_unzip_archive_size
    get_partition_space
    compare_partition_space
    restore_backup
    logger "Done!"
    ;;
  *)
    help
    exit 1
  esac
}

main "$@"
