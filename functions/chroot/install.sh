#!/bin/bash

set -Euo pipefail

# Source all required chroot functions
source /tmp/chroot_functions/logging.sh
source /tmp/chroot_functions/account.sh
source /tmp/chroot_functions/grub.sh
source /tmp/chroot_functions/localization.sh
source /tmp/chroot_functions/nvidia.sh
source /tmp/chroot_functions/services.sh
source /tmp/chroot_functions/compatibility.sh

# Import variables from host environment
source /tmp/chroot_vars.sh

# Execute chroot functions in order
log_step "Setting root password"
root_password

log_step "Configuring user account"
user_account

log_step "Configuring sudoers"
sudoers

log_step "Setting timezone"
timezone

log_step "Configuring locale"
locale

log_step "Setting hostname"
hostname

log_step "Enabling services"
enable_services

# Check if NVIDIA configuration is needed
if [[ $has_nvidia ]]; then
  log_step "Configuring NVIDIA"
  nvidia
fi

log_step "Installing and configuring GRUB"
grub

# Clean up temporary files
log_step "Cleaning up"
rm -rf /tmp/chroot_functions
rm -f /tmp/chroot_vars.sh
rm -f /tmp/chroot_install.sh

log_step "Chroot configuration complete!"

