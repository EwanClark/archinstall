#! /bin/bash

detected_gpu_vendor="Unknown"
detected_cpu_vendor="Unknown"
selected_gpu_profile=""
selected_cpu_microcode=""
dual_boot=""
secure_boot=""
nvidia=false

function check_compatibility() {
  if [[ ! -d /sys/firmware/efi ]]; then
    # System is not UEFI, failed compatibility
    log_error "System is not UEFI, this script only supports UEFI systems."
    return 1
  fi

  # All checks passed
  return 0
}

detect_gpu_vendor() {
  local vga_output
  if command -v lspci >/dev/null 2>&1; then
    vga_output=$(lspci | grep -iE "vga|3d|display" || true)
  else
    vga_output=""
  fi

  if echo "$vga_output" | grep -qi "nvidia"; then
    detected_gpu_vendor="NVIDIA"
    return 0
  elif echo "$vga_output" | grep -Eqi "amd|ati"; then
    detected_gpu_vendor="AMD"
    return 1
  elif echo "$vga_output" | grep -qi "intel"; then
    detected_gpu_vendor="Intel"
    return 1
  fi

  detected_gpu_vendor="Unknown"
  return 1
}

nvidia_or_amd_or_intel_gpu() {
  detect_gpu_vendor
  if [[ "$detected_gpu_vendor" == "NVIDIA" ]]; then
    return 0
  fi
  return 1
}

detect_cpu_vendor() {
  if grep -qi "GenuineIntel" /proc/cpuinfo; then
    detected_cpu_vendor="Intel"
    return 0
  elif grep -qi "AuthenticAMD" /proc/cpuinfo || grep -qi "AMD" /proc/cpuinfo; then
    detected_cpu_vendor="AMD"
    return 1
  fi

  detected_cpu_vendor="Unknown"
  return 1
}

# Intel or AMD cpu
intel_or_amd_cpu() {
  detect_cpu_vendor
  if [[ "$detected_cpu_vendor" == "Intel" ]]; then
    return 0
  fi
  return 1
}

ensure_detection_defaults() {
  if [[ -z "$selected_gpu_profile" ]]; then
    if [[ "$detected_gpu_vendor" == "NVIDIA" ]]; then
      selected_gpu_profile="nvidia"
    else
      selected_gpu_profile="amd_intel"
    fi
  fi

  if [[ -z "$selected_cpu_microcode" ]]; then
    if [[ "$detected_cpu_vendor" == "Intel" ]]; then
      selected_cpu_microcode="intel"
    else
      selected_cpu_microcode="amd"
    fi
  fi

  sync_gpu_selection_flags
}

ensure_boot_option_selections() {
  if [[ -z "${dual_boot:-}" ]]; then
    dual_boot_compatibility || true
  fi
  if [[ -z "${secure_boot:-}" ]]; then
    secure_boot_compatibility || true
  fi
}

sync_gpu_selection_flags() {
  if [[ "$selected_gpu_profile" == "nvidia" ]]; then
    nvidia=true
  else
    nvidia=false
  fi
}

format_enabled_state() {
  local value="${1:-false}"
  if [[ "$value" == "true" ]]; then
    echo "Enabled"
  else
    echo "Disabled"
  fi
}

modify_detection_settings() {
  local choice
  while true; do
    log_blank
    log_title "Modify detected settings"
    log_info "1) CPU microcode packages : ${selected_cpu_microcode^^}"
    log_info "2) GPU driver profile     : ${selected_gpu_profile//_/ + }"
    log_info "3) Dual boot packages     : $(format_enabled_state "$dual_boot")"
    log_info "4) Secure boot packages   : $(format_enabled_state "$secure_boot")"
    log_info "5) Done"
    read -r -p "Select an option to change [1-5]: " choice </dev/tty
    case "${choice,,}" in
      1)
        while true; do
          read -r -p "Choose CPU microcode packages [intel/amd]: " cpu_choice </dev/tty
          cpu_choice="${cpu_choice,,}"
          case "$cpu_choice" in
            intel|amd)
              selected_cpu_microcode="$cpu_choice"
              break
              ;;
            *)
              log_warn "Please answer 'intel' or 'amd'."
              ;;
          esac
        done
        ;;
      2)
        while true; do
          read -r -p "Choose GPU driver profile [nvidia/amd]: " gpu_choice </dev/tty
          gpu_choice="${gpu_choice,,}"
          case "$gpu_choice" in
            nvidia)
              selected_gpu_profile="nvidia"
              break
              ;;
            amd|amd_intel|mesa)
              selected_gpu_profile="amd_intel"
              break
              ;;
            *)
              log_warn "Please answer 'nvidia' or 'amd'."
              ;;
          esac
        done
        ;;
      3)
        while true; do
          read -r -p "Enable dual boot packages? [y/N]: " dual_choice </dev/tty
          dual_choice="${dual_choice,,}"
          case "$dual_choice" in
            ""|"n"|"no")
              dual_boot=false
              break
              ;;
            "y"|"yes")
              dual_boot=true
              break
              ;;
            *)
              log_warn "Please answer yes or no."
              ;;
          esac
        done
        ;;
      4)
        while true; do
          read -r -p "Enable secure boot packages? [y/N]: " secure_choice </dev/tty
          secure_choice="${secure_choice,,}"
          case "$secure_choice" in
            ""|"n"|"no")
              secure_boot=false
              break
              ;;
            "y"|"yes")
              secure_boot=true
              break
              ;;
            *)
              log_warn "Please answer yes or no."
              ;;
          esac
        done
        ;;
      5|""|"done"|"q"|"quit")
        sync_gpu_selection_flags
        return 0
        ;;
      *)
        log_warn "Please pick a number between 1 and 5."
        ;;
    esac
    sync_gpu_selection_flags
  done
}

review_system_detection() {
  ensure_detection_defaults
  local response
  while true; do
    log_blank
    log_title "System detection summary"
    log_info "CPU vendor detected : ${detected_cpu_vendor}"
    log_info "CPU microcode pkg   : ${selected_cpu_microcode^^}"
    log_info "GPU vendor detected : ${detected_gpu_vendor}"
    log_info "GPU driver profile  : ${selected_gpu_profile//_/ + }"
    log_info "Dual boot packages  : $(format_enabled_state "$dual_boot")"
    log_info "Secure boot packages: $(format_enabled_state "$secure_boot")"
    log_blank
    read -r -p "Accept these settings? [Y]es / [M]odify / [R]edetect: " response </dev/tty
    response="${response,,}"
    case "$response" in
      ""|"y"|"yes")
        sync_gpu_selection_flags
        return 0
        ;;
      "m"|"modify")
        modify_detection_settings
        ;;
      "r"|"redetect")
        detect_gpu_vendor
        detect_cpu_vendor
        selected_gpu_profile=""
        selected_cpu_microcode=""
        ensure_detection_defaults
        ;;
      *)
        log_warn "Please respond with 'y', 'm', or 'r'."
        ;;
    esac
  done
}

# Ask if they want dual boot compatibility
dual_boot_compatibility() {
  if [[ -n "${dual_boot:-}" ]]; then
    if [[ "$dual_boot" == "true" ]]; then
      return 0
    fi
    return 1
  fi
  while true; do
    read -r -p "Do you want dual boot compatibility? [Y/n]: " dual_boot_input </dev/tty
    dual_boot_input="${dual_boot_input,,}"
    case "$dual_boot_input" in
      ""|"y"|"yes")
        dual_boot=true
        return 0
        ;;
      "n"|"no")
        dual_boot=false
        return 1
        ;;
      *)
      log_warn "Please answer yes or no."
        ;;
    esac
  done
}

# Ask if they want secure boot compatibility
secure_boot_compatibility() {
  if [[ -n "${secure_boot:-}" ]]; then
    if [[ "$secure_boot" == "true" ]]; then
      return 0
    fi
    return 1
  fi
  while true; do
    read -r -p "Do you want secure boot compatibility? [Y/n]: " secure_boot_input </dev/tty
    secure_boot_input="${secure_boot_input,,}"
    case "$secure_boot_input" in
      ""|"y"|"yes")
        secure_boot=true
        return 0
        ;;
      "n"|"no")
        secure_boot=false
        return 1
        ;;
      *)
      log_warn "Please answer yes or no."
        ;;
    esac
  done
}