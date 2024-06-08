# bb

**b**ash **b**ackup

A simple and universal script for creating and restoring backups with archive verification after creation and disk space check before deploying the backup.

- When restoring, the latest version of the archive is selected based on the date in the archive name among those found in the backup directory (specified via the `-b` key or the `BACKUP_DIR` variable). The search is based on the prefix in the archive name, which is set through `BACKUP_PREFIX`

> [!IMPORTANT]
> Please check the functionality of the `restore_backup()` function. You will likely want to implement your own logic there.

## Usage

```bash
user:~$ ./backup.sh -h

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
  ./backup.sh -c                       # Create backup in the default directory
  ./backup.sh -c -v                    # Verify backup after creation
  ./backup.sh -c -s /path/to/source    # Create backup of a specific directory
  ./backup.sh -c -b /path/to/backup    # Create backup in a specific directory
  ./backup.sh -c -s /path/to/source -b /path/to/backup
  ./backup.sh -c -s /path/to/source -b /path/to/backup -v
  ./backup.sh -r                      # Restore the latest backup in the default directory
  ./backup.sh -r -b /path/to/backup   # Restore the latest backup in a specific directory
  ./backup.sh -r -b /path/to/backup -t /path/to/target
```

## Global variables

It also allows setting certain parameters through global variables.

```bash
# Backup archive prefix name
BACKUP_PREFIX=

BACKUP_DIR=
SOURCE_DIR=
TARGET_DIR=

# Default: True
LOG_TO_FILE=
# Default: backup.log
LOG_FILE=
```

## Log file example

```log
2024-06-08 17:38:52#
2024-06-08 17:38:52# ------------------------------------ Backup script ------------------------------------
2024-06-08 17:38:52# MODE: Start creating backup...
2024-06-08 17:38:52# SUCCESS: Backup backup-2024-06-08_173852.tar.gz created in ./backup
2024-06-08 17:38:52# SUCCESS: Backup backup-2024-06-08_173852.tar.gz is valid
2024-06-08 17:38:52# Done!
2024-06-08 17:39:08#
2024-06-08 17:39:08# ------------------------------------ Backup script ------------------------------------
2024-06-08 17:39:08# MODE: Start restoring backup...
2024-06-08 17:39:08# Checking archive size...
2024-06-08 17:39:08# Latest backup: backup-2024-06-08_173852.tar.gz :: requires 15617024 [14 MB] bytes of disc space.
2024-06-08 17:39:08# ERROR: lsblk is not installed.
```
