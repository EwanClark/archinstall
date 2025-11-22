#! /bin/bash

secure_boot_script='#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

if ! sbctl status | grep -Eiq "Setup Mode:[[:space:]]*(yes|true|enabled)"; then
  echo "Secure Boot must be in setup mode before enrolling keys. Reboot, enable setup mode, and re-run this script."
  exit 1
fi

sbctl create-keys
sbctl enroll-keys --microsoft
sbctl sign /boot/vmlinuz-linux
sbctl sign /boot/efi/EFI/arch/grubx64.efi

mkinitcpio -P
'

secure_boot_info() {
  log_info "Restart your computer, enter BIOS, and enable/restart into Secure Boot setup mode."
  log_info "Boot into the new Arch installation and run the setup script found in your home directory."
  log_info "Once Secure Boot keys are enrolled, you'll be able to boot with Secure Boot enabled."
  log_info "Delete the setup script from your home directory after completing the steps."
  log_blank
  log_warn "IMPORTANT: Reboot into Secure Boot setup mode before running the setup script or it will fail."
}

generate_script() {
  if [[ -z "${username:-}" ]]; then
    log_error "Unable to generate Secure Boot setup script: username is not available."
    log_warn "Secure Boot keys must be enrolled manually."
    return 1
  fi

  local script_path="/mnt/home/$username/secure_boot_setup.sh"
  printf '%s\n' "$secure_boot_script" > "$script_path"
  chmod +x "$script_path"
}
