#! /bin/bash

interactive_timezone_browser() {
  local -n _timezones_ref=$1
  local tty="/dev/tty"
  local page_size=20
  local page=0
  local selection=""
  local -a active_indices=("${!_timezones_ref[@]}")

  if (( ${#_timezones_ref[@]} == 0 )); then
    printf "No timezone data available to display.\n" >"$tty"
    return 1
  fi

  while true; do
    local total_active=${#active_indices[@]}
    if (( total_active == 0 )); then
      printf "\nNo matches found. Use 'a' to reset or 'q' to quit.\n" >"$tty"
    else
      local start=$((page * page_size))
      if (( start >= total_active )); then
        page=0
        start=0
      fi
      local end=$((start + page_size))
      if (( end > total_active )); then
        end=$total_active
      fi
      printf "\nShowing timezones %d-%d of %d (of %d total)\n" $((start + 1)) $end $total_active ${#_timezones_ref[@]} >"$tty"
      for ((i=start; i<end; i++)); do
        local idx=${active_indices[i]}
        printf "%4d) %s\n" $((idx + 1)) "${_timezones_ref[idx]}" >"$tty"
      done
    fi
    printf "\nOptions: [Enter/n] next  [p] prev  [s] search  [a] all  [q] quit  [#] select\n" >"$tty"
    read -r -p "Choice: " choice </dev/tty
    if [[ -z "$choice" ]]; then
      choice="n"
    fi
    case "$choice" in
      n|N)
        if (( total_active > 0 && (page + 1) * page_size < total_active )); then
          ((page++))
        else
          page=0
        fi
        ;;
      p|P)
        if (( page > 0 )); then
          ((page--))
        else
          page=$(( (total_active + page_size - 1) / page_size - 1 ))
          if (( page < 0 )); then
            page=0
          fi
        fi
        ;;
      s|S)
        read -r -p "Search term (case-insensitive): " term </dev/tty
        term="${term,,}"
        active_indices=()
        if [[ -z "$term" ]]; then
          active_indices=("${!_timezones_ref[@]}")
        else
          for idx in "${!_timezones_ref[@]}"; do
            if [[ "${_timezones_ref[idx],,}" == *"$term"* ]]; then
              active_indices+=("$idx")
            fi
          done
        fi
        page=0
        ;;
      a|A)
        active_indices=("${!_timezones_ref[@]}")
        page=0
        ;;
      q|Q)
        break
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          local num=$choice
          if (( num >= 1 && num <= ${#_timezones_ref[@]} )); then
            selection="${_timezones_ref[num-1]}"
            printf "Selected timezone: %s\n" "$selection" >"$tty"
            printf "%s" "$selection"
            return 0
          fi
          printf "Number outside valid range.\n" >"$tty"
        else
          printf "Unknown option.\n" >"$tty"
        fi
        ;;
    esac
  done

  return 1
}

timezone() {
  log_info "Setting timezone configuration"
  local -a available_timezones=()
  if ! mapfile -t available_timezones < <(timedatectl list-timezones); then
    log_error "Failed to retrieve timezones from timedatectl."
    return 1
  fi
  if (( ${#available_timezones[@]} == 0 )); then
    log_error "No timezones were returned by timedatectl."
    return 1
  fi

  local timezone_input=""
  local resolved_timezone=""
  local browse_selection=""

  read -r -p "Would you like to browse available timezones first? [Y/n]: " browse_choice </dev/tty
  browse_choice="${browse_choice,,}"
  if [[ "$browse_choice" != "n" && "$browse_choice" != "no" ]]; then
    browse_selection=$(interactive_timezone_browser available_timezones)
    if [[ -n "$browse_selection" ]]; then
      timezone_input="$browse_selection"
    fi
  fi

  while true; do
    if [[ -z "$timezone_input" ]]; then
      read -r -p "Enter your timezone (type 'list' to browse): " timezone_input </dev/tty
    fi
    if [[ -z "$timezone_input" ]]; then
      log_error "Timezone cannot be empty."
      continue
    fi
    if [[ "${timezone_input,,}" == "list" ]]; then
      browse_selection=$(interactive_timezone_browser available_timezones)
      timezone_input="$browse_selection"
      continue
    fi
    resolved_timezone=""
    for tz in "${available_timezones[@]}"; do
      if [[ "${tz,,}" == "${timezone_input,,}" ]]; then
        resolved_timezone="$tz"
        break
      fi
    done
    if [[ -z "$resolved_timezone" ]]; then
      log_error "Invalid timezone. Please try again."
      read -r -p "Would you like to browse the timezone list? [Y/n]: " browse_retry </dev/tty
      browse_retry="${browse_retry,,}"
      if [[ "$browse_retry" != "n" && "$browse_retry" != "no" ]]; then
        browse_selection=$(interactive_timezone_browser available_timezones)
        timezone_input="$browse_selection"
      else
        timezone_input=""
      fi
      continue
    fi
    ln -sf "/usr/share/zoneinfo/$resolved_timezone" /etc/localtime
    hwclock --systohc
    break
  done
}

locale() {
  read -r -p "Would you like a custom locale (default is en_us) [y/N]: " custom_locale </dev/tty
  custom_locale="${custom_locale,,}"
  if [[ "$custom_locale" == "y" || "$custom_locale" == "yes" ]]; then
    read -r -p "Press enter to be taken to the file to uncomment the locale you want to use" </dev/tty
    nano /etc/locale.gen </dev/tty >/dev/tty 2>&1
    read -r -p "Have you uncommented the locale you want to use? [Y/n]: " uncommented_locale </dev/tty
    uncommented_locale="${uncommented_locale,,}"
    if [[ "$uncommented_locale" == "n" || "$uncommented_locale" == "no" ]]; then
      log_info "Re-running the locale selection."
      locale
    fi
    locale-gen
    locale=$(grep -v '^#' /etc/locale.gen | grep -v '^$' | head -n 1 | awk '{print $1}')
    echo "LANG=$locale" > /etc/locale.conf
  else
    sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
  fi
}

hostname() {
  local hostname_value=""
  while true; do
    read -r -p "Enter hostname (default is arch): " hostname_input </dev/tty
    if [[ -z "$hostname_input" ]]; then
      hostname_value="arch"
      break
    fi
    if [[ "$hostname_input" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?$ ]]; then
      hostname_value="$hostname_input"
      break
    fi
    log_error "Hostnames must be 1-63 characters, start/end with alphanumeric, and may include '-' in the middle."
  done
  echo "$hostname_value" > /etc/hostname
}

keyboard_layout() {
  read -r -p "Would you like to set a custom keyboard layout (default is us) [y/N]: " custom_keyboard_layout </dev/tty
  custom_keyboard_layout="${custom_keyboard_layout,,}"
  if [[ "$custom_keyboard_layout" == "y" || "$custom_keyboard_layout" == "yes" ]]; then
    log_info "Listing available keyboard layouts"
    read -r -p "Press enter to see all available keyboard layouts" </dev/tty
    localectl list-keymaps | less </dev/tty >/dev/tty 2>&1
    local keyboard_layout_input=""
    local resolved_keymap=""
    while true; do
      read -r -p "Enter your keyboard layout (e.g. us, de, fr): " keyboard_layout_input </dev/tty
      keyboard_layout_input="${keyboard_layout_input,,}"
      if [[ -z "$keyboard_layout_input" ]]; then
        log_error "Keyboard layout cannot be empty."
        continue
      fi
      resolved_keymap=$(localectl list-keymaps | awk -v target="$keyboard_layout_input" 'tolower($0)==tolower(target) {print $0; exit}')
      if [[ -z "$resolved_keymap" ]]; then
        log_error "Invalid keyboard layout. Please try again."
        continue
      fi
      echo "KEYMAP=$resolved_keymap" > /etc/vconsole.conf
      break
    done
  else
    echo "KEYMAP=us" > /etc/vconsole.conf
  fi
}
