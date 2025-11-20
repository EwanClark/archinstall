function check_compatibility() {
  if [[ ! -d /sys/firmware/efi ]]; then
    # System is not UEFI, failed compatibility
    echo "System is not UEFI, this script only supports UEFI systems."
    return 1
  fi

  # All checks passed
  return 0
}


# NVIDIA or AMD or Intel GPU
nvidia_or_amd_or_intel_gpu() {
  if [[ $(grep -c "NVIDIA" /proc/cpuinfo) -gt 0 ]]; then
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
  read -p "Do you want dual boot compatibility? [Y/n]: " dual_boot_compatibility
  dual_boot_compatibility="${dual_boot_compatibility,,}"
  if [[ -z "$dual_boot_compatibility" || "$dual_boot_compatibility" == "y" || "$dual_boot_compatibility" == "yes" ]]; then
    return 0
  fi
  return 1
}