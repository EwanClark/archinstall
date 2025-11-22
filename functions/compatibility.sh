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