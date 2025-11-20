#! /bin/bash
set -Eeuo pipefail

source functions/compatibility.sh
source functions/disk.sh
source functions/packages.sh

if ! check_compatibility; then
  exit 1
fi

select_disk
make_partitions
get_partitions
format_partitions
mount_partitions
detect_packages
install_packages