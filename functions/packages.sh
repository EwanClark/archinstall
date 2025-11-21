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
  if nvidia_or_amd_or_intel_gpu; then
    packages+=("${nvidia_gpu_packages[@]}")
  else
    packages+=("${amd_intel_gpu_packages[@]}")
  fi

  if intel_or_amd_cpu; then
    packages+=("${intel_cpu_packages[@]}")
  else
    packages+=("${amd_cpu_packages[@]}")
  fi

  if dual_boot_compatibility; then
    packages+=("${dual_boot_packages[@]}")
  fi

  if secure_boot_compatibility; then
    packages+=("${secure_boot_packages[@]}")
  fi
}

# Install the packages
install_packages() {
  pacstrap /mnt "${packages[@]}"
}