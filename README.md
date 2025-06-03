# Auto-Mount

A simple Bash script to easily mount external drives on Ubuntu and other Linux distributions.

## Overview

Auto-Mount is a user-friendly command-line tool that simplifies the process of mounting external drives. It automatically detects unmounted drives, provides a simple selection interface, and handles common mounting issues.

## Features

- 🔍 Automatically detects unmounted drives
- 📋 Lists available drives with filesystem information
- 🛠️ Handles NTFS drives with Windows fast startup issues
- 🖥️ Opens the file manager after mounting
- 🔄 Easy unmounting of previously mounted drives
- 🎨 Color-coded output for better readability

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/arashsalekah/auto-mount.git
   ```

2. Make the script executable:
   ```bash
   chmod +x auto-mount.sh
   ```

## Usage

Simply run the script:

```bash
./auto-mount.sh
```

The script will:

1. Show any currently mounted drive at `/mnt/external` with an option to unmount
2. Display a list of unmounted drives with details
3. Prompt you to select a drive to mount
4. Mount the selected drive to `/mnt/external` and open in file manager
5. Offer to fix NTFS drives with Windows fast startup issues

## Requirements

- Linux distribution (tested on Ubuntu)
- `sudo` privileges (for mounting operations)
- Standard command-line utilities: `lsblk`, `mount`, `umount`
- Optional: `ntfsfix` for handling NTFS drives

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project is licensed under the [MIT License](LICENSE).
