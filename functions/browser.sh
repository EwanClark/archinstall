#! /bin/bash

if ! declare -F log_info >/dev/null 2>&1; then
  _browser_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${_browser_dir}/logging.sh" ]]; then
    # shellcheck source=functions/logging.sh
    source "${_browser_dir}/logging.sh"
  elif [[ -f "${_browser_dir}/../functions/logging.sh" ]]; then
    # shellcheck source=functions/logging.sh
    source "${_browser_dir}/../functions/logging.sh"
  fi
  unset _browser_dir
fi

# Generic pager/search browser for long lists shown inside /dev/tty.
# Accepts a reference to an array and lets the user page, search, reset,
# and select either by the on-screen number or the exact text.
interactive_list_browser() {
  local singular_label="${1:-item}"
  local plural_label="${2:-items}"
  local array_ref="$3"
  local page_size="${4:-20}"
  local tty="/dev/tty"

  if [[ -z "$array_ref" ]]; then
    log_error "No ${plural_label} list reference provided." 2>"$tty"
    return 1
  fi

  local -n _items_ref="$array_ref"
  local page=0
  local selection=""
  local -a active_indices=("${!_items_ref[@]}")

  if (( ${#_items_ref[@]} == 0 )); then
    log_warn "No ${plural_label} available to display." >"$tty"
    return 1
  fi

  while true; do
    local total_active=${#active_indices[@]}
    if (( total_active == 0 )); then
      log_blank >"$tty"
      log_warn "No matches found. Use 'r' to reset all ${plural_label} or 'q' to quit." >"$tty"
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
      log_blank >"$tty"
      printf -v header "Showing %s %d-%d of %d (of %d total)" "$plural_label" $((start + 1)) $end $total_active ${#_items_ref[@]}
      log_info "$header" >"$tty"
      for ((i=start; i<end; i++)); do
        local idx=${active_indices[i]}
        printf -v line "%4d) %s" $((idx + 1)) "${_items_ref[idx]}"
        log_info "$line" >"$tty"
      done
      printf -v instructions "Type the number beside a %s or enter the exact %s text to select it." "$singular_label" "$singular_label"
      log_info "$instructions" >"$tty"
    fi

    log_blank >"$tty"
    log_info "Options: [Enter/n] next  [p] prev  [s] search  [r] reset  [q] quit  [number/text] select" >"$tty"
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
          active_indices=("${!_items_ref[@]}")
        else
          for idx in "${!_items_ref[@]}"; do
            if [[ "${_items_ref[idx],,}" == *"$term"* ]]; then
              active_indices+=("$idx")
            fi
          done
        fi
        page=0
        ;;
      r|R)
        active_indices=("${!_items_ref[@]}")
        page=0
        ;;
      q|Q)
        break
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          local num=$choice
          if (( num >= 1 && num <= ${#_items_ref[@]} )); then
            selection="${_items_ref[num-1]}"
            printf -v selected_msg "Selected %s: %s" "$singular_label" "$selection"
            log_success "$selected_msg" >"$tty"
            printf "%s" "$selection"
            return 0
          fi
          log_warn "Number outside valid range." >"$tty"
        else
          local lowered_choice="${choice,,}"
          for item in "${_items_ref[@]}"; do
            if [[ "${item,,}" == "$lowered_choice" ]]; then
              selection="$item"
              printf -v selected_msg "Selected %s: %s" "$singular_label" "$selection"
              log_success "$selected_msg" >"$tty"
              printf "%s" "$selection"
              return 0
            fi
          done
          printf -v unknown_msg "Unknown option. Enter an on-screen number or the exact %s text." "$singular_label"
          log_warn "$unknown_msg" >"$tty"
        fi
        ;;
    esac
  done

  return 1
}

