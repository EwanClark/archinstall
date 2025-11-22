#! /bin/bash

secure_boot_modules="
 all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo play cpuid tpm cryptodisk luks lvm mdraid09 mdraid1x raid5rec raid6rec 
"

declare -a additional_boot_partitions=()
declare -a additional_boot_mountpoints=()

mount_another_boot_loader() {
  log_step "Mounting additional boot loader"
  log_blank
  while true; do
    read -r -p "Do you want grub to detect another boot loader? [y/N]: " choice </dev/tty
    local normalized_choice="${choice,,}"
    if [[ -z "$normalized_choice" || "$normalized_choice" == "n" || "$normalized_choice" == "no" ]]; then
      return
    elif [[ "$normalized_choice" == "y" || "$normalized_choice" == "yes" ]]; then
      break
    else
      log_warn "Please answer yes or no."
    fi
  done

  local selection=""
  local mounted_any=false
  local next_index=$(( ${#additional_boot_mountpoints[@]} + 1 ))

  while true; do
    log_blank
    log_title "Available partitions"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    log_blank

    read -r -p "Enter the partition you would like to mount (e.g., nvme0n1p3 or /dev/sda1) [or 'back']: " selection </dev/tty

    local normalized_selection="${selection,,}"
    if [[ -z "$normalized_selection" ]]; then
      log_warn "Please choose a partition or type 'back' to cancel."
      continue
    fi

    if [[ "$normalized_selection" == "back" || "$normalized_selection" == "b" || "$normalized_selection" == "skip" ]]; then
      if [[ "$mounted_any" == "true" ]]; then
        break
      else
        log_info "Skipping additional boot loader detection."
        return
      fi
    fi

    if [[ "$normalized_selection" != /dev/* ]]; then
      normalized_selection="/dev/$normalized_selection"
    fi

    if [[ ! -b "$normalized_selection" ]]; then
      log_error "Partition '$normalized_selection' does not exist. Please try again."
      continue
    fi

    local mount_dir="/mnt/$next_index"
    ((next_index++))

    mkdir -p "$mount_dir"
    if mountpoint -q "$mount_dir"; then
      umount "$mount_dir"
    fi

    if mount -o ro "$normalized_selection" "$mount_dir"; then
      additional_boot_partitions+=("$normalized_selection")
      additional_boot_mountpoints+=("$mount_dir")
      mounted_any=true
      log_success "Mounted $normalized_selection at $mount_dir"
    else
      log_error "Failed to mount $normalized_selection. Please try another partition."
      if [[ -d "$mount_dir" ]]; then
        rmdir "$mount_dir"
      fi
      # Reuse the mount_dir index since this mount failed.
      next_index=$((next_index - 1))
      continue
    fi

    while true; do
      read -r -p "Mount another partition for boot detection? [y/N]: " continue_choice </dev/tty
      local normalized_continue="${continue_choice,,}"
      if [[ -z "$normalized_continue" || "$normalized_continue" == "n" || "$normalized_continue" == "no" ]]; then
        return
      elif [[ "$normalized_continue" == "y" || "$normalized_continue" == "yes" ]]; then
        break
      else
        log_warn "Please answer yes or no."
      fi
    done
  done
}

cleanup_additional_boot_mounts() {
  log_step "Cleaning up additional boot mount points"
  log_blank
  local idx
  for idx in "${!additional_boot_mountpoints[@]}"; do
    local mountpoint="${additional_boot_mountpoints[$idx]}"
    if [[ -z "$mountpoint" ]]; then
      continue
    fi

    if mountpoint -q "$mountpoint"; then
      if umount "$mountpoint"; then
        log_info "Unmounted $mountpoint"
      else
        log_warn "Unable to unmount $mountpoint. Please unmount it manually."
        continue
      fi
    fi

    if [[ -d "$mountpoint" ]]; then
      if rmdir "$mountpoint"; then
        log_info "Removed $mountpoint"
      else
        log_warn "Unable to remove $mountpoint. Please remove it manually."
      fi
    fi
  done

  additional_boot_partitions=()
  additional_boot_mountpoints=()
}

grub() {
  if [[ "$dual_boot" == "true" ]]; then
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    mount_another_boot_loader
  fi
  if [[ "$secure_boot" == "true" ]]; then
    grub-install $boot_partition --efi-directory=/boot/efi --disable-shim-lock --modules="$secure_boot_modules"
  else
    grub-install $boot_partition --efi-directory=/boot/efi
  fi
  grub-mkconfig -o /boot/grub/grub.cfg

  cleanup_additional_boot_mounts
}