#!/bin/bash

setup_chroot() {
  # Create temporary directory structure
  mkdir -p /mnt/opt/archinstall/chroot_functions
  
  # Copy all chroot function files
  cp functions/chroot/*.sh /mnt/opt/archinstall/chroot_functions/
  cp functions/compatibility.sh /mnt/opt/archinstall/chroot_functions/
  cp functions/logging.sh /mnt/opt/archinstall/chroot_functions/
  cp functions/browser.sh /mnt/opt/archinstall/chroot_functions/
  
  # Copy the main chroot install script
  cp functions/chroot/install.sh /mnt/opt/archinstall/chroot_install.sh
  chmod +x /mnt/opt/archinstall/chroot_install.sh
  
  # Export variables needed in chroot environment
  cat > /mnt/opt/archinstall/chroot_vars.sh << EOF
export boot_partition="${boot_partition:-}"
export has_nvidia="${nvidia:-false}"
export dual_boot="${dual_boot:-false}"
export secure_boot="${secure_boot:-false}"
EOF
}

execute_chroot_install() {
  arch-chroot /mnt /opt/archinstall/chroot_install.sh
  
  # Import username from chroot environment
  if [[ -f /mnt/opt/archinstall/username.txt ]]; then
    username=$(< /mnt/opt/archinstall/username.txt)
    rm /mnt/opt/archinstall/username.txt
  else
    log_warn "Unable to locate the username generated inside the chroot."
  fi

  rm -rf /mnt/opt/archinstall
}
