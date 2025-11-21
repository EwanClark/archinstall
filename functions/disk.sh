#! /bin/bash
select_disk() {
  lsblk -o NAME,SIZE,TYPE
  read -r -p "Which disk would you like to use? " disk_input </dev/tty
  disk_input="${disk_input,,}"
  # Ensure disk is in /dev/$disk format
  if [[ "$disk_input" == /dev/* ]]; then
    disk="$disk_input"
  else
    disk="/dev/$disk_input"
  fi
  if [[ ! -b "$disk" ]]; then
    log_error "Invalid disk. Please try again."
    select_disk
  else
    log_success "Selected disk: $disk"
  fi
}

declare -a additional_partition_entries=()

boot_partition=""
swap_partition=""
root_partition=""
boot_manager_partition=""

is_reserved_mountpoint() {
  local candidate="$1"
  local reserved_paths=(
    "/"
    "/bin"
    "/boot"
    "/dev"
    "/etc"
    "/home"
    "/lib"
    "/lib64"
    "/mnt"
    "/opt"
    "/proc"
    "/root"
    "/run"
    "/srv"
    "/sys"
    "/tmp"
    "/usr"
    "/var"
  )
  for path in "${reserved_paths[@]}"; do
    if [[ "$candidate" == "$path" ]]; then
      return 0
    fi
  done
  return 1
}

make_partitions() {  
  log_blank
  log_title "Partitioning Guide for $disk"
  log_info "You need to create the following partitions:"
  log_blank
  log_info "1. EFI Boot Partition:"
  log_info "   - Size: 1 GiB"
  log_info "   - Stores the boot loader and will be mounted at /boot/efi"
  log_blank
  log_info "2. Swap Partition:"
  log_info "   - Size: match your RAM"
  log_info "   - Provides overflow space when memory is full"
  log_blank
  log_info "3. Root Partition (/):"
  log_info "   - Size: at least 20 GiB"
  log_info "   - Main filesystem mounted at /"
  log_blank
  log_info "4. (Optional) Additional partition (e.g. {homedir}/Documents)"
  log_info "   - Size: remaining space or whatever you prefer"

  log_blank
  log_title "How to use cfdisk"
  log_info "1. Use arrow keys to navigate"
  log_info "2. Select 'New' to create a partition"
  log_info "3. Enter the size (e.g., 512M for 512 MiB, 30G for 30 GiB)"
  log_info "4. Select the type (EFI System for boot, Linux swap, Linux filesystem)"
  log_info "5. Select 'Write' and type 'yes' to save changes"
  log_info "6. Select 'Quit' when done"
  log_blank
  read -r -p "Press Enter when you're ready to open cfdisk..." </dev/tty
  
  cfdisk $disk </dev/tty >/dev/tty 2>&1
  
  # Force kernel to re-read partition table
  partprobe $disk
  sleep 1
  
  log_blank
  log_info "Partitioning complete! Current layout:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT $disk
  log_blank
}

get_partitions() {
  additional_partition_entries=()
  boot_partition=""
  swap_partition=""
  root_partition=""

  local -a partition_names=()
  local -a partition_sizes=()
  local -a partition_fstypes=()
  declare -A partition_size_lookup=()
  declare -A partition_fstype_lookup=()

  mapfile -t partition_lines < <(lsblk -nP -p -o NAME,TYPE,SIZE,FSTYPE "$disk")

  local line
  for line in "${partition_lines[@]}"; do
    eval "$line"
    if [[ "$TYPE" != "part" ]]; then
      unset NAME TYPE SIZE FSTYPE
      continue
    fi
    partition_names+=("$NAME")
    partition_sizes+=("$SIZE")
    partition_fstypes+=("${FSTYPE:-unknown}")
    partition_size_lookup["$NAME"]="$SIZE"
    partition_fstype_lookup["$NAME"]="${FSTYPE:-unknown}"
    unset NAME TYPE SIZE FSTYPE
  done

  if ((${#partition_names[@]} < 3)); then
    log_error "At least three partitions are required (boot, swap, root)."
    log_info "Re-opening the partition tool so you can adjust the layout."
    make_partitions
    get_partitions
    return
  fi

  local -a extra_partitions=()

  rebuild_extra_partitions() {
    extra_partitions=()
    local idx
    for idx in "${!partition_names[@]}"; do
      local candidate="${partition_names[$idx]}"
      if [[ "$candidate" != "$boot_partition" && "$candidate" != "$swap_partition" && "$candidate" != "$root_partition" ]]; then
        extra_partitions+=("$candidate|${partition_sizes[$idx]}|${partition_fstypes[$idx]}")
      fi
    done
  }

  manual_partition_assignment() {
    log_blank
    log_title "Available partitions on $disk"
    local idx
    for idx in "${!partition_names[@]}"; do
      printf "  %2d) %s (%s, fs: %s)\n" $((idx + 1)) "${partition_names[$idx]}" "${partition_sizes[$idx]}" "${partition_fstypes[$idx]}"
    done

    local total="${#partition_names[@]}"
    local -a selections=()
    local -A used_indices=()
    local -a role_prompts=(
      "EFI boot partition (target ≈ 1 GiB)"
      "Swap partition (target ≈ your RAM size)"
      "Root partition / (target ≥ 20 GiB)"
    )

    local role_idx
    for role_idx in 0 1 2; do
      while true; do
        read -r -p "Select the ${role_prompts[$role_idx]} [1-$total or 'back']: " choice </dev/tty
        choice="${choice,,}"
        if [[ "$choice" == "back" || "$choice" == "b" ]]; then
          log_warn "Manual reassignment cancelled."
          return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          local selected_idx=$((choice - 1))
          if (( selected_idx < 0 || selected_idx >= total )); then
            log_warn "Please choose a number between 1 and $total."
            continue
          fi
          if [[ -n "${used_indices[$selected_idx]}" ]]; then
            log_warn "That partition has already been assigned."
            continue
          fi
          selections[$role_idx]=$selected_idx
          used_indices[$selected_idx]=1
          break
        fi
        log_warn "Please enter a valid number or 'back'."
      done
    done

    boot_partition="${partition_names[${selections[0]}]}"
    swap_partition="${partition_names[${selections[1]}]}"
    root_partition="${partition_names[${selections[2]}]}"
    rebuild_extra_partitions
    log_blank
    log_title "Updated partition mapping"
    log_info "  EFI boot -> $boot_partition"
    log_info "  Swap      -> $swap_partition"
    log_info "  Root      -> $root_partition"
    return 0
  }

  boot_partition="${partition_names[0]}"
  swap_partition="${partition_names[1]}"
  root_partition="${partition_names[2]}"
  rebuild_extra_partitions

  while true; do
    log_blank
    log_title "Guessed partition mapping"
    log_info "  Boot (≈1 GiB target): ${boot_partition:-unset} (${partition_size_lookup[$boot_partition]:-unknown})"
    log_info "  Swap (≈RAM target):   ${swap_partition:-unset} (${partition_size_lookup[$swap_partition]:-unknown})"
    log_info "  Root (≥20 GiB):       ${root_partition:-unset} (${partition_size_lookup[$root_partition]:-unknown})"
    log_blank
    log_info "Current lsblk output for $disk:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk"
    log_blank
    read -r -p "Is this mapping correct? [Y]es / [C]hange / [P]artition again: " confirmation </dev/tty
    confirmation="${confirmation,,}"
    case "$confirmation" in
      ""|"y"|"yes")
        break
        ;;
      "c"|"change")
        if manual_partition_assignment; then
          continue
        else
          log_info "No changes applied. Keeping the current mapping."
          continue
        fi
        ;;
      "p"|"partition"|"back")
        log_info "Re-opening the partition tool so you can make changes."
        make_partitions
        get_partitions
        return
        ;;
      *)
        log_warn "Please respond with 'y', 'c', or 'p'."
        ;;
    esac
  done

  log_title "Detected partitions on $disk"
  log_info "  EFI : $boot_partition"
  log_info "  Swap: $swap_partition"
  log_info "  Root: $root_partition"

  if ((${#extra_partitions[@]} == 0)); then
    return
  fi

  log_blank
  log_title "Additional partitions detected"
  local entry
  for entry in "${extra_partitions[@]}"; do
    IFS="|" read -r part_name part_size part_fstype <<< "$entry"
    while true; do
      read -r -p "Include $part_name ($part_size, filesystem: ${part_fstype:-unknown})? [y/N]: " include_partition </dev/tty
      include_partition="${include_partition,,}"
      if [[ -z "$include_partition" || "$include_partition" == "n" || "$include_partition" == "no" ]]; then
        log_info "Ignoring $part_name."
        break
      elif [[ "$include_partition" == "y" || "$include_partition" == "yes" ]]; then
        local fs="ext4"
        log_info "$part_name will be formatted as $fs."

        local mount_decision=""
        local mount_point=""
        while true; do
          read -r -p "Would you like to mount $part_name? [y/N]: " mount_decision </dev/tty
          mount_decision="${mount_decision,,}"
          if [[ -z "$mount_decision" || "$mount_decision" == "n" || "$mount_decision" == "no" ]]; then
            break
          elif [[ "$mount_decision" == "y" || "$mount_decision" == "yes" ]]; then
            while true; do
              read -r -p "Enter a mount point (use {homedir} to represent /home/\$username): " mount_point </dev/tty
              mount_point="${mount_point,,}"
              if [[ -z "$mount_point" ]]; then
                log_warn "Mount point cannot be empty."
                continue
              fi
              if [[ "$mount_point" != \{homedir\}* && "$mount_point" != /* ]]; then
                log_warn "Mount points must start with '/' or '{homedir}'."
                continue
              fi
              local validation_target="$mount_point"
              validation_target="${validation_target//\{homedir\}/\/home\/\$username}"
              if is_reserved_mountpoint "$validation_target"; then
                log_warn "That path already exists in the base system. Choose another directory."
                continue
              fi
              break
            done
            break
          else
            log_warn "Please answer yes or no."
          fi
        done

        additional_partition_entries+=("$part_name|$fs|$mount_point|${mount_decision:-no}")
        break
      else
        log_warn "Please answer yes or no."
      fi
    done
  done
}

format_partitions() {  
  mkfs.fat -F 32 $boot_partition
  mkswap $swap_partition
  mkfs.ext4 $root_partition

  if ((${#additional_partition_entries[@]} > 0)); then
    local entry
    for entry in "${additional_partition_entries[@]}"; do
      IFS="|" read -r part_name fs mount_point mount_decision <<< "$entry"
      if [[ -n "$part_name" && -n "$fs" ]]; then
        mkfs.$fs $part_name
      fi
    done
  fi
}

mount_partitions() {
  mount $root_partition /mnt
  mount --mkdir $boot_partition /mnt/boot/efi
  swapon $swap_partition
}

select_boot_manager_partition() {
  if [[ "${dual_boot:-false}" != "true" ]]; then
    return
  fi

  log_blank
  log_title "Boot Manager Partition for os-prober"
  while true; do
    read -r -p "Do you have another boot loader you want to mount? [y/N]: " choice </dev/tty
    choice="${choice,,}"
    if [[ -z "$choice" || "$choice" == "n" || "$choice" == "no" ]]; then
      return
    elif [[ "$choice" == "y" || "$choice" == "yes" ]]; then
      break
    else
      log_warn "Please answer yes or no."
    fi
  done

  log_blank
  log_info "Available partitions:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
  log_blank
  
  while true; do
    read -r -p "Enter the partition to mount (e.g., /dev/sda1): " boot_manager_partition </dev/tty
    if [[ -z "$boot_manager_partition" ]]; then
      log_warn "Partition cannot be empty."
      continue
    fi
    if [[ ! -b "$boot_manager_partition" ]]; then
      log_warn "Invalid partition. Please try again."
      continue
    fi
    log_success "Selected boot manager partition: $boot_manager_partition"
    break
  done
}

mount_boot_manager() {
  if [[ -n "$boot_manager_partition" ]]; then
    log_info "Mounting boot manager partition $boot_manager_partition for os-prober"
    mkdir -p /mnt/mnt
    if mount "$boot_manager_partition" /mnt/mnt 2>/dev/null; then
      log_success "Mounted boot manager partition at /mnt/mnt"
    else
      log_warn "Failed to mount boot manager partition. os-prober may not detect other OSes."
    fi
  fi
}

mount_additional_partitions() {
  if ((${#additional_partition_entries[@]} > 0)); then
    local entry
    for entry in "${additional_partition_entries[@]}"; do
      IFS="|" read -r part_name fs mount_point mount_decision <<< "$entry"
      if [[ -n "$part_name" && -n "$fs" && "$mount_decision" == "yes" && -n "$mount_point" ]]; then
        local expanded_mount_point="${mount_point//\{homedir\}/\/home\/$username}"
        mkdir -p "/mnt$expanded_mount_point"
        mount $part_name "/mnt$expanded_mount_point"
        log_success "Mounted $part_name at /mnt$expanded_mount_point"
      fi
    done
  fi
}

create_fstab() {
  genfstab -U /mnt > /mnt/etc/fstab
}