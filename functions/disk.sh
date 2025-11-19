select_disk() {
  lsblk -o NAME,SIZE,TYPE
  read -p "Which disk would you like to use? " disk
  if [[ ! -b "$disk" ]]; then
    echo "Invalid disk selection. Please try again."
    select_disk
  else
    echo "Selected disk: $disk"
  fi
}

make_partitions() {
  cfdisk /dev/$disk
}