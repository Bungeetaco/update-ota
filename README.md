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
- 🔄 Automatic tool updates (avbroot, custota-tool, Magisk)
- ✅ File integrity verification
- 📧 Email notifications
- 🔐 Secure credential handling
- 🗑️ Retention policy for old updates
- 🌐 Web directory management for OTA distribution

## Requirements 📋

### System Requirements 🖥️
- Linux-based operating system
- Root access
- Python 3
- `mail` command (optional, for notifications)

### Required Tools 🛠️
- `avbroot`
- `custota-tool`
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

1. Install Python package requirements:
   ```bash
   pip install -r requirements.txt
   ```

2. Create the required directories:
   ```bash
   sudo mkdir -p /etc/android-ota
   sudo mkdir -p /etc/android-ota/keys
   sudo mkdir -p /var/lib/android-ota/ota
   sudo mkdir -p /var/log/android-ota
   sudo mkdir -p /var/run/android-ota
   sudo mkdir -p /var/www/html/ota
   
   # Set proper ownership and permissions for directories
   sudo chown root:root /etc/android-ota
   sudo chmod 755 /etc/android-ota
   sudo chmod 700 /etc/android-ota/keys
   sudo chmod 755 /var/lib/android-ota/ota
   sudo chmod 755 /var/log/android-ota
   sudo chmod 755 /var/run/android-ota
   sudo chmod 755 /var/www/html/ota
   ```