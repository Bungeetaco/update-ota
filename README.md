# Android OTA Update Automation

A bash script for automating OTA (Over-The-Air) updates for Android devices with support for Magisk and KernelSU root solutions.

## Features

- Automated OTA update fetching and patching
- Support for multiple rooting solutions:
  - Magisk
  - KernelSU
  - Rootless mode
- Automatic tool updates (avbroot, custota-tool, Magisk)
- File integrity verification
- Email notifications
- Secure credential handling
- Retention policy for old updates
- Web directory management for OTA distribution

## Requirements

### System Requirements
- Linux-based operating system
- Root access
- Python 3
- `mail` command (optional, for notifications)

### Required Tools
- `avbroot`
- `custota-tool`
- `python3`
- `curl`
- `wget`
- `unzip`
- `jq`

### Directory Structure
```
/opt/android-ota/
├── credentials         # Credentials file (600 permissions)
├── keys/              # Directory containing encryption keys
│   ├── avb.key
│   ├── ota.key
│   └── ota.crt
├── kernelsu_boot.img  # (Optional) KernelSU boot image
├── Magisk-v*.apk     # Magisk APK file
├── ota/              # Directory for OTA files
├── update-ota.log    # Log file
└── download.py       # Python download script
```

## Installation

1. Create the required directories:
   ```bash
   sudo mkdir -p /opt/android-ota
   sudo mkdir -p /opt/android-ota/keys
   sudo mkdir -p /opt/android-ota/ota
   sudo mkdir -p /var/www/ota.yourdomain.com
   
   # Set proper ownership and permissions for directories
   sudo chown root:root /opt/android-ota
   sudo chmod 755 /opt/android-ota
   sudo chmod 700 /opt/android-ota/keys
   sudo chmod 755 /opt/android-ota/ota
   ```

2. Set up the credentials file:
   ```bash
   sudo touch /opt/android-ota/credentials
   sudo chown root:root /opt/android-ota/credentials
   sudo chmod 600 /opt/android-ota/credentials
   ```

3. Add required credentials to `/opt/android-ota/credentials`:
   ```bash
   PASSPHRASE_AVB="your_avb_passphrase"
   PASSPHRASE_OTA="your_ota_passphrase"
   ```

4. Place your encryption keys in the `/opt/android-ota/keys/` directory and set proper permissions:
   ```bash
   # Copy your keys
   sudo cp avb.key ota.key ota.crt /opt/android-ota/keys/
   
   # Set ownership to root
   sudo chown root:root /opt/android-ota/keys/*
   
   # Set restrictive permissions on private keys
   sudo chmod 600 /opt/android-ota/keys/avb.key
   sudo chmod 600 /opt/android-ota/keys/ota.key
   
   # Set permissions on public certificate
   sudo chmod 644 /opt/android-ota/keys/ota.crt
   ```

5. Set proper permissions for the log file:
   ```bash
   sudo touch /opt/android-ota/update-ota.log
   sudo chown root:root /opt/android-ota/update-ota.log
   sudo chmod 640 /opt/android-ota/update-ota.log
   ```

6. If using Magisk, set proper permissions for the APK:
   ```bash
   sudo chown root:root /opt/android-ota/Magisk-v*.apk
   sudo chmod 644 /opt/android-ota/Magisk-v*.apk
   ```

7. If using KernelSU, set proper permissions for the boot image:
   ```bash
   sudo chown root:root /opt/android-ota/kernelsu_boot.img
   sudo chmod 600 /opt/android-ota/kernelsu_boot.img
   ```

## Usage

Basic usage:
```bash
sudo ./update-ota.sh --device DEVICE_CODENAME
```

Available options:
- `--device`, `-d`: Specify device codename (e.g., husky)
- `--rootless`: Use rootless mode (no root modifications)
- `--kernelsu`: Use KernelSU instead of Magisk
- `--verbose`, `-v`: Enable verbose logging
- `--force`, `-f`: Force update even if another instance is running
- `--notify EMAIL`: Send email notifications to specified address

Examples:
```bash
# Update Pixel 8 Pro (husky) with Magisk
sudo ./update-ota.sh --device husky

# Update with KernelSU
sudo ./update-ota.sh --device husky --kernelsu

# Update without root modifications
sudo ./update-ota.sh --device husky --rootless

# Enable verbose logging and notifications
sudo ./update-ota.sh --device husky --verbose --notify admin@example.com
```

## Configuration

The script uses several configurable variables at the beginning of the file. Key configurations include:

- `DEVICE`: Default device codename
- `MAGISK_PREINIT_DEVICE`: Device partition for Magisk preinit
- `RETENTION_DAYS`: Number of days to keep old OTA files
- `WEB_DIR`: Directory for serving OTA updates
- `WEB_USER` and `WEB_GROUP`: Web server user/group ownership

## Security

- Base directory (`/opt/android-ota`) permissions: 755 (drwxr-xr-x)
- Keys directory (`/opt/android-ota/keys`) permissions: 700 (drwx------)
- Credentials file permissions: 600 (-rw-------)
- Private key files permissions: 600 (-rw-------)
- Public certificate permissions: 644 (-rw-r--r--)
- Log file permissions: 640 (-rw-r-----)
- Magisk APK permissions: 644 (-rw-r--r--)
- KernelSU boot image permissions: 600 (-rw-------)
- Script uses secure environment variables for passphrases
- Implements file locking to prevent concurrent runs
- Validates file integrity with checksums

## Logging

The script logs all operations to `/opt/android-ota/update-ota.log`. Use `--verbose` for detailed logging.

## Contributing

Feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 