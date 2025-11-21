#! /bin/bash
function check_compatibility() {
  if [[ ! -d /sys/firmware/efi ]]; then
    # System is not UEFI, failed compatibility
    log_error "System is not UEFI, this script only supports UEFI systems."
    return 1
  fi

  # All checks passed
  return 0
}


# NVIDIA GPU detection
nvidia_or_amd_or_intel_gpu() {
  if lspci | grep -i "vga\|3d\|display" | grep -qi "nvidia"; then
    nvidia=true
    return 0
  fi
  return 1
}

# Intel or AMD cpu
intel_or_amd_cpu() {
  if [[ $(grep -c "Intel" /proc/cpuinfo) -gt 0 ]]; then
    return 0
  fi
  return 1
}

# Ask if they want dual boot compatibility
dual_boot_compatibility() {
  while true; do
    read -r -p "Do you want dual boot compatibility? [Y/n]: " dual_boot_input </dev/tty
    dual_boot_input="${dual_boot_input,,}"
    case "$dual_boot_input" in
      ""|"y"|"yes")
        dual_boot=true
        return 0
        ;;
      "n"|"no")
        dual_boot=false
        return 1
        ;;
      *)
      log_warn "Please answer yes or no."
        ;;
    esac
  done
}

# Ask if they want secure boot compatibility
secure_boot_compatibility() {
  while true; do
    read -r -p "Do you want secure boot compatibility? [Y/n]: " secure_boot_input </dev/tty
    secure_boot_input="${secure_boot_input,,}"
    case "$secure_boot_input" in
      ""|"y"|"yes")
        secure_boot=true
        return 0
        ;;
      "n"|"no")
        secure_boot=false
        return 1
        ;;
      *)
      log_warn "Please answer yes or no."
        ;;
    esac
  done
}