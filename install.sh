#!/bin/bash

# Arch Linux Installation Script
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} \"$1\""
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} \"$1\""
}

print_error() {
    echo -e "${RED}[ERROR]${NC} \"$1\""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} \"$1\""
}

# Get partition information
print_info "Please provide partitions:"
read -p "Enter boot partition (e.g., /dev/nvme1n1p1 or /dev/sda1): " BOOT_PARTITION
read -p "Enter swap partition (e.g., /dev/nvme1n1p2 or /dev/sda2): " SWAP_PARTITION
read -p "Enter root partition (e.g., /dev/nvme1n1p3 or /dev/sda3): " ROOT_PARTITION

# Get username
read -p "Enter username for user: " USERNAME

# Validate inputs
if [[ ! -b "$BOOT_PARTITION" ]] || [[ ! -b "$SWAP_PARTITION" ]] || [[ ! -b "$ROOT_PARTITION" ]]; then
    print_error "One or more partitions don't exist!"
    exit 1
fi

if [[ -z "$USERNAME" ]]; then
    print_error "Username cannot be empty!"
    exit 1
fi

print_info "Configuration:"
echo "Boot partition: $BOOT_PARTITION"
echo "Swap partition: $SWAP_PARTITION"
echo "Root partition: $ROOT_PARTITION"
echo "Username: $USERNAME"
read -p "Continue with installation? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Format partitions
print_info "Formatting partitions..."
mkfs.fat -F 32 "$BOOT_PARTITION"
mkswap "$SWAP_PARTITION"
mkfs.ext4 "$ROOT_PARTITION"

# Mount partitions
print_info "Mounting partitions..."
mount "$ROOT_PARTITION" /mnt
mount --mkdir "$BOOT_PARTITION" /mnt/boot/efi
swapon "$SWAP_PARTITION"

# Install system
print_info "Installing packages (this may take a while)..."
pacstrap /mnt base linux linux-firmware intel-ucode sof-firmware base-devel grub efibootmgr nano networkmanager nvidia-dkms nvidia-settings nvidia-utils sbctl linux-headers os-prober ntfs-3g

# Generate file system tab
print_info "Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab

# Create chroot script
print_info "Creating chroot configuration script..."
cat > /mnt/chroot_script.sh << EOF
#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} \"$1\""
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} \"$1\""
}

print_error() {
    echo -e "${RED}[ERROR]${NC} \"$1\""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} \"$1\""
}

# Setup users and passwords
print_info "Setting up users and passwords..."
echo "Please enter root password:"
passwd

print_info "Creating user $USERNAME..."
useradd -m -G wheel -s /bin/bash $USERNAME
echo "Please enter password for user $USERNAME:"
passwd $USERNAME

# Setup sudo
print_info "Enabling sudo for wheel group..."
cp /etc/sudoers /etc/sudoers.bak
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
if visudo -c; then
    print_success "The sudoers file was successfully updated and validated."
    rm /etc/sudoers.bak
else
    print_error "There was an error in the sudoers file. Restoring the backup."
    cp /etc/sudoers.bak /etc/sudoers
    exit 1
fi

# Setup timezone and clock
print_info "Setting up timezone and clock..."
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

# Set locale
print_info "Configuring locale..."
sed -i '/^#en_GB.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Set hostname
print_info "Setting hostname..."
echo "arch" > /etc/hostname

# Enable core services
print_info "Enabling NetworkManager service..."
systemctl enable NetworkManager

# Setup NVIDIA drivers
print_info "Configuring NVIDIA drivers..."
nvidia-xconfig
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/".*"/"loglevel=3 nvidia-drm.modeset=1"/' /etc/default/grub
sed -i '/^MODULES=/s/)/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

print_info "Rebuilding initramfs..."
mkinitcpio -P

# Setup GRUB
print_info "Installing and configuring GRUB..."
grub-install $BOOT_PARTITION --disable-shim-lock --efi-directory=/boot/efi --modules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo play cpuid tpm cryptodisk luks lvm mdraid09 mdraid1x raid5rec raid6rec"
grub-mkconfig -o /boot/grub/grub.cfg

# Create secure boot setup script in user's home directory
print_info "Creating secure boot setup script..."
cat > /home/$USERNAME/setup_secure_boot.sh << SECURE_BOOT
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} \"$1\""
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} \"$1\""
}

print_error() {
    echo -e "${RED}[ERROR]${NC} \"$1\""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} \"$1\""
}

# Check if script is run as root
print_warning "Have you run this script as root? If not, press Ctrl+C and run it with sudo."
print_warning "If you have, press Enter to continue."
read -r

# Check if secure boot is in setup mode
print_info "Checking secure boot status..."
if ! bootctl status | grep -q "Secure Boot: disabled (setup)"; then
    print_error "Secure boot is not in setup mode!"
    print_warning "Please enter UEFI/BIOS setup and enable Setup Mode for secure boot"
    print_warning "This usually involves clearing/deleting secure boot keys"
    exit 1
fi

# Sign bootloader and kernel for secure boot
print_info "Setting up secure boot..."
sbctl create-keys
sbctl enroll-keys --microsoft
sbctl sign /boot/vmlinuz-linux
sbctl sign /boot/efi/EFI/arch/grubx64.efi

# Rebuild initramfs
mkinitcpio -P

print_info "Secure boot setup completed!"
print_warning "You can now delete this script using: rm ~/setup_secure_boot.sh"
print_success "Your Arch Linux system is now fully set up!"
SECURE_BOOT

chmod +x /home/$USERNAME/setup_secure_boot.sh
chown $USERNAME:$USERNAME /home/$USERNAME/setup_secure_boot.sh

print_info "Chroot configuration completed!"
EOF

# Make chroot script executable
chmod +x /mnt/chroot_script.sh

# Enter system and run configuration
print_info "Entering chroot environment..."

arch-chroot /mnt /chroot_script.sh

# Cleanup
rm /mnt/chroot_script.sh

# Final steps
print_info "Installation completed!"
print_warning "Please reboot and enable secure boot, then run the setup_secure_boot.sh script in the home directory as your user using: sudo ./setup_secure_boot.sh"

read -p "Reboot now? (y/N): " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    reboot
fi