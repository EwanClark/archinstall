# Arch Linux Installation Script

A streamlined Arch Linux installation script with NVIDIA drivers and secure boot support.

---

## Installation

1. **Boot into the Arch Linux live ISO**  
   Start your system using the Arch Linux installation media.

2. **Connect to the internet**  
   Check internet connection. If you're using Ethernet, it should work automatically:
   ```bash
   ping archlinux.org
   ```

### 3. **Partition Your Disk**

To prepare your disk for Arch Linux installation, follow these steps:

---

#### **Step 3.1: Identify the Disk**  
Use the `lsblk` command to list all available storage devices. Look for the disk you want to install Arch Linux on. Pay attention to the size and name of the disk to ensure you select the correct one.

```bash
lsblk
```

Example output:
```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0 931.5G  0 disk
├─sda1        8:1    0 512.0M  0 part
├─sda2        8:2    0 27.0G   0 part
nvme0n1     259:0    0 256.0G  0 disk
```

In this example:
- The disk `nvme0n1` is a 256 GB SSD, which is likely the target for installation.
- The `sda` disk is the Arch Linux live install USB.

---

#### **Step 3.2: Partition the Disk**  
Once you've identified the correct disk, use the `cfdisk` command to partition it. Replace `<disk>` with the name of the disk you found in the `lsblk` output (e.g., `/dev/nvme0n1`).

```bash
cfdisk /dev/<disk>
```

Example:
```bash
cfdisk /dev/nvme0n1
```
---

#### **Step 3.3: Create Partitions**  
Use the table below as a guide for partitioning your disk:

| Partition Type | Suggested Size         | Notes                                      |
|----------------|------------------------|--------------------------------------------|
| EFI Boot       | 512 MB - 1 GB          | Required for UEFI boot                    |
| Swap           | 2 GB - 16 GB           | Match your RAM size                       |
| Root           | Remaining space        | Main system partition. Use all space left |

Example for a 256 GB SSD:
- **EFI Boot**: 1 GB
- **Swap**: 8 GB
- **Root**: ~247 GB

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
