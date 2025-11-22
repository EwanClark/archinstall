#! /bin/bash

secure_boot_modules="
 all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo play cpuid tpm cryptodisk luks lvm mdraid09 mdraid1x raid5rec raid6rec 
"

grub() {
  if [[ "$dual_boot" == "true" ]]; then
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  fi
  if [[ "$secure_boot" == "true" ]]; then
    grub-install $boot_partition --efi-directory=/boot/efi --disable-shim-lock --modules="$secure_boot_modules"
  else
    grub-install $boot_partition --efi-directory=/boot/efi
  fi
  grub-mkconfig -o /boot/grub/grub.cfg
}