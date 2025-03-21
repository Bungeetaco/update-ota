# Android OTA Update Automation 🤖

A bash script for automating OTA (Over-The-Air) updates for Android devices with support for Magisk and KernelSU root solutions.

## Credits 🙏

This project uses several amazing open-source tools:

- 🔧 [avbroot](https://github.com/chenxiaolong/avbroot) - Sign (and root) Android A/B OTAs with custom keys while preserving Android Verified Boot
- 🔄 [Custota](https://github.com/chenxiaolong/Custota) - Android A/B OTA updater app for custom OTA servers
  - Created by [Andrew Gunnerson (chenxiaolong)](https://github.com/chenxiaolong)

- 🎭 [Magisk](https://github.com/topjohnwu/Magisk) - The Magic Mask for Android
  - Created by [John Wu (topjohnwu)](https://github.com/topjohnwu)

- 🔒 [KernelSU](https://github.com/tiann/KernelSU) - A Kernel based root solution for Android
  - Created by [weishu (tiann)](https://github.com/tiann)

- 📥 [google-ota-download](https://github.com/Bungeetaco/google-ota-download) - Google Android OTA and Factory Image Scraper
  - Used for automated OTA downloads
  - Included in this project and regularly updated from origin

## Features ✨

- 📥 Automated OTA update fetching and patching
- 🔧 Support for multiple rooting solutions:
  - 🎭 Magisk
  - 🔒 KernelSU
  - 🚫 Rootless mode
- 🔄 Automatic tool installation and updates (avbroot, custota-tool, Magisk)
- ✅ File integrity verification
- 📧 Email notifications
- 🔐 Secure credential handling
- 🗑️ Retention policy for old updates
- 🌐 Web directory management for OTA distribution

## Requirements 📋

### System Requirements 🖥️
- Linux-based operating system
- Root access (for initial setup)
- Python 3
- `mail` command (optional, for notifications)
- User must have read/write access to:
  - `/opt/android-ota/` - For tool installation and updates
  - `/opt/android-ota/ota/` - For OTA file storage
  - Web server directory (e.g., `/var/www/ota/`) - For serving OTA files

### Required Tools 🛠️
The following tools are automatically installed and updated by the script:
- `avbroot` (installed in `/opt/android-ota/`)
- `custota-tool` (installed in `/opt/android-ota/`)

System commands required:
- `python3`
- `curl`
- `wget`
- `unzip`
- `jq`

### Python Package Requirements 📦
```bash
pip install -r requirements.txt
```

Required packages:
- `requests>=2.31.0` - 🌐 For HTTP requests
- `beautifulsoup4>=4.12.0` - 🔍 For HTML parsing
- `colorama>=0.4.6` - 🎨 For colored terminal output
- `psutil>=5.9.0` - 📊 For system and process utilities

## Installation 🚀

1. Install system dependencies:
   ```bash
   # For Debian/Ubuntu:
   sudo apt install python3 python3-pip curl wget unzip jq

   # For RHEL/CentOS:
   sudo yum install python3 python3-pip curl wget unzip jq
   ```

2. Install Python package requirements:
   ```bash
   pip install -r requirements.txt
   ```

3. Create the required directories and set permissions:
   ```bash
   # Create main directory and subdirectories
   sudo mkdir -p /opt/android-ota
   sudo mkdir -p /opt/android-ota/keys
   sudo mkdir -p /opt/android-ota/ota
   
   # Set proper ownership and permissions for directories
   sudo chown root:root /opt/android-ota
   sudo chmod 755 /opt/android-ota
   sudo chmod 700 /opt/android-ota/keys
   sudo chmod 755 /opt/android-ota/ota
   
   # Add your user to the appropriate group (example using www-data)
   sudo usermod -a -G www-data $USER
   
   # Set group ownership for directories that need write access
   sudo chown root:www-data /opt/android-ota/ota
   sudo chmod 775 /opt/android-ota/ota
   
   # Create a directory for tool installation
   sudo mkdir -p /opt/android-ota/bin
   sudo chown root:www-data /opt/android-ota/bin
   sudo chmod 775 /opt/android-ota/bin
   ```

4. Configure web server settings:
   ```bash
   # Edit the script to set your web server directory and user/group
   sudo nano /opt/android-ota/update-ota.sh
   
   # Update these variables to match your setup:
   WEB_DIR="/var/www/your-ota-server"    # Your OTA server directory
   WEB_USER="www-data"                   # Web server user (typically www-data)
   WEB_GROUP="www-data"                  # Web server group (typically www-data)
   
   # Create and set permissions for your web directory
   sudo mkdir -p "$WEB_DIR"
   sudo chown "$WEB_USER:$WEB_GROUP" "$WEB_DIR"
   sudo chmod 775 "$WEB_DIR"
   ```

5. Set up cron job for automated updates:
   ```bash
   sudo crontab -e
   
   # Add one of these lines depending on your needs:
   
   # Check for updates daily at 2 AM
   0 2 * * * /opt/android-ota/update-ota.sh --device husky --notify admin@example.com
   ```

   Common cron patterns:
   - `0 2 * * *` - Daily at 2 AM
   - `0 3 * * 0` - Weekly on Sunday at 3 AM
   - `0 */6 * * *` - Every 6 hours
   - `0 2,14 * * *` - Twice daily at 2 AM and 2 PM
   - `0 2 * * 1-5` - Weekdays at 2 AM

   Additional cron options:
   - Add `--verbose` for detailed logging
   - Add `--force` to override lock file if needed
   - Add `--rootless` for no root modifications
   - Add `--kernelsu` to use KernelSU instead of Magisk

   Example with multiple options:
   ```bash
   0 2 * * * /opt/android-ota/update-ota.sh --device husky --verbose --notify admin@example.com
   ```

   Note: Make sure the script has executable permissions:
   ```bash
   sudo chmod +x /opt/android-ota/update-ota.sh
   ```

## Configuration ⚙️

### Web Server Settings 🌐
The script needs to know where to serve the OTA files and which user/group should own them. Edit these variables in the script:
```bash
WEB_DIR="/var/www/your-ota-server"    # Your OTA server directory
WEB_USER="www-data"                   # Web server user (typically www-data)
WEB_GROUP="www-data"                  # Web server group (typically www-data)
```
Common web server configurations:
- Apache: `/var/www/html/ota` with `www-data:www-data`
- Nginx: `/var/www/ota` with `www-data:www-data`
- Custom: Set to match your web server's configuration

### Script Configuration Variables 🔧
The following variables can be customized in the script:

```bash
# Default values and their purposes:
DEVICE="husky"                        # Default device codename
FORCE=false                          # Force update even if locked
INTERACTIVE=false                    # Run in interactive mode
KEYS_DIR="/opt/android-ota/keys"     # Directory for encryption keys
KERNELSU_BOOT="/opt/android-ota/kernelsu_boot.img"  # KernelSU boot image path
LOCK_FILE="/opt/android-ota/update-ota.lock"        # Lock file location
LOG_FILE="/opt/android-ota/update-ota.log"          # Log file location
MAGISK_APK="/opt/android-ota/Magisk-v28.1.apk"      # Magisk APK location
MAGISK_PREINIT_DEVICE="sda10"        # Magisk preinit device
NOTIFY_EMAIL=""                      # Email for notifications
OTA_DIR="/opt/android-ota/ota"       # OTA files directory
PYTHON_SCRIPT="download.py"          # Python download script name
RETENTION_DAYS=31                    # Days to keep old updates
ROOTLESS=false                       # Use rootless mode
SCRIPT_DIR="/opt/android-ota"        # Main script directory
USE_KERNELSU=false                   # Use KernelSU instead of Magisk
VERBOSE=false                        # Enable verbose logging
```

### Tool Installation and Updates 🔄
The script automatically handles the installation and updates of required tools:
- `avbroot` and `custota-tool` are installed in `/opt/android-ota/`
- Tools are automatically downloaded from their respective GitHub repositories
- Version checks are performed on each run to ensure tools are up to date
- Tools are installed with appropriate permissions (777) for system-wide access

### Email Notifications 📧
To set up email notifications:

1. Install the mail command:
   ```bash
   # For Debian/Ubuntu:
   sudo apt install mailutils
   
   # For RHEL/CentOS:
   sudo yum install mailx
   ```

2. Configure your mail settings:
   ```bash
   # Edit the mail configuration
   sudo nano /etc/mail.rc
   
   # Add your SMTP settings (example for Gmail):
   set smtp=smtp.gmail.com:587
   set smtp-use-starttls
   set ssl-verify=ignore
   set from=your-email@gmail.com
   ```

3. Set up the notification email in the script:
   ```bash
   # Edit the script
   sudo nano /opt/android-ota/update-ota.sh
   
   # Set your notification email
   NOTIFY_EMAIL="your-email@example.com"
   ```

4. Test the email notification:
   ```bash
   # Run the script with --verbose to see email details
   sudo /opt/android-ota/update-ota.sh --device husky --verbose --notify your-email@example.com
   ```

Note: For Gmail, you'll need to:
1. Enable 2-factor authentication
2. Generate an App Password
3. Use the App Password in your mail configuration

## Directory Structure 📁
```
/opt/android-ota/           # Main directory
├── avbroot               # avbroot executable (auto-installed)
├── custota-tool         # custota-tool executable (auto-installed)
├── credentials          # Credentials file (600 permissions)
├── keys/               # Directory containing encryption keys
│   ├── avb.key
│   ├── ota.key
│   └── ota.crt
├── kernelsu_boot.img   # (Optional) KernelSU boot image
├── Magisk-v*.apk      # Magisk APK file (auto-updated)
├── ota/               # Directory for OTA files
├── update-ota.log     # Log file
├── update-ota.lock    # Lock file
├── update-ota.sh      # Main script
└── download.py        # Python download script
```

## Security 🔒
- Base directory (`/opt/android-ota`) permissions: 755 (drwxr-xr-x)
- Keys directory (`/opt/android-ota/keys`) permissions: 700 (drwx------)
- OTA directory (`/opt/android-ota/ota`) permissions: 775 (drwxrwxr-x)
- Tool directory (`/opt/android-ota/bin`) permissions: 775 (drwxrwxr-x)
- Web directory permissions: 775 (drwxrwxr-x)
- Credentials file permissions: 600 (-rw-------)
- Private key files permissions: 600 (-rw-------)
- Public certificate permissions: 644 (-rw-r--r--)
- Log file permissions: 640 (-rw-r-----)
- Tool executables permissions: 775 (-rwxrwxr-x)
- Magisk APK permissions: 644 (-rw-r--r--)
- KernelSU boot image permissions: 600 (-rw-------)
- Script uses secure environment variables for passphrases
- Implements file locking to prevent concurrent runs
- Validates file integrity with checksums
- Directory ownership and group permissions ensure proper access control
- Sensitive directories and files are only accessible by root
- Write access to required directories is granted through group membership

### Directory Access Requirements 📂
The script requires specific access permissions to function properly:

1. Root Access:
   - Initial setup and directory creation
   - Managing tool installations
   - Setting file permissions
   - Reading private keys and credentials

2. User Access:
   - Must be a member of the web server group (e.g., `www-data`)
   - Read/write access to:
     - `/opt/android-ota/ota/` - For OTA file storage
     - `/opt/android-ota/bin/` - For tool installation
     - Web server directory - For serving OTA files
   - Read-only access to:
     - Tool executables
     - Public certificates
     - Configuration files

3. Web Server Access:
   - Read/write access to web directory
   - Read access to OTA files and signatures

To verify your access permissions:
```bash
# Check group membership
groups $USER

# Verify directory access
ls -l /opt/android-ota/
ls -l /opt/android-ota/ota/
ls -l /opt/android-ota/bin/
ls -l $WEB_DIR

# Test write permissions
touch /opt/android-ota/ota/test.txt
touch /opt/android-ota/bin/test.txt
touch $WEB_DIR/test.txt
rm /opt/android-ota/ota/test.txt
rm /opt/android-ota/bin/test.txt
rm $WEB_DIR/test.txt
```

## Logging 📝
The script logs all operations to `/opt/android-ota/update-ota.log`. Use `--verbose` for detailed logging.

## Contributing 🤝
Feel free to submit issues and pull requests.

## License 📄
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.