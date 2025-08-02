#!/bin/bash

# Backup the original sudoers file
sudo cp /etc/sudoers /etc/sudoers.bak

# Use sed to uncomment the specific line and safely edit the sudoers file
sudo sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers

# Validate the sudoers file to ensure no syntax errors
sudo visudo -c

# Check the exit status of visudo
if [ $? -eq 0 ]; then
    echo "The sudoers file was successfully updated and validated."
else
    echo "There was an error in the sudoers file. Restoring the backup."
    sudo cp /etc/sudoers.bak /etc/sudoers
fi
