#! /bin/bash

# Base packages
packages=(
  base
  linux
  linux-firmware
  linux-headers
  sof-firmware
  base-devel
  grub
  efibootmgr
  networkmanager
  nano
  git
  less
)

# NVIDIA GPU packages
nvidia_gpu_packages=(
  nvidia
  nvidia-settings
  nvidia-utils
)

# AMD and Intel GPU packages
amd_intel_gpu_packages=(
  mesa
)

# Intel CPU packages
intel_cpu_packages=(
  intel-ucode
)

# AMD CPU packages
amd_cpu_packages=(
  amd-ucode
)

# Dual boot packages
dual_boot_packages=(
  os-prober
)

secure_boot_packages=(
  sbctl
)

detect_packages() {
  # Detect GPU
  local use_nvidia=false
  if nvidia_or_amd_or_intel_gpu; then
    use_nvidia=true
  fi

  # Detect CPU
  local use_intel=false
  if intel_or_amd_cpu; then
    use_intel=true
  fi

  # Default dual boot and secure boot to true
  local use_dual_boot=true
  local use_secure_boot=true

  # Show overview and get user confirmation
  while true; do
    log_blank
    log_title "=== Package Configuration Overview ==="
    log_info "1. GPU:         $([ "$use_nvidia" = true ] && printf "NVIDIA" || printf "AMD/Intel")"
    log_info "2. CPU:         $([ "$use_intel" = true ] && printf "Intel" || printf "AMD")"
    log_info "3. Dual Boot:   $([ "$use_dual_boot" = true ] && printf "Enabled" || printf "Disabled")"
    log_info "4. Secure Boot: $([ "$use_secure_boot" = true ] && printf "Enabled" || printf "Disabled")"
    log_blank
    log_info "Note: Dual Boot and Secure Boot can be enabled for compatibility even if not currently needed."
    log_blank
    log_info "Press Enter to continue, or enter a number (1-4) to switch between options:"
    
    read -r choice </dev/tty
    
    case "$choice" in
      "")
        # User pressed Enter, continue with current settings
        break
        ;;
      1)
        # Toggle GPU
        if [ "$use_nvidia" = true ]; then
          use_nvidia=false
        else
          use_nvidia=true
        fi
        ;;
      2)
        # Toggle CPU
        if [ "$use_intel" = true ]; then
          use_intel=false
        else
          use_intel=true
        fi
        ;;
      3)
        # Toggle dual boot
        if [ "$use_dual_boot" = true ]; then
          use_dual_boot=false
        else
          use_dual_boot=true
        fi
        ;;
      4)
        # Toggle secure boot
        if [ "$use_secure_boot" = true ]; then
          use_secure_boot=false
        else
          use_secure_boot=true
        fi
        ;;
      *)
        log_warn "Invalid choice. Please enter 1-4 or press Enter to continue."
        ;;
    esac
  done

  # Add packages based on selections
  if [ "$use_nvidia" = true ]; then
    packages+=("${nvidia_gpu_packages[@]}")
  else
    packages+=("${amd_intel_gpu_packages[@]}")
  fi

  if [ "$use_intel" = true ]; then
    packages+=("${intel_cpu_packages[@]}")
  else
    packages+=("${amd_cpu_packages[@]}")
  fi

  if [ "$use_dual_boot" = true ]; then
    packages+=("${dual_boot_packages[@]}")
  fi

  if [ "$use_secure_boot" = true ]; then
    packages+=("${secure_boot_packages[@]}")
  fi
}

# Install the packages
install_packages() {
  pacstrap /mnt "${packages[@]}"
}