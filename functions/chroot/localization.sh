#! /bin/bash

if ! declare -F interactive_list_browser >/dev/null 2>&1; then
  _localization_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_localization_dir}/../browser.sh" ]]; then
    # shellcheck source=../browser.sh
    source "${_localization_dir}/../browser.sh"
  fi
  unset _localization_dir
fi

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
    browse_selection=$(interactive_list_browser "timezone" "timezones" available_timezones)
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
      browse_selection=$(interactive_list_browser "timezone" "timezones" available_timezones)
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
        browse_selection=$(interactive_list_browser "timezone" "timezones" available_timezones)
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
    log_info "Configuring keyboard layout"
    local -a available_keymaps=()
    if ! mapfile -t available_keymaps < <(localectl list-keymaps); then
      log_error "Failed to retrieve keyboard layouts from localectl."
      return 1
    fi
    if (( ${#available_keymaps[@]} == 0 )); then
      log_error "No keyboard layouts were returned by localectl."
      return 1
    fi

    local keyboard_layout_input=""
    local resolved_keymap=""
    local browse_selection=""

    read -r -p "Would you like to browse available keyboard layouts first? [Y/n]: " browse_choice </dev/tty
    browse_choice="${browse_choice,,}"
    if [[ "$browse_choice" != "n" && "$browse_choice" != "no" ]]; then
      browse_selection=$(interactive_list_browser "keyboard layout" "keyboard layouts" available_keymaps 25)
      if [[ -n "$browse_selection" ]]; then
        keyboard_layout_input="$browse_selection"
      fi
    fi

    while true; do
      if [[ -z "$keyboard_layout_input" ]]; then
        read -r -p "Enter your keyboard layout (type 'list' to browse): " keyboard_layout_input </dev/tty
      fi
      if [[ -z "$keyboard_layout_input" ]]; then
        log_error "Keyboard layout cannot be empty."
        continue
      fi
      if [[ "${keyboard_layout_input,,}" == "list" ]]; then
        browse_selection=$(interactive_list_browser "keyboard layout" "keyboard layouts" available_keymaps 25)
        keyboard_layout_input="$browse_selection"
        continue
      fi

      resolved_keymap=""
      for keymap in "${available_keymaps[@]}"; do
        if [[ "${keymap,,}" == "${keyboard_layout_input,,}" ]]; then
          resolved_keymap="$keymap"
          break
        fi
      done

      if [[ -z "$resolved_keymap" ]]; then
        log_error "Invalid keyboard layout. Please try again."
        read -r -p "Would you like to browse the keyboard layouts? [Y/n]: " browse_retry </dev/tty
        browse_retry="${browse_retry,,}"
        if [[ "$browse_retry" != "n" && "$browse_retry" != "no" ]]; then
          browse_selection=$(interactive_list_browser "keyboard layout" "keyboard layouts" available_keymaps 25)
          keyboard_layout_input="$browse_selection"
        else
          keyboard_layout_input=""
        fi
        continue
      fi

      echo "KEYMAP=$resolved_keymap" > /etc/vconsole.conf
      break
    done
  else
    echo "KEYMAP=us" > /etc/vconsole.conf
  fi
}
