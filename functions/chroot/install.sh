#!/bin/bash

set -Eeuo pipefail

# Source all required chroot functions
source /opt/archinstall/chroot_functions/logging.sh
source /opt/archinstall/chroot_functions/account.sh
source /opt/archinstall/chroot_functions/grub.sh
source /opt/archinstall/chroot_functions/localization.sh
source /opt/archinstall/chroot_functions/nvidia.sh
source /opt/archinstall/chroot_functions/services.sh
source /opt/archinstall/chroot_functions/compatibility.sh

# Import variables from host environment
source /opt/archinstall/chroot_vars.sh

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

log_step "Setting keyboard layout"
keyboard_layout

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
rm -rf /opt/archinstall

log_step "Chroot configuration complete!"

