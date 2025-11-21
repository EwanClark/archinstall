#! /bin/bash
timezone() {
  log_info "Setting timezone configuration"
  read -r -p "Press enter to see all available timezones" </dev/tty
  timedatectl list-timezones
  local timezone_input=""
  local resolved_timezone=""
  while true; do
    read -r -p "Enter your timezone (e.g. Region/City): " timezone_input </dev/tty
    if [[ -z "$timezone_input" ]]; then
      log_error "Timezone cannot be empty."
      continue
    fi
    resolved_timezone=$(timedatectl list-timezones | awk -v target="$timezone_input" 'tolower($0)==tolower(target) {print $0; exit}')
    if [[ -z "$resolved_timezone" ]]; then
      log_error "Invalid timezone. Please try again."
      continue
    fi
    ln -sf "/usr/share/zoneinfo/$resolved_timezone" /etc/localtime
    hwclock --systohc
    break
  done
}

locale() {
  read -r -p "Would you like a custom locale (default is en_us) [Y/n]: " custom_locale </dev/tty
  custom_locale="${custom_locale,,}"
  if [[ -z "$custom_locale" || "$custom_locale" == "y" || "$custom_locale" == "yes" ]]; then
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