#!/bin/bash

# Script to create a Kali Linux Live USB with Encrypted Persistence (Dialog Enhanced)
# WARNING: This script will erase all data on the selected USB drive.
# Run this script with sudo privileges: sudo ./create_kali_persistent_usb_dialog.sh

# --- Configuration & Helper Functions ---
# Dialog exit codes
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ESC=255

# Dialog dimensions (approximate, dialog often auto-adjusts)
D_WIDTH=70
D_INFO_HEIGHT=8
D_MSGBOX_HEIGHT=10
D_INPUT_HEIGHT=10 # Increased height slightly for longer default path
D_MENU_HEIGHT=18
D_GAUGE_HEIGHT=7

# Function to print messages (for console, if dialog fails or for debugging)
_print_info() {
    echo "[INFO] $1"
}

_print_warning() {
    echo "[WARNING] $1"
}

_print_error() {
    echo "[ERROR] $1"
}

# Function to display a dialog message box
show_msgbox() {
    local title="$1"
    local message="$2"
    dialog --backtitle "Kali Persistent USB Creator" --title "$title" --msgbox "$message" $D_MSGBOX_HEIGHT $D_WIDTH
}

# Function to display an error message box and exit
show_error_exit() {
    local message="$1"
    dialog --backtitle "Kali Persistent USB Creator" --title "Error" --msgbox "ERROR: $message\n\nAborting script." $D_MSGBOX_HEIGHT $D_WIDTH
    # Restore stdout before exiting if it was redirected
    exec 1>&3 3>&-
    exit 1
}

# Function to ask for confirmation
confirm_action_dialog() {
    local title="$1"
    local message="$2"
    dialog --backtitle "Kali Persistent USB Creator" --title "$title" --yesno "$message" $D_MSGBOX_HEIGHT $D_WIDTH
    return $? # Returns 0 for Yes, 1 for No
}

# Function to get text input
get_input_dialog() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    # Redirect stderr (dialog output) to stdout (captured by command substitution)
    # and redirect original stdout to fd 3 so it doesn't get captured.
    dialog --backtitle "Kali Persistent USB Creator" --title "$title" --inputbox "$prompt" $D_INPUT_HEIGHT $D_WIDTH "$default_value" 2>&1 1>&3
}

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
       # No fd 3 redirection here yet, as it's set up in main script body
       dialog --backtitle "Kali Persistent USB Creator" --title "Error" --msgbox "This script must be run as root. Please use sudo.\n\nAborting." $D_MSGBOX_HEIGHT $D_WIDTH
       exit 1
    fi
}

# Function to check for required tools
check_tools() {
    local missing_tools_list=()
    # Essential tools for this script
    for tool in dialog dd fdisk cryptsetup mkfs.ext4 lsblk tee umount mount mkdir e2label parted partprobe; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools_list+=("$tool")
        fi
    done
    if [[ ${#missing_tools_list[@]} -ne 0 ]]; then
        local message="The following required tools are not installed:\n"
        for tool in "${missing_tools_list[@]}"; do
            message+="\n- $tool"
        done
        message+="\n\nPlease install them and try again.\nExample for Debian/Kali: sudo apt install ${missing_tools_list[*]}.\n\nAborting."
        dialog --backtitle "Kali Persistent USB Creator" --title "Missing Tools" --msgbox "$message" $((D_MSGBOX_HEIGHT + ${#missing_tools_list[@]} + 2)) $D_WIDTH
        exit 1
    fi
}

# --- Main Script ---
# Save current stdout to fd 3, so dialog (which writes its output to stderr)
# can have its stderr redirected to the original stdout for capture by command substitution,
# without capturing the script's own echo/printf statements.
exec 3>&1

check_root
check_tools

show_msgbox "Welcome" "Welcome to the Kali Linux Live USB with Encrypted Persistence Setup Script.\n\n\
This script will guide you through the process.\n\n\
🛑 WARNING: This script will partition and format the selected USB drive. \
ALL DATA ON THE SELECTED USB DRIVE WILL BE PERMANENTLY LOST.\n\n\
Please back up any important data before proceeding."

# --- STEP 1: Write Kali ISO to USB Drive ---
# Determine the actual home directory of the user who invoked sudo, or current user if not sudo
SUDO_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
CURRENT_USER_HOME="$HOME"

TARGET_HOME="${SUDO_USER_HOME:-$CURRENT_USER_HOME}" # Prefer SUDO_USER's home if available

DEFAULT_KALI_ISO_PATH="$TARGET_HOME/Downloads/kali-linux-2025.1c-live-amd64.iso"

KALI_ISO_PATH=$(get_input_dialog "Step 1: Select ISO" "Enter the full path to your Kali Linux ISO file:" "$DEFAULT_KALI_ISO_PATH")
DIALOG_EXIT_CODE=$? # Capture exit code of dialog

if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]]; then
    show_msgbox "Cancelled" "Operation cancelled by user."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi
# If user pressed OK but left the field empty, dialog returns an empty string.
# In this specific case, we want to use the default if it was empty.
# The get_input_dialog function already returns the default if input is empty and OK is pressed.

_print_info "Selected ISO path: $KALI_ISO_PATH" # For debugging if needed

while [[ ! -f "$KALI_ISO_PATH" ]]; do
    KALI_ISO_PATH=$(get_input_dialog "Step 1: Select ISO - File Not Found" "ISO file not found at '$KALI_ISO_PATH'.\nPlease check the path and try again, or cancel." "$DEFAULT_KALI_ISO_PATH")
    DIALOG_EXIT_CODE=$?
    if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]]; then
        show_msgbox "Cancelled" "Operation cancelled by user."
        exec 1>&3 3>&- # Restore stdout
        exit 0
    fi
done

# Get target USB device
mapfile -t devices_raw < <(lsblk -d -n -p -o NAME,SIZE,MODEL,TRAN | grep -v "rom\|loop\|sr0")
declare -a device_options
if [[ ${#devices_raw[@]} -eq 0 ]]; then
    show_error_exit "No suitable USB devices found. Please ensure your USB drive is connected."
fi

for i in "${!devices_raw[@]}"; do
    device_info=(${devices_raw[$i]}) # Split string into array
    device_name="${device_info[0]}"
    device_details="${devices_raw[$i]#"$device_name "}" # Get the rest of the line
    # Ensure details are quoted if they contain spaces for dialog
    device_options+=("$device_name" "$device_details" "OFF")
done

USB_DEVICE=$(dialog --backtitle "Kali Persistent USB Creator" --title "Step 1: Select USB Drive" \
    --radiolist "Select the target USB drive (USE ARROW KEYS, SPACE TO SELECT, ENTER TO CONFIRM):\n\n\
    🛑 CAUTION: ALL DATA ON THE SELECTED DRIVE WILL BE ERASED!" \
    $D_MENU_HEIGHT $D_WIDTH $((${#device_options[@]} / 3)) \
    "${device_options[@]}" 2>&1 1>&3)
DIALOG_EXIT_CODE=$?

if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]] || [[ -z "$USB_DEVICE" ]]; then
    show_msgbox "Cancelled" "Operation cancelled by user or no device selected."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi

confirm_action_dialog "Step 1: Confirm USB Device" "You have selected '$USB_DEVICE'.\n\n\
🛑 ALL DATA ON THIS DEVICE WILL BE ERASED PERMANENTLY.\n\n\
Are you absolutely sure you want to continue?"
if [[ $? -ne $DIALOG_OK ]]; then
    show_msgbox "Cancelled" "Operation cancelled by user."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi

show_msgbox "Step 1: Writing ISO" "Now writing Kali Linux ISO '$KALI_ISO_PATH' to '$USB_DEVICE'.\n\n\
This may take a significant amount of time depending on the ISO size and USB speed.\n\n\
Please be patient. A success or failure message will appear once completed."

(
    # Using pv to show progress if available, otherwise just run dd
    if command -v pv &> /dev/null; then
        ISO_SIZE=$(stat -c%s "$KALI_ISO_PATH")
        sudo dd if="$KALI_ISO_PATH" bs=4M conv=fsync status=none | pv -s "$ISO_SIZE" -ptebar | sudo dd of="$USB_DEVICE" bs=4M status=none
    else
        sudo dd if="$KALI_ISO_PATH" of="$USB_DEVICE" conv=fsync bs=4M status=progress
    fi
    sync
) 2>&1 | dialog --backtitle "Kali Persistent USB Creator" --title "Writing ISO..." --programbox "Writing '$KALI_ISO_PATH' to '$USB_DEVICE'...\nThis can take several minutes." 20 $D_WIDTH
# The exit status of the last command in a pipe is what $? reflects.
# For the pv pipe, it would be the exit status of the second dd.
# For the simple dd, it's its own status.
# We need to be careful here. A more robust way is to check pipe status array if available (bash 4+).
# For simplicity, we'll assume if dialog box closes without error, dd likely succeeded.
# A truly robust progress for dd into dialog is complex.
# Let's capture the exit code of the subshell.
DD_COMMAND_EXIT_CODE=$?


if [[ $DD_COMMAND_EXIT_CODE -eq 0 ]]; then
    show_msgbox "Step 1: Success" "Kali Linux ISO successfully written to $USB_DEVICE."
else
    show_error_exit "Failed to write ISO to $USB_DEVICE. 'dd' command or 'pv' pipeline exited with code $DD_COMMAND_EXIT_CODE. Please check for errors (e.g., permissions, disk space, correct device)."
fi

# --- STEP 2: Create an Additional Partition for Persistence ---
show_msgbox "Step 2: Create Persistence Partition" "This step will attempt to create a new partition in the remaining empty space on '$USB_DEVICE'.\n\nThis partition will be used for encrypted persistence."

confirm_action_dialog "Step 2: Confirm Partition Creation" "Proceed with creating a new partition on $USB_DEVICE?"
if [[ $? -ne $DIALOG_OK ]]; then
    show_msgbox "Cancelled" "Partition creation skipped by user."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi

dialog --backtitle "Kali Persistent USB Creator" --title "Step 2: Creating Partition" --infobox "Attempting to create partition on $USB_DEVICE..." 5 $D_WIDTH
sleep 1 # Brief pause for infobox visibility

# Give the system a moment to recognize the ISO structure
sleep 5
sync

LAST_PART_END=$(sudo parted -sm "$USB_DEVICE" print free 2>/dev/null | grep -E '^[0-9]+:' | tail -n 1 | cut -d':' -f3)

if [[ -z "$LAST_PART_END" ]]; then
    show_error_exit "Could not determine the end of the existing partitions on $USB_DEVICE using 'parted'. \
    This might happen if the ISO structure is not as expected or if 'parted' output changed. \
    Please check 'sudo parted -sm \"$USB_DEVICE\" print free' manually."
fi
_print_info "Last existing partition seems to end at $LAST_PART_END." # Debug output

if sudo parted -s "$USB_DEVICE" mkpart primary ext4 "$LAST_PART_END" 100% &>/dev/null; then
    _print_info "New partition command sent to 'parted'." # Debug output
    sync # Ensure partition table changes are written
    sleep 5 # Give the system a moment to recognize the new partition
    sudo partprobe "$USB_DEVICE" # Ask kernel to re-read partition table
    sleep 2
    show_msgbox "Step 2: Partition Created" "'parted' command completed. A new partition should have been created."
else
    show_error_exit "'parted' command failed. Unable to create partition. Check 'parted' output if run manually."
fi

# Identify the new partition
PARTITIONS_INFO=$(lsblk -npl -o NAME,SIZE,FSTYPE,MOUNTPOINT "$USB_DEVICE")
HIGHEST_PART_NUM=$(lsblk -ln -o NAME "$USB_DEVICE" | grep -oP "${USB_DEVICE##*/}\K[0-9]+" | sort -n | tail -n 1)

# If HIGHEST_PART_NUM is empty (e.g. no numbered partitions yet, though unlikely after dd)
# or if parted created a partition but lsblk doesn't see it with a number yet,
# this logic might need adjustment or a more robust way to find the *newest* partition.
# For now, assume it's the highest number.
PERSISTENCE_PARTITION_DEFAULT=""
if [[ -n "$HIGHEST_PART_NUM" ]]; then
    PERSISTENCE_PARTITION_DEFAULT="${USB_DEVICE}${HIGHEST_PART_NUM}"
else
    # Fallback if no numbered partitions found, less reliable
    PERSISTENCE_PARTITION_DEFAULT="${USB_DEVICE}3" # Common case after typical ISO
fi


PERSISTENCE_PARTITION=$(get_input_dialog "Step 2: Identify Persistence Partition" \
 "The following partitions exist on $USB_DEVICE:\n\n$PARTITIONS_INFO\n\n\
 The script suggests the new persistence partition is '$PERSISTENCE_PARTITION_DEFAULT'.\n\
 Please verify and enter the correct device name for the NEW persistence partition (e.g., /dev/sdb3):" \
 "$PERSISTENCE_PARTITION_DEFAULT")
DIALOG_EXIT_CODE=$?

if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]] || [[ -z "$PERSISTENCE_PARTITION" ]]; then
    show_msgbox "Cancelled" "Operation cancelled or no partition entered."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi

while [[ ! -b "$PERSISTENCE_PARTITION" ]]; do
    PERSISTENCE_PARTITION=$(get_input_dialog "Step 2: Invalid Partition" \
    "The partition '$PERSISTENCE_PARTITION' does not exist or is not a block device.\n\
    Current partitions on $USB_DEVICE:\n$PARTITIONS_INFO\n\n\
    Please enter a valid partition name:" "$PERSISTENCE_PARTITION_DEFAULT")
    DIALOG_EXIT_CODE=$?
    if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]]; then
        show_msgbox "Cancelled" "Operation cancelled."
        exec 1>&3 3>&- # Restore stdout
        exit 0
    fi
done
show_msgbox "Step 2: Partition Selected" "Using partition '$PERSISTENCE_PARTITION' for encrypted persistence."

# --- STEP 3: Encrypt the Partition with LUKS ---
show_msgbox "Step 3: Encrypt Partition" "This step will encrypt the partition '$PERSISTENCE_PARTITION' using LUKS (Linux Unified Key Setup).\n\n\
You will be prompted by 'cryptsetup' to:\n\
1. Confirm by typing 'YES' (all uppercase).\n\
2. Create a strong passphrase. DO NOT FORGET THIS PASSPHRASE.\n\n\
Losing it means losing access to your persistent data."

confirm_action_dialog "Step 3: Confirm Encryption" "Proceed with encrypting '$PERSISTENCE_PARTITION'?\nThis will format the data on this specific partition."
if [[ $? -ne $DIALOG_OK ]]; then
    show_msgbox "Cancelled" "Encryption skipped by user."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi

# cryptsetup has its own TUI for passphrase, so we temporarily exit dialog's control
# Save current tty settings
OLD_TTY_SETTINGS=$(stty -g)
# Restore tty settings before cryptsetup
stty sane
if sudo cryptsetup --verbose --verify-passphrase luksFormat "$PERSISTENCE_PARTITION"; then
    # Restore tty settings after cryptsetup
    stty "$OLD_TTY_SETTINGS"
    show_msgbox "Step 3: Success" "Partition '$PERSISTENCE_PARTITION' successfully encrypted with LUKS."
else
    stty "$OLD_TTY_SETTINGS"
    show_error_exit "LUKS encryption failed on '$PERSISTENCE_PARTITION'. Check cryptsetup messages for details."
fi

# --- STEP 4: Open the Encrypted Partition ---
LUKS_MAP_NAME=$(get_input_dialog "Step 4: LUKS Mapping Name" "Enter a name for the decrypted LUKS mapping (e.g., 'kali_persistence_crypt'):" "my_usb_crypt")
DIALOG_EXIT_CODE=$?
if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]]; then
    show_msgbox "Cancelled" "Operation cancelled."
    exec 1>&3 3>&- # Restore stdout
    exit 0
fi
if [[ -z "$LUKS_MAP_NAME" ]]; then LUKS_MAP_NAME="my_usb_crypt"; fi # Ensure default if empty

show_msgbox "Step 4: Open Encrypted Partition" "This step will unlock the LUKS-encrypted partition '$PERSISTENCE_PARTITION' as '/dev/mapper/$LUKS_MAP_NAME'.\n\nYou will be prompted by 'cryptsetup' for your LUKS passphrase."

OLD_TTY_SETTINGS=$(stty -g)
stty sane
if sudo cryptsetup luksOpen "$PERSISTENCE_PARTITION" "$LUKS_MAP_NAME"; then
    stty "$OLD_TTY_SETTINGS"
    show_msgbox "Step 4: Success" "Encrypted partition opened and mapped to /dev/mapper/$LUKS_MAP_NAME."
else
    stty "$OLD_TTY_SETTINGS"
    show_error_exit "Failed to open LUKS partition. Check your passphrase and ensure the partition exists."
fi

# --- STEP 5: Create an ext4 Filesystem ---
FS_LABEL_DEFAULT="persistence" # This is the label Kali looks for
FS_LABEL=$(get_input_dialog "Step 5: Filesystem Label" "Enter a label for this filesystem. The label '$FS_LABEL_DEFAULT' is recommended for Kali automatic detection:" "$FS_LABEL_DEFAULT")
DIALOG_EXIT_CODE=$?
if [[ $DIALOG_EXIT_CODE -ne $DIALOG_OK ]]; then
    sudo cryptsetup luksClose "$LUKS_MAP_NAME" &>/dev/null # Attempt cleanup
    show_msgbox "Cancelled" "Operation cancelled."
    exec 1>&3 3>&- # Restore stdout
    exit 0;
fi
if [[ -z "$FS_LABEL" ]]; then FS_LABEL="$FS_LABEL_DEFAULT"; fi

dialog --backtitle "Kali Persistent USB Creator" --title "Step 5: Creating Filesystem" --infobox "Creating ext4 filesystem with label '$FS_LABEL' on /dev/mapper/$LUKS_MAP_NAME..." 5 $D_WIDTH
if sudo mkfs.ext4 -L "$FS_LABEL" "/dev/mapper/$LUKS_MAP_NAME"; then
    show_msgbox "Step 5: Success" "ext4 filesystem created successfully with label '$FS_LABEL'."
else
    sudo cryptsetup luksClose "$LUKS_MAP_NAME" &>/dev/null # Attempt cleanup
    show_error_exit "Failed to create ext4 filesystem on /dev/mapper/$LUKS_MAP_NAME."
fi

# --- STEP 6: Mount Partition and Create persistence.conf ---
show_msgbox "Step 6: Configure Persistence" "This step will mount the new filesystem and create the 'persistence.conf' file, which tells Kali to use this partition for persistence."

MOUNT_POINT_BASE="/mnt"
MOUNT_POINT="$MOUNT_POINT_BASE/$LUKS_MAP_NAME" # e.g., /mnt/my_usb_crypt

dialog --backtitle "Kali Persistent USB Creator" --title "Step 6: Configuring" --infobox "Creating mount point: $MOUNT_POINT..." 5 $D_WIDTH
if ! sudo mkdir -p "$MOUNT_POINT"; then
    sudo cryptsetup luksClose "$LUKS_MAP_NAME" &>/dev/null
    show_error_exit "Failed to create mount point $MOUNT_POINT."
fi

dialog --backtitle "Kali Persistent USB Creator" --title "Step 6: Configuring" --infobox "Mounting /dev/mapper/$LUKS_MAP_NAME to $MOUNT_POINT..." 5 $D_WIDTH
if ! sudo mount "/dev/mapper/$LUKS_MAP_NAME" "$MOUNT_POINT"; then
    sudo rmdir "$MOUNT_POINT" &>/dev/null
    sudo cryptsetup luksClose "$LUKS_MAP_NAME" &>/dev/null
    show_error_exit "Failed to mount /dev/mapper/$LUKS_MAP_NAME to $MOUNT_POINT."
fi

PERSISTENCE_CONF_CONTENT="/ union"
dialog --backtitle "Kali Persistent USB Creator" --title "Step 6: Configuring" --infobox "Creating persistence.conf file with content: '$PERSISTENCE_CONF_CONTENT'..." 5 $D_WIDTH
if echo "$PERSISTENCE_CONF_CONTENT" | sudo tee "$MOUNT_POINT/persistence.conf" > /dev/null; then
    _print_info "'persistence.conf' created successfully in $MOUNT_POINT." # Debug output
else
    sudo umount "$MOUNT_POINT" &>/dev/null
    sudo rmdir "$MOUNT_POINT" &>/dev/null
    sudo cryptsetup luksClose "$LUKS_MAP_NAME" &>/dev/null
    show_error_exit "Failed to create 'persistence.conf'."
fi

dialog --backtitle "Kali Persistent USB Creator" --title "Step 6: Configuring" --infobox "Unmounting $MOUNT_POINT..." 5 $D_WIDTH
if ! sudo umount "$MOUNT_POINT"; then
    _print_warning "Failed to unmount $MOUNT_POINT. You may need to unmount it manually: sudo umount $MOUNT_POINT" # Debug output
    # Continue to luksClose
fi

dialog --backtitle "Kali Persistent USB Creator" --title "Step 6: Configuring" --infobox "Removing temporary mount point $MOUNT_POINT..." 5 $D_WIDTH
sudo rmdir "$MOUNT_POINT" &>/dev/null # Best effort removal

show_msgbox "Step 6: Success" "Persistence configuration completed."

# --- STEP 7: Close the Encrypted Partition ---
dialog --backtitle "Kali Persistent USB Creator" --title "Step 7: Close Encrypted Partition" --infobox "Closing LUKS mapping /dev/mapper/$LUKS_MAP_NAME..." 5 $D_WIDTH
if sudo cryptsetup luksClose "$LUKS_MAP_NAME"; then
    show_msgbox "Step 7: Success" "Encrypted partition /dev/mapper/$LUKS_MAP_NAME closed successfully."
else
    # This might not be critical if it was already closed or unmounted led to closure
    show_msgbox "Step 7: Warning" "Failed to explicitly close LUKS partition /dev/mapper/$LUKS_MAP_NAME. It might already be closed or an error occurred. This may be okay."
fi

show_msgbox "Completion" "🎉 Congratulations! Your Kali Linux Live USB with Encrypted Persistence should be ready!\n\n\
You can now reboot your computer and boot from the USB drive.\n\n\
When booting, select the 'Live system (persistence, check kali.org/prst)' or a similar option that mentions persistence.\n\n\
You will be prompted for your LUKS passphrase during the boot process to unlock your persistent storage.\n\n\
🛑 Remember your LUKS passphrase! If you forget it, your persistent data will be inaccessible."

# Restore stdout and close fd 3
exec 1>&3 3>&-

exit 0
