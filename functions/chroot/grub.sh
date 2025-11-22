#! /bin/bash

secure_boot_modules="
 all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo play cpuid tpm cryptodisk luks lvm mdraid09 mdraid1x raid5rec raid6rec 
"

prompt_boot_manager_mounts() {
  local mount_index=1
  while true; do
    log_blank
    log_title "Current block devices (lsblk)"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT

    local partition_input=""
    read -r -p "Partition to mount for another boot loader [or 'done']: " partition_input </dev/tty
    partition_input="${partition_input,,}"
    if [[ -z "$partition_input" || "$partition_input" == "done" || "$partition_input" == "skip" ]]; then
      log_info "Finished handling extra boot loader mounts."
      break
    fi

    local partition_path="$partition_input"
    if [[ "$partition_path" != /dev/* ]]; then
      partition_path="/dev/$partition_path"
    fi
    if [[ ! -b "$partition_path" ]]; then
      log_warn "$partition_path is not a valid block device."
      continue
    fi

    local target=""
    while true; do
      target="/mnt/$mount_index"
      if mountpoint -q "$target"; then
        mount_index=$((mount_index + 1))
        continue
      fi
      break
    done

    if mount --mkdir -o ro "$partition_path" "$target"; then
      log_success "Mounted $partition_path at $target (read-only)."
      mount_index=$((mount_index + 1))
    else
      log_error "Failed to mount $partition_path at $target."
    fi
  done
}

mount_another_boot_loader() {
  local manual_required="false"

  if command -v efibootmgr >/dev/null 2>&1; then
    local -a boot_entries=()
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      boot_entries+=("$entry")
    done < <(efibootmgr -v | grep -E '^Boot[0-9A-Fa-f]{4}')

    if ((${#boot_entries[@]} > 0)); then
      log_blank
      log_title "Detected EFI boot managers"
      local entry
      for entry in "${boot_entries[@]}"; do
        log_info "  $entry"
      done

      while true; do
        local wants_mount=""
        read -r -p "Need to mount any of these (or another) for GRUB detection? [y/N]: " wants_mount </dev/tty
        wants_mount="${wants_mount,,}"
        case "$wants_mount" in
          ""|"n"|"no")
            return
            ;;
          "y"|"yes")
            manual_required="true"
            break
            ;;
          *)
            log_warn "Please answer yes or no."
            ;;
        esac
      done
    else
      log_info "No EFI boot managers were reported by the firmware."
      manual_required="true"
    fi
  else
    log_warn "efibootmgr is unavailable; manual boot manager selection required."
    manual_required="true"
  fi

  if [[ "$manual_required" == "true" ]]; then
    prompt_boot_manager_mounts
  fi
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
}