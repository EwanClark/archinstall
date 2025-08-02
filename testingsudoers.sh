#!/bin/bash

# Create a temporary file
temp_sudoers=$(mktemp)

# Copy the current sudoers file to the temporary file
sudo cp /etc/sudoers "$temp_sudoers"

# Use sed to uncomment the line
sudo sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+ALL\)/\1/' "$temp_sudoers"

# Validate the modified file using visudo
sudo visudo -c -f "$temp_sudoers"
if [ $? -eq 0 ]; then
    # If the validation is successful, replace the sudoers file
    sudo cp "$temp_sudoers" /etc/sudoers
    echo "Successfully updated the sudoers file."
else
    echo "Error: The modified sudoers file is invalid. No changes were made."
fi

# Clean up the temporary file
rm -f "$temp_sudoers"