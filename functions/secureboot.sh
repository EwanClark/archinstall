#! /bin/bash

secure_boot_script='#!/bin/bash
set -euo pipefail

sbctl create-keys
sbctl enroll-keys --microsoft
sbctl sign /boot/vmlinuz-linux
sbctl sign /boot/efi/EFI/arch/grubx64.efi

mkinitcpio -P
'

secure_boot_info() {
  log_success "Secure Boot has been enabled."
  log_info "Restart your computer, enter BIOS, and enable/restart into Secure Boot setup mode."
  log_info "Boot into the new Arch installation and run the setup script found in your home directory."
  log_info "Once Secure Boot keys are enrolled, you'll be able to boot with Secure Boot enabled."
  log_info "Delete the setup script from your home directory after completing the steps."
  log_blank
  log_warn "IMPORTANT: Reboot into Secure Boot setup mode before running the setup script or it will fail."
}

generate_script() {
  printf '%s\n' "$secure_boot_script" > "/mnt/home/$username/secure_boot_setup.sh"
  chmod +x "/mnt/home/$username/secure_boot_setup.sh"
}
