finalizing() {
  mkinitcpio -P
  log_step "Installation complete!"
  if secure_boot; then
    secure_boot_info
    generate_script
    log_info "You can now reboot your system. Remember to enable Secure Boot setup mode!"
  else
    log_info "You can now reboot your system."
  fi
}