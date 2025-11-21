#! /bin/bash
nvidia() {
  sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/".*"/"loglevel=3 nvidia-drm.modeset=1"/' /etc/default/grub
  sed -i '/^MODULES=/s/)/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
  # mkinitcpio -P     running it at the end of arch install process.
}