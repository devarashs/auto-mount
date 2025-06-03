#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_color $RED "This script should not be run as root directly."
        print_color $YELLOW "It will ask for sudo permission when needed."
        exit 1
    fi
}

# Function to get unmounted drives
get_unmounted_drives() {
    # Get all block devices that are not mounted and not the root partition
    lsblk -rno NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT | grep -E "sd[a-z][0-9]|nvme[0-9]n[0-9]p[0-9]" | while read line; do
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        label=$(echo "$line" | awk '{print $3}')
        fstype=$(echo "$line" | awk '{print $4}')
        mountpoint=$(echo "$line" | awk '{print $5}')

        # Skip if already mounted or if it's the root partition
        if [[ -z "$mountpoint" && "$mountpoint" != "/" && "$mountpoint" != "/boot/efi" ]]; then
            # Only show drives with filesystem
            if [[ -n "$fstype" ]]; then
                echo "/dev/$name|$size|$label|$fstype"
            fi
        fi
    done
}

# Function to display drives menu
display_drives() {
    print_color $BLUE "Available unmounted drives:"
    echo "=================================="

    local counter=1
    local drives=()

    while IFS='|' read -r device size label fstype; do
        # Extract just the device name (e.g., sda1 from /dev/sda1)
        device_name=$(basename "$device")

        if [[ -n "$label" ]]; then
            printf "[%d] %s (%s) - %s [%s]\n" "$counter" "$device_name" "$label" "$size" "$fstype"
        else
            printf "[%d] %s - %s [%s]\n" "$counter" "$device_name" "$size" "$fstype"
        fi
        drives+=("$device")
        ((counter++))
    done < <(get_unmounted_drives)

    if [[ ${#drives[@]} -eq 0 ]]; then
        print_color $YELLOW "No unmounted drives found."
        exit 0
    fi

    echo "=================================="
    printf "q) Quit\n\n"

    # Return drives array
    printf '%s\n' "${drives[@]}"
}

# Function to mount drive
mount_drive() {
    local device="$1"
    local mount_point="/mnt/external"

    print_color $YELLOW "Mounting $device to $mount_point..."

    # Create mount point if it doesn't exist
    if ! sudo mkdir -p "$mount_point" 2>/dev/null; then
        print_color $RED "Failed to create mount point $mount_point"
        return 1
    fi

    # Check if mount point is already in use
    if mountpoint -q "$mount_point"; then
        print_color $YELLOW "Mount point $mount_point is already in use."
        read -p "Do you want to unmount it first? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if ! sudo umount "$mount_point"; then
                print_color $RED "Failed to unmount $mount_point"
                return 1
            fi
        else
            print_color $RED "Aborted."
            return 1
        fi
    fi

    # Attempt to mount the drive
    if sudo mount "$device" "$mount_point"; then
        print_color $GREEN "Successfully mounted $device to $mount_point"

        # Try to open the folder in file manager
        if command -v xdg-open &> /dev/null; then
            print_color $BLUE "Opening folder in file manager..."
            xdg-open "$mount_point" &
        elif command -v nautilus &> /dev/null; then
            print_color $BLUE "Opening folder in Nautilus..."
            nautilus "$mount_point" &
        else
            print_color $YELLOW "File manager not found. You can access your drive at: $mount_point"
        fi

        print_color $GREEN "Drive is now available at: $mount_point"
        return 0
    else
        print_color $RED "Failed to mount $device"
        print_color $YELLOW "This might be due to:"
        print_color $YELLOW "- Windows fast startup (try: sudo ntfsfix $device)"
        print_color $YELLOW "- Dirty filesystem state"
        print_color $YELLOW "- Permission issues"

        # Offer to try ntfsfix for NTFS drives
        local fstype=$(lsblk -no FSTYPE "$device" 2>/dev/null)
        if [[ "$fstype" == "ntfs" ]]; then
            echo
            read -p "This appears to be an NTFS drive. Try to fix with ntfsfix? (y/N): " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                print_color $YELLOW "Running ntfsfix on $device..."
                if sudo ntfsfix "$device"; then
                    print_color $GREEN "ntfsfix completed. Trying to mount again..."
                    if sudo mount "$device" "$mount_point"; then
                        print_color $GREEN "Successfully mounted $device to $mount_point after fix!"
                        if command -v xdg-open &> /dev/null; then
                            xdg-open "$mount_point" &
                        fi
                        return 0
                    fi
                fi
            fi
        fi
        return 1
    fi
}

# Function to show unmount option
show_unmount_option() {
    echo
    print_color $BLUE "Mounted drives at /mnt/external:"
    if mountpoint -q "/mnt/external"; then
        local mounted_device=$(findmnt -n -o SOURCE /mnt/external)
        print_color $GREEN "/mnt/external -> $mounted_device"
        echo
        read -p "Do you want to unmount /mnt/external? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if sudo umount /mnt/external; then
                print_color $GREEN "Successfully unmounted /mnt/external"
            else
                print_color $RED "Failed to unmount /mnt/external"
            fi
        fi
    else
        print_color $YELLOW "No drives mounted at /mnt/external"
    fi
}

# Main function
main() {
    check_root

    print_color $GREEN "External Drive Mount Helper"
    print_color $GREEN "=========================="
    echo

    # Show unmount option first if something is mounted
    if mountpoint -q "/mnt/external"; then
        show_unmount_option
        echo
    fi

    # Get and display available drives
    mapfile -t available_drives < <(display_drives)

    # Remove the header text and get only device paths
    local drives=()
    for item in "${available_drives[@]}"; do
        if [[ "$item" =~ ^/dev/ ]]; then
            drives+=("$item")
        fi
    done

    if [[ ${#drives[@]} -eq 0 ]]; then
        exit 0
    fi

    # Get user choice
    # Display the drives list with details for selection
    echo "Select drive to mount:"
    for idx in "${!drives[@]}"; do
        # Get drive info for display
        drive_info=$(lsblk -rno NAME,SIZE,LABEL,FSTYPE "${drives[$idx]}" | head -n1)
        name=$(echo "$drive_info" | awk '{print $1}')
        size=$(echo "$drive_info" | awk '{print $2}')
        label=$(echo "$drive_info" | awk '{print $3}')
        fstype=$(echo "$drive_info" | awk '{print $4}')
        if [[ -n "$label" ]]; then
            printf "[%d] %s (%s) - %s [%s]\n" "$((idx+1))" "$name" "$label" "$size" "$fstype"
        else
            printf "[%d] %s - %s [%s]\n" "$((idx+1))" "$name" "$size" "$fstype"
        fi
    done

    while true; do
        read -p "Select drive to mount (1-${#drives[@]}) or 'q' to quit: " choice

        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
            print_color $YELLOW "Goodbye!"
            exit 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#drives[@]}" ]]; then
            selected_drive="${drives[$((choice-1))]}"
            mount_drive "$selected_drive"
            break
        else
            print_color $RED "Invalid choice. Please enter a number between 1 and ${#drives[@]}, or 'q' to quit."
        fi
    done
}

# Run main function
main "$@"