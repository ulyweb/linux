#!/bin/bash

# Script to create a Kali Linux Live USB with Encrypted Persistence
# WARNING: This script will erase all data on the selected USB drive.
# Run this script with sudo privileges: sudo ./create_kali_persistent_usb.sh
# chmod +x ./create_kali_persistent_usb.sh

# --- Configuration & Helper Functions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print messages
print_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_step() {
    echo -e "\n${GREEN}>>> STEP $1: $2${NC}"
}

confirm_action() {
    while true; do
        read -r -p "$(echo -e "${YELLOW}❓ $1 (yes/no): ${NC}")" choice
        case "$choice" in
            [Yy][Ee][Ss] ) return 0;;
            [Nn][Oo]     ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       print_error "This script must be run as root. Please use sudo."
       exit 1
    fi
}

check_tools() {
    local missing_tools=0
    # Essential tools for this script
    for tool in dd fdisk cryptsetup mkfs.ext4 lsblk tee umount mount mkdir e2label parted; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool '$tool' is not installed. Please install it and try again."
            missing_tools=1
        fi
    done
    if [[ "$missing_tools" -eq 1 ]]; then
        exit 1
    fi
}

# --- Main Script ---
clear
echo "==================================================================="
echo " Kali Linux Live USB with Encrypted Persistence Setup Script "
echo "==================================================================="
echo -e "${RED}🛑 WARNING: This script will partition and format the selected USB drive."
echo -e "${RED}🛑 ALL DATA ON THE SELECTED USB DRIVE WILL BE PERMANENTLY LOST."
echo -e "${YELLOW}Please back up any important data before proceeding.${NC}"
echo "==================================================================="
echo ""

# Preliminary checks
check_root
check_tools

# --- STEP 1: Write Kali ISO to USB Drive ---
print_step "1" "Writing Kali Linux ISO to USB Drive"
echo "This step will write the Kali Linux ISO image to your USB drive."
echo "This will make the USB drive bootable with Kali Linux."

# Get ISO path
while true; do
    read -r -p "Enter the full path to your Kali Linux ISO file (e.g., /path/to/kali-linux-YYYY.Q-live-amd64.iso): " KALI_ISO_PATH
    if [[ -f "$KALI_ISO_PATH" ]]; then
        print_info "ISO file found: $KALI_ISO_PATH"
        break
    else
        print_error "ISO file not found at '$KALI_ISO_PATH'. Please check the path and try again."
    fi
done

# Get target USB device
echo -e "\n${YELLOW}Available block devices (potential USB drives):${NC}"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "rom\|loop\|sr0" # Filter out cd/dvd, loop devices
echo -e "${YELLOW}Please identify your USB drive from the list above (e.g., /dev/sdb, /dev/sdc).${NC}"
print_warning "Ensure you select the correct device. Choosing the wrong one can erase your system!"

while true; do
    read -r -p "Enter the target USB device (e.g., /dev/sdb): " USB_DEVICE
    if [[ -b "$USB_DEVICE" ]]; then # Check if it's a block device
        if confirm_action "You have selected '$USB_DEVICE'. ALL DATA on this device will be ERASED. Are you absolutely sure you want to continue?"; then
            break
        else
            print_info "Operation cancelled by user."
            exit 0
        fi
    else
        print_error "Device '$USB_DEVICE' does not exist or is not a block device. Please enter a valid device path."
    fi
done

print_info "Writing ISO to $USB_DEVICE. This may take a while..."
if sudo dd if="$KALI_ISO_PATH" of="$USB_DEVICE" conv=fsync bs=4M status=progress; then
    print_info "Kali Linux ISO successfully written to $USB_DEVICE."
    sync # Ensure all data is written
else
    print_error "Failed to write ISO to $USB_DEVICE. Please check for errors."
    exit 1
fi

# --- STEP 2: Create an Additional Partition for Persistence ---
print_step "2" "Creating an Additional Partition for Persistence"
echo "This step will create a new partition in the remaining empty space on the USB drive."
echo "This partition will be used for encrypted persistence."
print_info "We will use 'parted' to create a new primary partition using all remaining free space."

if confirm_action "Proceed with creating a new partition on $USB_DEVICE?"; then
    print_info "Attempting to create partition on $USB_DEVICE..."
    # Give the system a moment to recognize the ISO structure
    sleep 5 
    sync

    # Get the end of the last partition written by the ISO
    # Kali ISOs usually create two partitions. We need to find the end of the 2nd one.
    # Using parted to get this information in a scriptable way.
    # The exact partition numbers might vary, so we find the last one.
    LAST_PART_END=$(sudo parted -sm "$USB_DEVICE" print free | grep -E '^[0-9]+:' | tail -n 1 | cut -d':' -f3)
    
    if [[ -z "$LAST_PART_END" ]]; then
        print_error "Could not determine the end of the existing partitions on $USB_DEVICE."
        print_error "This might happen if the ISO structure is not as expected or if 'parted' output changed."
        print_error "Please check 'sudo parted -sm \"$USB_DEVICE\" print free' manually."
        exit 1
    fi
    print_info "Last existing partition seems to end at $LAST_PART_END."

    # Create a new primary partition from LAST_PART_END to 100% of the disk
    # Using ext4 as a placeholder type, it will be reformatted by cryptsetup/mkfs later.
    if sudo parted -s "$USB_DEVICE" mkpart primary ext4 "$LAST_PART_END" 100%; then
        print_info "New partition command sent to 'parted'."
        sync # Ensure partition table changes are written
        sleep 5 # Give the system a moment to recognize the new partition
        sudo partprobe "$USB_DEVICE" # Ask kernel to re-read partition table
        sleep 2
    else
        print_error "'parted' command failed. Unable to create partition."
        exit 1
    fi
else
    print_info "Partition creation skipped by user."
    exit 0
fi

# Identify the new partition
# The new partition is usually the next number after existing ones.
# e.g., if sdb1 and sdb2 exist, new one is sdb3.
echo ""
lsblk "$USB_DEVICE"
print_warning "Please verify the new partition created for persistence from the 'lsblk' output above."

# Try to determine the new partition number automatically
# Count existing partitions, the new one should be that count + 1
EXISTING_PART_COUNT=$(lsblk -ln -o NAME "$USB_DEVICE" | grep -c "${USB_DEVICE##*/}[0-9]")
NEW_PART_NUM=$((EXISTING_PART_COUNT)) # lsblk lists the main device too, so count is often right.
                                        # If ISO creates 2 partitions (sda1, sda2), count is 2, new is sda3.
                                        # Let's be more robust by finding the highest number.
HIGHEST_PART_NUM=$(lsblk -ln -o NAME "$USB_DEVICE" | grep "${USB_DEVICE##*/}[0-9]" | sed "s|${USB_DEVICE##*/}\([0-9]*\)|\1|" | sort -n | tail -n 1)

if [[ -z "$HIGHEST_PART_NUM" ]]; then
    print_error "Could not automatically determine the new partition number."
    PERSISTENCE_PARTITION_DEFAULT=""
else
    PERSISTENCE_PARTITION_DEFAULT="${USB_DEVICE}${HIGHEST_PART_NUM}"
fi

read -r -p "Enter the device name for the new persistence partition (e.g., ${PERSISTENCE_PARTITION_DEFAULT:-${USB_DEVICE}3}): " PERSISTENCE_PARTITION_INPUT
PERSISTENCE_PARTITION=${PERSISTENCE_PARTITION_INPUT:-$PERSISTENCE_PARTITION_DEFAULT}


if [[ -z "$PERSISTENCE_PARTITION" ]] || [[ ! -b "$PERSISTENCE_PARTITION" ]]; then
    print_error "The specified partition '$PERSISTENCE_PARTITION' does not exist or is invalid. Please check 'lsblk $USB_DEVICE' and re-run."
    exit 1
fi
print_info "Using partition '$PERSISTENCE_PARTITION' for encrypted persistence."


# --- STEP 3: Encrypt the Partition with LUKS ---
print_step "3" "Encrypting the Persistence Partition with LUKS"
echo "This step will encrypt the partition '$PERSISTENCE_PARTITION' using LUKS (Linux Unified Key Setup)."
echo "You will be prompted to create a strong passphrase. DO NOT FORGET THIS PASSPHRASE."
echo "Losing it means losing access to your persistent data."
echo -e "${YELLOW}IMPORTANT: You will be asked to confirm by typing 'YES' (all uppercase) by cryptsetup.${NC}"

if confirm_action "Proceed with encrypting '$PERSISTENCE_PARTITION'? This will format the partition."; then
    print_info "Running LUKS formatting on $PERSISTENCE_PARTITION. Follow the prompts."
    if sudo cryptsetup --verbose --verify-passphrase luksFormat "$PERSISTENCE_PARTITION"; then
        print_info "Partition '$PERSISTENCE_PARTITION' successfully encrypted with LUKS."
    else
        print_error "LUKS encryption failed on '$PERSISTENCE_PARTITION'."
        exit 1
    fi
else
    print_info "Encryption skipped by user."
    exit 0
fi


# --- STEP 4: Open the Encrypted Partition ---
print_step "4" "Opening (Unlocking) the Encrypted Partition"
echo "This step will unlock the LUKS-encrypted partition to make it accessible."
read -r -p "Enter a name for the decrypted LUKS mapping (e.g., 'kali_persistence_crypt', default is 'my_usb_crypt'): " LUKS_MAP_NAME
LUKS_MAP_NAME=${LUKS_MAP_NAME:-my_usb_crypt} # Default to 'my_usb_crypt' if empty

print_info "Opening '$PERSISTENCE_PARTITION' as '/dev/mapper/$LUKS_MAP_NAME'. You will be prompted for your LUKS passphrase."
if sudo cryptsetup luksOpen "$PERSISTENCE_PARTITION" "$LUKS_MAP_NAME"; then
    print_info "Encrypted partition opened and mapped to /dev/mapper/$LUKS_MAP_NAME."
else
    print_error "Failed to open LUKS partition. Check your passphrase and ensure the partition exists."
    exit 1
fi


# --- STEP 5: Create an ext4 Filesystem ---
print_step "5" "Creating an ext4 Filesystem on the Unlocked Partition"
echo "This step will create an ext4 filesystem on the unlocked LUKS partition (/dev/mapper/$LUKS_MAP_NAME)."
FS_LABEL_DEFAULT="persistence" # This is the label Kali looks for
read -r -p "Enter a label for this filesystem (default is '$FS_LABEL_DEFAULT', recommended for Kali): " FS_LABEL
FS_LABEL=${FS_LABEL:-$FS_LABEL_DEFAULT}

print_info "Creating ext4 filesystem with label '$FS_LABEL' on /dev/mapper/$LUKS_MAP_NAME..."
if sudo mkfs.ext4 -L "$FS_LABEL" "/dev/mapper/$LUKS_MAP_NAME"; then
    print_info "ext4 filesystem created successfully with label '$FS_LABEL'."
    # The e2label command is redundant if -L is used with mkfs.ext4, but we can verify.
    # sudo e2label "/dev/mapper/$LUKS_MAP_NAME" "$FS_LABEL"
else
    print_error "Failed to create ext4 filesystem on /dev/mapper/$LUKS_MAP_NAME."
    # Attempt to close LUKS mapper on failure
    sudo cryptsetup luksClose "$LUKS_MAP_NAME"
    exit 1
fi


# --- STEP 6: Mount Partition and Create persistence.conf ---
print_step "6" "Configuring Persistence"
echo "This step will mount the new filesystem and create the 'persistence.conf' file, which tells Kali to use this partition for persistence."

MOUNT_POINT_BASE="/mnt"
MOUNT_POINT="$MOUNT_POINT_BASE/$LUKS_MAP_NAME" # e.g., /mnt/my_usb_crypt

print_info "Creating mount point: $MOUNT_POINT"
if sudo mkdir -p "$MOUNT_POINT"; then
    print_info "Mount point created."
else
    print_error "Failed to create mount point $MOUNT_POINT."
    sudo cryptsetup luksClose "$LUKS_MAP_NAME"
    exit 1
fi

print_info "Mounting /dev/mapper/$LUKS_MAP_NAME to $MOUNT_POINT..."
if sudo mount "/dev/mapper/$LUKS_MAP_NAME" "$MOUNT_POINT"; then
    print_info "Filesystem mounted successfully."
else
    print_error "Failed to mount /dev/mapper/$LUKS_MAP_NAME to $MOUNT_POINT."
    sudo rmdir "$MOUNT_POINT" # Clean up created mount point
    sudo cryptsetup luksClose "$LUKS_MAP_NAME"
    exit 1
fi

PERSISTENCE_CONF_CONTENT="/ union"
print_info "Creating persistence.conf file at '$MOUNT_POINT/persistence.conf' with content: '$PERSISTENCE_CONF_CONTENT'"
if echo "$PERSISTENCE_CONF_CONTENT" | sudo tee "$MOUNT_POINT/persistence.conf" > /dev/null; then
    print_info "'persistence.conf' created successfully in $MOUNT_POINT."
else
    print_error "Failed to create 'persistence.conf'."
    sudo umount "$MOUNT_POINT"
    sudo rmdir "$MOUNT_POINT"
    sudo cryptsetup luksClose "$LUKS_MAP_NAME"
    exit 1
fi

print_info "Unmounting $MOUNT_POINT..."
if sudo umount "$MOUNT_POINT"; then
    print_info "Filesystem unmounted successfully."
else
    print_warning "Failed to unmount $MOUNT_POINT. You may need to unmount it manually: sudo umount $MOUNT_POINT"
    # Continue to luksClose as it's important
fi

print_info "Removing temporary mount point $MOUNT_POINT..."
if sudo rmdir "$MOUNT_POINT"; then
    print_info "Mount point removed."
else
    print_warning "Failed to remove mount point $MOUNT_POINT. It might be in use or already removed."
fi


# --- STEP 7: Close the Encrypted Partition ---
print_step "7" "Closing (Locking) the Encrypted Partition"
echo "This step will lock the LUKS encrypted partition."

print_info "Closing LUKS mapping /dev/mapper/$LUKS_MAP_NAME..."
if sudo cryptsetup luksClose "$LUKS_MAP_NAME"; then
    print_info "Encrypted partition /dev/mapper/$LUKS_MAP_NAME closed successfully."
else
    print_error "Failed to close LUKS partition /dev/mapper/$LUKS_MAP_NAME. It might already be closed or an error occurred."
    # Still, the main goal might have been achieved.
fi

echo ""
echo "==================================================================="
echo -e "${GREEN}🎉 Congratulations! Your Kali Linux Live USB with Encrypted Persistence should be ready!${NC}"
echo "==================================================================="
echo "You can now reboot your computer and boot from the USB drive."
echo "When booting, select the 'Live system (persistence, check kali.org/prst)' or a similar option that mentions persistence."
echo "You will be prompted for your LUKS passphrase during the boot process to unlock your persistent storage."
echo ""
print_warning "Remember your LUKS passphrase! If you forget it, your persistent data will be inaccessible."
echo "==================================================================="

exit 0
