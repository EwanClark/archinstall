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
  # Normalize to avoid trailing slashes causing false negatives (keep / as-is)
  if [[ "$candidate" != "/" ]]; then
    candidate="${candidate%/}"
  fi
  local -a strict_reserved_paths=(
    "/"
    "/bin"
    "/boot"
    "/dev"
    "/etc"
    "/lib"
    "/lib64"
    "/proc"
    "/root"
    "/run"
    "/sys"
    "/usr"
  )
  local -a exact_only_paths=(
    "/mnt"
    "/opt"
    "/srv"
    "/tmp"
    "/var"
  )
  local path normalized_path
  for path in "${strict_reserved_paths[@]}"; do
    normalized_path="$path"
    if [[ "$normalized_path" != "/" ]]; then
      normalized_path="${normalized_path%/}"
    fi
    if [[ "$candidate" == "$normalized_path" ]]; then
      return 0
    fi
    if [[ "$normalized_path" != "/" && "$candidate" == "$normalized_path"/* ]]; then
      return 0
    fi
  done
  for path in "${exact_only_paths[@]}"; do
    normalized_path="$path"
    if [[ "$normalized_path" != "/" ]]; then
      normalized_path="${normalized_path%/}"
    fi
    if [[ "$candidate" == "$normalized_path" ]]; then
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
  log_info "4. (Optional) Additional partition (e.g. {home}/Documents)"
  log_info "   - Size: remaining space or whatever you prefer"

  log_blank
  log_title "How to use cfdisk"
  log_info "1. Cfdisk may ask for a partition table type, pick GPT. This prompt may not appear."
  log_info "2. Use arrow keys to navigate"
  log_info "3. Select 'New' to create a partition"
  log_info "4. Enter the size (e.g., 512M for 512 MiB, 30G for 30 GiB)"
  log_info "5. Select the type (EFI System for boot, Linux swap, Linux filesystem)"
  log_info "6. Select 'Write' and type 'yes' to save changes"
  log_info "7. Select 'Quit' when done"
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

  offer_additional_partitions() {
    local has_extra_on_disk=0
    local has_other_device=0

    if ((${#extra_partitions[@]} > 0)); then
      has_extra_on_disk=1
    fi

    while IFS= read -r device_line; do
      eval "$device_line"
      if [[ "$TYPE" == "disk" && "$NAME" != "$disk" ]]; then
        has_other_device=1
        unset NAME TYPE
        break
      fi
      unset NAME TYPE
    done < <(lsblk -nP -p -o NAME,TYPE)

    if (( !has_extra_on_disk && !has_other_device )); then
      return
    fi

    log_blank
    log_title "Optional additional partitions"
    log_info "Detected other devices or unused partitions."
    log_info "Enter partitions to include (press Enter or 'no' to finish)."

    declare -A used_partitions=()
    [[ -n "$boot_partition" ]] && used_partitions["$boot_partition"]=1
    [[ -n "$swap_partition" ]] && used_partitions["$swap_partition"]=1
    [[ -n "$root_partition" ]] && used_partitions["$root_partition"]=1
    local entry existing_part
    for entry in "${additional_partition_entries[@]}"; do
      IFS="|" read -r existing_part _ <<< "$entry"
      if [[ -n "$existing_part" ]]; then
        used_partitions["$existing_part"]=1
      fi
    done

    print_filtered_lsblk() {
      log_info "Current block devices (excluding assigned Arch partitions):"
      printf "  %-22s %-8s %-10s %s\n" "NAME" "SIZE" "FSTYPE" "MOUNTPOINT"

      declare -A node_size=()
      declare -A node_type=()
      declare -A node_fs=()
      declare -A node_mount=()
      declare -A disk_children=()
      declare -A skip_nodes=()
      declare -a disk_order=()

      while IFS= read -r device_line; do
        eval "$device_line"
        local name="$NAME"
        local parent="$PKNAME"
        local type="$TYPE"
        local should_skip=0
        if [[ -n "$MOUNTPOINT" && "$MOUNTPOINT" == /run/archiso* ]]; then
          should_skip=1
        elif [[ -n "$parent" && -n "${skip_nodes[$parent]+x}" ]]; then
          should_skip=1
        fi
        if (( should_skip )); then
          skip_nodes["$name"]=1
          unset NAME PKNAME TYPE SIZE FSTYPE MOUNTPOINT
          continue
        fi

        node_size["$name"]="${SIZE:-unknown}"
        node_type["$name"]="${type:-?}"
        node_fs["$name"]="${FSTYPE:-unknown}"
        node_mount["$name"]="${MOUNTPOINT:--}"

        if [[ "$type" == "disk" ]]; then
          disk_order+=("$name")
        fi
        if [[ -n "$parent" ]]; then
          disk_children["$parent"]+="$name "
        fi

        unset NAME PKNAME TYPE SIZE FSTYPE MOUNTPOINT
      done < <(lsblk -nP -p -o NAME,PKNAME,TYPE,SIZE,FSTYPE,MOUNTPOINT)

      local printed_any=0
      local disk
      for disk in "${disk_order[@]}"; do
        if [[ -n "${skip_nodes[$disk]+x}" ]]; then
          continue
        fi
        local disk_size="${node_size[$disk]:-unknown}"
        printf "  %s (%s disk)\n" "$disk" "$disk_size"
        printed_any=1

        local child_list="${disk_children[$disk]-}"
        local -a visible_children=()
        local child
        for child in $child_list; do
          if [[ -n "${skip_nodes[$child]+x}" ]]; then
            continue
          fi
          if [[ "${node_type[$child]}" != "part" ]]; then
            continue
          fi
          if [[ -n "${used_partitions[$child]+x}" ]]; then
            continue
          fi
          visible_children+=("$child")
        done

        if ((${#visible_children[@]} == 0)); then
          printf "    (no available partitions on this disk)\n"
          continue
        fi

        local child
        for child in "${visible_children[@]}"; do
          printf "    | %-18s %-8s %-10s %s\n" "$child" "${node_size[$child]:-unknown}" "${node_fs[$child]:-unknown}" "${node_mount[$child]:--}"
        done
      done

      if (( !printed_any )); then
        printf "  (no eligible devices detected)\n"
      fi
    }

    while true; do
      log_blank
      print_filtered_lsblk
      read -r -p "Partition to include (Enter or 'no' to finish): " partition_choice </dev/tty
      partition_choice="${partition_choice//[$'\t\r\n ']}"
      local normalized_choice="${partition_choice,,}"
      if [[ -z "$normalized_choice" || "$normalized_choice" == "no" ]]; then
        log_info "Finished selecting additional partitions."
        break
      fi
      if [[ "$normalized_choice" != /dev/* ]]; then
        normalized_choice="/dev/$normalized_choice"
      fi
      local target_partition="$normalized_choice"

      if [[ -n "${used_partitions[$target_partition]+x}" ]]; then
        log_warn "$target_partition is already assigned."
        continue
      fi

      if [[ ! -b "$target_partition" ]]; then
        log_warn "$target_partition does not exist."
        continue
      fi

      local part_type
      part_type=$(lsblk -no TYPE "$target_partition" 2>/dev/null)
      if [[ "$part_type" != "part" ]]; then
        log_warn "$target_partition is not a partition."
        continue
      fi

      local part_info
      local part_size="unknown"
      local part_fstype="unknown"
      part_info=$(lsblk -nP -p -o NAME,SIZE,FSTYPE "$target_partition" 2>/dev/null | head -n1)
      if [[ -n "$part_info" ]]; then
        eval "$part_info"
        part_size="${SIZE:-unknown}"
        part_fstype="${FSTYPE:-unknown}"
        unset NAME SIZE FSTYPE
      fi
      log_info "Selected $target_partition ($part_size, filesystem: $part_fstype)"

      local fs="ext4"
      log_info "$target_partition will be formatted as $fs."

      local should_mount="no"
      local mount_point=""
      while true; do
        read -r -p "Where should $target_partition be mounted? (use {home} for /home/\$username, Enter or 'no' to skip): " mount_point </dev/tty
        mount_point="${mount_point,,}"
        if [[ -z "$mount_point" || "$mount_point" == "no" ]]; then
          should_mount="no"
          mount_point=""
          break
        fi
        if [[ "$mount_point" != \{home\}* && "$mount_point" != /* ]]; then
          log_warn "Mount points must start with '/' or '{home}'."
          continue
        fi
        local validation_target="$mount_point"
        validation_target="${validation_target//\{home\}/\/home\/\$username}"
        if is_reserved_mountpoint "$validation_target"; then
          log_warn "That path already exists in the base system. Choose another directory."
          continue
        fi
        should_mount="yes"
        break
      done

      additional_partition_entries+=("$target_partition|$fs|$mount_point|$should_mount")
      used_partitions["$target_partition"]=1
      log_success "Queued $target_partition for inclusion."
    done
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
  offer_additional_partitions
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

mount_additional_partitions() {
  if ((${#additional_partition_entries[@]} > 0)); then
    local entry
    for entry in "${additional_partition_entries[@]}"; do
      IFS="|" read -r part_name fs mount_point mount_decision <<< "$entry"
      if [[ -n "$part_name" && -n "$fs" && "$mount_decision" == "yes" && -n "$mount_point" ]]; then
        local expanded_mount_point="${mount_point//\{home\}/\/home\/$username}"
        mkdir -p "/mnt$expanded_mount_point"
        mount $part_name "/mnt$expanded_mount_point"
        log_info "Mounted $part_name at /mnt$expanded_mount_point"
      fi
    done
  fi
}

create_fstab() {
  genfstab -U /mnt > /mnt/etc/fstab
}
