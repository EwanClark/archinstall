#! /bin/bash
set -Eeuo pipefail

source functions/logging.sh
source functions/compatibility.sh
source functions/disk.sh
source functions/packages.sh
source functions/secureboot.sh
source functions/chroot/setup.sh
source functions/finalizing.sh

log_step "Checking system compatibility"
if ! check_compatibility; then
  exit 1
fi

log_step "Selecting installation disk"
select_disk

log_step "Creating partition layout"
make_partitions

log_step "Reviewing partition mapping"
get_partitions

log_step "Formatting partitions"
format_partitions

log_step "Mounting base partitions"
mount_partitions

log_step "Detecting required packages"
detect_packages

log_step "Selecting boot manager partition)"
select_boot_manager_partition

# check to see if they want to select a boot manager partition !!!
log_step "Mounting boot manager partition"
mount_boot_manager

log_step "Installing base system"
install_packages

log_step "Preparing chroot environment"
setup_chroot

log_step "Running configuration inside chroot"
execute_chroot_install

log_step "Mounting any additional partitions"
mount_additional_partitions

log_step "Generating fstab"
create_fstab

log_step "Finalizing installation"
finalizing