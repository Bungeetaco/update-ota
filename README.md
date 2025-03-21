# Android OTA Update Automation

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

### Python Package Requirements
```bash
pip install -r requirements.txt
```

Required packages:
- `requests>=2.31.0` - For HTTP requests
- `beautifulsoup4>=4.12.0` - For HTML parsing
- `colorama>=0.4.6` - For colored terminal output
- `psutil>=5.9.0` - For system and process utilities

## Installation

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