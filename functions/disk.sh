select_disk() {
  lsblk -o NAME,SIZE,TYPE
  read -p "Which disk would you like to use? " disk_input
  # Ensure disk is in /dev/$disk format
  if [[ "$disk_input" == /dev/* ]]; then
    disk="$disk_input"
  else
    disk="/dev/$disk_input"
  fi
  if [[ ! -b "$disk" ]]; then
    echo "Invalid disk. Please try again."
    select_disk
  else
    echo "Selected disk: $disk"
  fi
}

declare -a additional_partition_entries=()

boot_partition=""
swap_partition=""
root_partition=""

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
  echo ""
  echo "=========================================="
  echo "Partitioning Guide for $disk"
  echo "=========================================="
  echo ""
  echo "You need to create the following partitions:"
  echo ""
  echo "1. EFI Boot Partition:"
  echo "   - Size: 1 GiB"
  echo "   - This is used to store the boot loader and will be mounted at /boot/efi"
  echo ""
  echo "2. Swap Partition:"
  echo "   - Size: Equal to your RAM size"
  echo "   - This is used to swap memory from RAM to disk when memory is full"
  echo ""
  echo "3. Root Partition (/):"
  echo "   - Size: At least 20 GiB"
  echo "   - This is your main filesystem and will be mounted at /"
  echo ""
  echo "4. (Optional) Make an Additional Partition: (\$homedir/Documents, etc.)"
  echo "   - Size: Remaining space or as much as you want"
  echo ""
  
  echo "=========================================="
  echo "How to use cfdisk:"
  echo "=========================================="
  echo ""
  echo "1. Use arrow keys to navigate"
  echo "2. Select 'New' to create a partition"
  echo "3. Enter the size (e.g., '512M' for 512 MiB, '30G' for 30 GiB)"
  echo "5. Make sure to select 'Write' and type 'yes' to save changes"
  echo "6. Select 'Quit' when done"
  echo ""
  read -p "Press Enter when you're ready to open cfdisk..."
  
  cfdisk $disk
  
  echo ""
  echo "Partitioning complete! Showing current partition layout:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT $disk
  echo ""
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

  mapfile -t partition_lines < <(lsblk -lnP -p -o NAME,TYPE,SIZE,FSTYPE "$disk")

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
    echo "At least three partitions are required (boot, swap, root)."
    echo "Launching the partition tool again so you can adjust the layout."
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
    echo ""
    echo "Available partitions on $disk:"
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
        read -p "Select the ${role_prompts[$role_idx]} [1-$total or 'back']: " choice
        choice="${choice,,}"
        if [[ "$choice" == "back" || "$choice" == "b" ]]; then
          echo "Manual reassignment cancelled."
          return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          local selected_idx=$((choice - 1))
          if (( selected_idx < 0 || selected_idx >= total )); then
            echo "Please choose a number between 1 and $total."
            continue
          fi
          if [[ -n "${used_indices[$selected_idx]}" ]]; then
            echo "That partition has already been assigned."
            continue
          fi
          selections[$role_idx]=$selected_idx
          used_indices[$selected_idx]=1
          break
        fi
        echo "Please enter a valid number or 'back'."
      done
    done

    boot_partition="${partition_names[${selections[0]}]}"
    swap_partition="${partition_names[${selections[1]}]}"
    root_partition="${partition_names[${selections[2]}]}"
    rebuild_extra_partitions
    echo ""
    echo "Updated partition mapping:"
    echo "  EFI boot -> $boot_partition"
    echo "  Swap      -> $swap_partition"
    echo "  Root      -> $root_partition"
    return 0
  }

  boot_partition="${partition_names[0]}"
  swap_partition="${partition_names[1]}"
  root_partition="${partition_names[2]}"
  rebuild_extra_partitions

  while true; do
    echo ""
    echo "Guessing partitions based on order and expected sizes:"
    echo "  Boot (≈1 GiB target): ${boot_partition:-unset} (${partition_size_lookup[$boot_partition]:-unknown})"
    echo "  Swap (≈RAM target):   ${swap_partition:-unset} (${partition_size_lookup[$swap_partition]:-unknown})"
    echo "  Root (≥20 GiB):       ${root_partition:-unset} (${partition_size_lookup[$root_partition]:-unknown})"
    echo ""
    echo "Current lsblk output for $disk:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk"
    echo ""
    read -p "Is this mapping correct? [Y]es / [C]hange / [P]artition again: " confirmation
    confirmation="${confirmation,,}"
    case "$confirmation" in
      ""|"y"|"yes")
        break
        ;;
      "c"|"change")
        if manual_partition_assignment; then
          continue
        else
          echo "No changes applied. Keeping the current mapping."
          continue
        fi
        ;;
      "p"|"partition"|"back")
        echo "Re-opening the partition tool so you can make changes."
        make_partitions
        get_partitions
        return
        ;;
      *)
        echo "Please respond with 'y', 'c', or 'p'."
        ;;
    esac
  done

  echo "Detected the following partitions on $disk:"
  echo "  EFI : $boot_partition"
  echo "  Swap: $swap_partition"
  echo "  Root: $root_partition"

  if ((${#extra_partitions[@]} == 0)); then
    return
  fi

  echo ""
  echo "Additional partitions were found."
  local entry
  for entry in "${extra_partitions[@]}"; do
    IFS="|" read -r part_name part_size part_fstype <<< "$entry"
    while true; do
      read -p "Include $part_name ($part_size, filesystem: ${part_fstype:-unknown})? [y/N]: " include_partition
      include_partition="${include_partition,,}"
      if [[ -z "$include_partition" || "$include_partition" == "n" || "$include_partition" == "no" ]]; then
        echo "Ignoring $part_name."
        break
      elif [[ "$include_partition" == "y" || "$include_partition" == "yes" ]]; then
        local fs="ext4"
        echo "$part_name will be formatted as $fs."

        local mount_decision=""
        local mount_point=""
        while true; do
          read -p "Would you like to mount $part_name? [y/N]: " mount_decision
          mount_decision="${mount_decision,,}"
          if [[ -z "$mount_decision" || "$mount_decision" == "n" || "$mount_decision" == "no" ]]; then
            break
          elif [[ "$mount_decision" == "y" || "$mount_decision" == "yes" ]]; then
            while true; do
              read -p "Enter a mount point (use {homedir} to represent /home/\$username): " mount_point
              if [[ -z "$mount_point" ]]; then
                echo "Mount point cannot be empty."
                continue
              fi
              if [[ "$mount_point" != \{homedir\}* && "$mount_point" != /* ]]; then
                echo "Mount points must start with '/' or '{homedir}'."
                continue
              fi
              local validation_target="$mount_point"
              validation_target="${validation_target//\{homedir\}/\/home\/\$username}"
              if is_reserved_mountpoint "$validation_target"; then
                echo "That path already exists in the base system. Choose another directory."
                continue
              fi
              break
            done
            break
          else
            echo "Please answer yes or no."
          fi
        done

        additional_partition_entries+=("$part_name|$fs|$mount_point|${mount_decision:-no}")
        break
      else
        echo "Please answer yes or no."
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

mount_additional_partitions() {
  if ((${#additional_partition_entries[@]} > 0)); then
    local entry
    for entry in "${additional_partition_entries[@]}"; do
      IFS="|" read -r part_name fs mount_point mount_decision <<< "$entry"
      if [[ -n "$part_name" && -n "$fs" && "$mount_decision" == "yes" && -n "$mount_point" ]]; then
        mount $part_name $mount_point
      fi
    done
  fi
}