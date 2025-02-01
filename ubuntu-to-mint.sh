#!/bin/bash

# Script to make Ubuntu look like Linux Mint Cinnamon Edition
# Note: This script should be run with sudo privileges

# Exit immediately if a command exits with a non-zero status
set -e

# Update the system
echo "Updating the system..."
apt update && apt upgrade -y

# Install Cinnamon desktop environment
echo "Installing Cinnamon desktop environment..."
apt install cinnamon-desktop-environment -y

# Install Mint themes and icons
echo "Installing Mint themes and icons..."
apt install mint-themes mint-y-icons mint-x-icons -y

# Set up Mint repositories
echo "Setting up Mint repositories..."
echo "deb http://packages.linuxmint.com vera main upstream import backport" | tee /etc/apt/sources.list.d/mint.list

# Import Linux Mint GPG key
echo "Importing Linux Mint GPG key..."
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com A6616109451BBBF2

# Update package list
echo "Updating package list..."
apt update

# Install Mint-specific applications
echo "Installing Mint-specific applications..."
apt install mintinstall mintwelcome mintreport -y

# Install MDM (Mint Display Manager)
echo "Installing MDM (Mint Display Manager)..."
apt install mdm -y
echo "mdm shared/default-x-display-manager select mdm" | debconf-set-selections
dpkg-reconfigure mdm -f noninteractive

echo "Installation complete! Please reboot your system and select 'Cinnamon' as your desktop environment from the login screen."
echo "After logging in, don't forget to manually set your theme, icons, and customize your desktop to complete the Mint look."

# Prompt for reboot
read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    reboot
fi
