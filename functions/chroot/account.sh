#! /bin/bash
root_password() {
  log_info "Enter new root password"
  passwd </dev/tty >/dev/tty 2>&1
}

user_account() {
  log_info "Setting new user account"
  local username_input=""
  local username_regex='^[a-z_][a-z0-9_-]{0,31}$'
  while true; do
    read -r -p "Enter new username: " username_input </dev/tty
    username_input="${username_input,,}"
    if [[ -z "$username_input" ]]; then
      log_error "Username cannot be empty."
      continue
    fi
    if [[ ! "$username_input" =~ $username_regex ]]; then
      log_error "Usernames must start with a letter or underscore and contain only lowercase letters, numbers, underscores, or hyphens (max 32 chars)."
      continue
    fi
    if id -u "$username_input" &>/dev/null; then
      log_error "User '$username_input' already exists. Choose another username."
      continue
    fi
    username="$username_input"
    break
  done

  useradd -m -G wheel -s /bin/bash "$username"
  log_info "Enter new password for $username"
  passwd "$username" </dev/tty >/dev/tty 2>&1
  
  # Export username back to host system
  echo "$username" > /tmp/username.txt
}

sudoers() {
  # make backup of sudoers file
  cp /etc/sudoers /etc/sudoers.bak
  sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
  if visudo -c; then
      log_success "The sudoers file was successfully updated and validated."
      rm /etc/sudoers.bak
  else
      log_error "There was an error in the sudoers file. Restoring the backup."
      cp /etc/sudoers.bak /etc/sudoers
      exit 1
  fi
}