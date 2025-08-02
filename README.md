# Arch Linux Installation Script

A streamlined Arch Linux installation script with NVIDIA drivers and secure boot support.

## Installation

1. **Boot from Arch Linux ISO and connect to internet**
2. **Manually partition your disk** with EFI boot, swap, and root partitions
3. **Download and run the script:**
   ```bash
   curl -O https://raw.githubusercontent.com/yourusername/arch-install/main/install.sh
   chmod +x install.sh
   ./install.sh
   ```
4. **After reboot, enable secure boot setup mode in BIOS/UEFI**
5. **Run the secure boot script:**
   ```bash
   sudo ./setup_secure_boot.sh
   ```

## Settings

This script assumes and configures:
- **UEFI system** with secure boot capability
- **Intel CPU** (installs `intel-ucode`)
- **NVIDIA graphics card** with drivers
- **Ethernet connection** (NetworkManager enabled)
- **UK timezone** (Europe/London)
- **en_GB.UTF-8 locale**
- **Hostname:** `arch`
- **Packages:** Base system + NVIDIA drivers + GRUB + secure boot tools + development tools
- **Partitions:** You've manually created EFI boot, swap, and root partitions

**Note:** This is a personal script with opinionated defaults. Review and modify as needed for your setup.
