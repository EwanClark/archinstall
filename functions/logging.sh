#!/bin/bash

COLOR_RESET=$'\033[0m'
COLOR_STEP=$'\033[1;32m'
COLOR_TITLE=$'\033[1;32m'
COLOR_INFO=$'\033[0;37m'
COLOR_SUCCESS=$'\033[1;32m'
COLOR_WARN=$'\033[1;33m'
COLOR_ERROR=$'\033[1;31m'

log_step() {
  local message="$1"
  printf "\n%s==> %s%s\n" "$COLOR_STEP" "$message" "$COLOR_RESET"
}

log_title() {
  local message="$1"
  printf "\n%s%s%s\n" "$COLOR_TITLE" "$message" "$COLOR_RESET"
}

log_info() {
  local message="$1"
  printf "%s%s%s\n" "$COLOR_INFO" "$message" "$COLOR_RESET"
}

log_success() {
  local message="$1"
  printf "%s%s%s\n" "$COLOR_SUCCESS" "$message" "$COLOR_RESET"
}

log_warn() {
  local message="$1"
  printf "%s%s%s\n" "$COLOR_WARN" "$message" "$COLOR_RESET"
}

log_error() {
  local message="$1"
  printf "%s%s%s\n" "$COLOR_ERROR" "$message" "$COLOR_RESET" >&2
}

log_blank() {
  printf "\n"
}

