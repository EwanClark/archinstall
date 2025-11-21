#!/bin/bash

setup_chroot() {
  # Create temporary directory structure
  mkdir -p /mnt/tmp/chroot_functions
  
  # Copy all chroot function files
  cp functions/chroot/*.sh /mnt/tmp/chroot_functions/
  cp functions/compatibility.sh /mnt/tmp/chroot_functions/
  cp functions/logging.sh /mnt/tmp/chroot_functions/
  
  # Copy the main chroot install script
  cp functions/chroot/install.sh /mnt/tmp/chroot_install.sh
  chmod +x /mnt/tmp/chroot_install.sh
  
  # Export variables needed in chroot environment
  cat > /mnt/tmp/chroot_vars.sh << EOF
export boot_partition="${boot_partition:-}"
export has_nvidia="${nvidia:-false}"
export dual_boot="${dual_boot:-false}"
export secure_boot="${secure_boot:-false}"
EOF
}

execute_chroot_install() {
  arch-chroot /mnt /bin/bash /tmp/chroot_install.sh
  
  # Import username from chroot environment
  if [[ -f /mnt/tmp/username.txt ]]; then
    username=$(cat /mnt/tmp/username.txt)
    rm /mnt/tmp/username.txt
  fi
}
