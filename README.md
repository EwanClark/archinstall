# Arch Linux Installation Script

A streamlined Arch Linux installation script with NVIDIA drivers and secure boot support.

---

## Installation

1. **Boot into the Arch Linux live ISO**  
   Start your system using the Arch Linux installation media.

2. **Connect to the internet**  
   Use `ping archlinux.org` to verify connectivity. If you're using Ethernet, it should work automatically.

3. **Partition your disk**  
   Use `lsblk` to view your disks and `cfdisk` to partition them. Refer to the table below for partition sizes:

   | Partition Type | Suggested Size         | Notes                                      |
   |----------------|------------------------|--------------------------------------------|
   | EFI Boot       | 512 MB - 1 GB          | Required for UEFI boot                    |
   | Swap           | 2 GB - 16 GB           | Match your RAM size                       |
   | Root           | Remaining space        | Main system partition. Use all space left |

   Example: For a 256 GB SSD, you might allocate:
   - 1 GB for EFI
   - 8 GB for Swap
   - ~247 GB for Root

4. **Install Git**  
   Run the following command to install Git:  
   ```bash
   sudo pacman -Sy git
   ```

5. **Clone the repository**  
   Download the script from the repository:  
   ```bash
   git clone https://github.com/ewanclark/archinstall
   ```

6. **View your partitions**  
   Before running the sciprt use `lsblk` to show partitions. This will be helpful when the script is running as you can't run commands:
   ```bash
   lsblk
   ```
   
7. **Run the installation script**  
   Navigate to the cloned directory, make the script executable, and run it. You will need to input partitions, usernames, and passwords:  
   ```bash
   cd archinstall
   chmod +x install.sh
   ./install.sh
   ```

8. **Reboot and enable secure boot setup mode**  
    After installation, reboot into your BIOS/UEFI settings and enable **Secure Boot Setup Mode**.

9. **Log into your Arch system**  
    Once booted into your new system, log in with the user credentials you created during installation.

10. **Run the secure boot setup script**  
    Complete the secure boot setup by running:  
    ```bash
    sudo ./setup_secure_boot.sh
    ```

---

## Settings

### Assumptions
This script assumes and configures:
- **UEFI system** with secure boot capability
- **Intel CPU** (installs `intel-ucode`)
- **NVIDIA graphics card** with proprietary drivers
- **Ethernet connection** (NetworkManager enabled)
- **UK timezone** (Europe/London)
- **en_GB.UTF-8 locale**
- **Hostname:** `arch`
- **Partitions:** You've manually created EFI boot, swap, and root partitions (swap is required)

### Installed Packages
The following packages will be installed:

```bash
base
linux
linux-firmware
base-devel
intel-ucode
grub
efibootmgr
os-prober
nvidia-dkms
nvidia-settings
nvidia-utils
sbctl
linux-headers
nano
networkmanager
sof-firmware
``` 

---

This script is designed for personal use with opinionated defaults. Review and modify as needed for your setup.
