# Arch Linux Installation Script

An automated Arch Linux installation script that simplifies the installation process with an interactive setup.

## Overview

An Arch Linux installation script that is easy to use and simple that include, disk partitioning, NVIDIA, secure boot, system configuration, and packages.

## Prerequisites

- Boot into Arch Linux live environment
- Internet connection
- UEFI system
- Basic knowledge of disk partitioning

## Usage

Run the installation script with:

```bash
curl -fsSL https://raw.githubusercontent.com/EwanClark/archinstall/main/install.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/EwanClark/archinstall.git
cd archinstall
chmod +x init.sh
./init.sh
```

## What It Does

The script will guide you through:

1. **System Compatibility Check** - Verifies UEFI boot mode
2. **Disk Setup** - Interactive disk selection and partitioning
3. **Partition Configuration** - Format and mount partitions (boot, swap, root)
4. **Base System Installation** - Install essential packages via pacstrap
5. **System Configuration** - Timezone, locale, hostname, user accounts
6. **Bootloader Setup** - GRUB installation and configuration
7. **Additional Features** - NVIDIA drivers, secure boot setup (optional)

## Features

- **Automatic Hardware Detection** - Detects Intel/AMD CPUs and installs appropriate microcode, automatically identifies NVIDIA GPUs and configures drivers
- **Interactive Disk Partitioning** - Uses cfdisk for easy partition layout creation with support for custom mount points
- **NVIDIA Support** - Automatically detects NVIDIA hardware and installs drivers with proper kernel parameters and module configuration
- **Secure Boot Ready** - Optional secure boot setup using sbctl with automated key generation and signing
- **Smart Package Selection** - Installs base system with essential packages tailored to your hardware
- **Automatic Configuration** - Generates fstab, enables NetworkManager, and sets up bootloader with os-prober support

## Notes

- The script is designed for single-user desktop installations
- Secure boot setup requires entering UEFI setup mode after installation
- All prompts are interactive - read carefully before proceeding

## Post-Installation

After the script completes:
1. Unmount partitions: `umount -R /mnt`
2. Reboot: `reboot`
3. If using secure boot, enter BIOS and enable setup mode, then run the secure boot setup script

## Disclaimer

This script will modify disk partitions. Use at your own risk.