#!/bin/bash

# Determine installation type and set paths
if [ "$EUID" -eq 0 ]; then
    # Root installation
    INSTALL_DIR="/opt/android-ota"
    WEB_DIR="/var/www/ota"
    WEB_USER="www-data"
    WEB_GROUP="www-data"
else
    # Non-root installation
    INSTALL_DIR="$HOME/android-ota"
    WEB_DIR="$HOME/public_html/ota"  # Adjust this path as needed
    WEB_USER="$USER"
    WEB_GROUP="$USER"
fi

# Configuration
CREDENTIALS_FILE="$INSTALL_DIR/credentials"
DEVICE="husky"  # Default device, can be overridden with --device argument
FORCE=false
INTERACTIVE=false
KEYS_DIR="$INSTALL_DIR/keys"
KERNELSU_BOOT="$INSTALL_DIR/kernelsu_boot.img"
LOCK_FILE="$INSTALL_DIR/update-ota.lock"
LOG_FILE="$INSTALL_DIR/update-ota.log"
MAGISK_APK="$INSTALL_DIR/Magisk-v28.1.apk"
MAGISK_PREINIT_DEVICE="sda10"
NOTIFY_EMAIL=""
OTA_DIR="$INSTALL_DIR/ota"
PYTHON_SCRIPT="download.py"
RETENTION_DAYS=31
ROOTLESS=false
SCRIPT_DIR="$INSTALL_DIR"
USE_KERNELSU=false
VERBOSE=false

# Tool paths - always use /opt/android-ota/
AVBROOT="/opt/android-ota/avbroot"
CUSTOTA_TOOL="/opt/android-ota/custota-tool"

# Function to log messages with different levels
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format message based on level
    case "$level" in
        "INFO")
            echo -e "\033[0;32m[INFO]\033[0m $message"
            ;;
        "WARN")
            echo -e "\033[0;33m[WARN]\033[0m $message"
            ;;
        "ERROR")
            echo -e "\033[0;31m[ERROR]\033[0m $message"
            ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "\033[0;36m[DEBUG]\033[0m $message"
            fi
            ;;
    esac
    
    # Always log to file
    echo "$timestamp - [$level] $message" >> "$LOG_FILE"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "ERROR" "Required command '$1' not found"
        exit 1
    fi
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        log "ERROR" "Required file '$1' not found"
        exit 1
    fi
}

# Function to check if a directory exists
check_dir() {
    if [ ! -d "$1" ]; then
        log "ERROR" "Required directory '$1' not found"
        exit 1
    fi
}

# Function to send email notification
send_notification() {
    local subject="$1"
    local body="$2"
    
    if [ -n "$NOTIFY_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$body" | mail -s "$subject" "$NOTIFY_EMAIL"
    fi
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    local signal=$1
    
    # Remove lock file if we created it
    if [ -f "$LOCK_FILE" ] && [ "$(cat "$LOCK_FILE")" = "$$" ]; then
        rm -f "$LOCK_FILE"
    fi
    
    # Clear sensitive variables from memory
    unset PASSPHRASE_AVB
    unset PASSPHRASE_OTA
    
    # Log exit reason
    if [ -n "$signal" ]; then
        log "INFO" "Script terminated by signal $signal"
    else
        log "INFO" "Script exited with code $exit_code"
    fi
    
    # Send notification if running non-interactively
    if [ "$INTERACTIVE" = false ]; then
        if [ $exit_code -eq 0 ]; then
            send_notification "OTA Update Success" "The OTA update process completed successfully."
        else
            send_notification "OTA Update Failed" "The OTA update process failed with exit code $exit_code. Check $LOG_FILE for details."
        fi
    fi
    
    exit $exit_code
}

# Set up trap for cleanup
trap 'cleanup' EXIT
trap 'cleanup SIGINT' SIGINT
trap 'cleanup SIGTERM' SIGTERM

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --device|-d)
            DEVICE="$2"
            shift 2
            ;;
        --rootless)
            ROOTLESS=true
            shift
            ;;
        --kernelsu)
            USE_KERNELSU=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --notify)
            NOTIFY_EMAIL="$2"
            shift 2
            ;;
        *)
            log "ERROR" "Unknown argument: $1"
            log "INFO" "Usage: $0 [--device|-d DEVICE] [--rootless] [--kernelsu] [--verbose|-v] [--force|-f] [--notify EMAIL]"
            exit 1
            ;;
    esac
done

# Check if running interactively
if [ -t 0 ]; then
    INTERACTIVE=true
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR" "This script must be run as root"
    exit 1
fi

# Check for lock file if not forcing
if [ -f "$LOCK_FILE" ] && [ "$FORCE" = false ]; then
    pid=$(cat "$LOCK_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        log "ERROR" "Another instance is running (PID: $pid)"
        exit 1
    else
        log "WARN" "Stale lock file found, removing..."
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo "$$" > "$LOCK_FILE"

# Check for required commands
log "INFO" "Checking required commands..."
check_command "python3"
check_command "curl"
check_command "wget"
check_command "unzip"
check_command "jq"

# Function to download and install tool
install_tool() {
    local tool_name="$1"
    local tool_path="$2"
    local latest_build="$3"
    local zip_name="$4"
    
    log "INFO" "Downloading and installing $tool_name..."
    if ! wget "https://github.com/chenxiaolong/$tool_name/releases/download/v$latest_build/$zip_name" -P "$WORKING_DIR"; then
        log "ERROR" "Failed to download $tool_name"
        exit 1
    fi
    
    sudo rm -f "$tool_path"
    sudo unzip -j "$WORKING_DIR/$zip_name" "$tool_name" -d /opt/android-ota
    sudo chmod 777 "$tool_path"
    
    rm "$WORKING_DIR/$zip_name"
    log "INFO" "$tool_name installed successfully"
}

# Create working directory for updates if it doesn't exist
WORKING_DIR="$SCRIPT_DIR/updates"
mkdir -p "$WORKING_DIR"

# Get latest versions
latest_avb_build=$(curl -s https://api.github.com/repos/chenxiaolong/avbroot/releases/latest | jq -r .tag_name | sed 's/^v//')
latest_cust_build=$(curl -s https://api.github.com/repos/chenxiaolong/Custota/releases/latest | jq -r .tag_name | sed 's/^v//')

# Check and install avbroot if missing
if [ ! -f "$AVBROOT" ]; then
    install_tool "avbroot" "$AVBROOT" "$latest_avb_build" "avbroot-$latest_avb_build-x86_64-unknown-linux-gnu.zip"
fi

# Check and install custota-tool if missing
if [ ! -f "$CUSTOTA_TOOL" ]; then
    install_tool "custota-tool" "$CUSTOTA_TOOL" "$latest_cust_build" "custota-tool-$latest_cust_build-x86_64-unknown-linux-gnu.zip"
fi

# Verify tools are now available
if [ ! -f "$AVBROOT" ]; then
    log "ERROR" "Failed to install avbroot"
    exit 1
fi
if [ ! -f "$CUSTOTA_TOOL" ]; then
    log "ERROR" "Failed to install custota-tool"
    exit 1
fi

# Check if credentials file exists and has correct permissions
if [ ! -f "$CREDENTIALS_FILE" ]; then
    log "ERROR" "Credentials file not found at $CREDENTIALS_FILE"
    exit 1
fi

if [ "$(stat -c %a "$CREDENTIALS_FILE")" != "600" ]; then
    log "ERROR" "Credentials file must have permissions 600"
    exit 1
fi

# Source credentials file
source "$CREDENTIALS_FILE"

# Check if required passwords are set
if [ -z "$PASSPHRASE_AVB" ]; then
    log "ERROR" "PASSPHRASE_AVB environment variable not set"
    exit 1
fi
if [ -z "$PASSPHRASE_OTA" ]; then
    log "ERROR" "PASSPHRASE_OTA environment variable not set"
    exit 1
fi

# Check if device is set
if [ -z "$DEVICE" ]; then
    log "ERROR" "DEVICE environment variable not set"
    exit 1
fi

# Create necessary directories
log "INFO" "Creating necessary directories..."
mkdir -p "$OTA_DIR" "$KEYS_DIR" "$WEB_DIR"

# Check for updates to required tools
log "INFO" "Checking for updates to required tools..."

# Get current versions
current_avb_build=$(cat "$WORKING_DIR/currentavbbuild.txt" 2>/dev/null || echo "")
current_cust_build=$(cat "$WORKING_DIR/currentcustbuild.txt" 2>/dev/null || echo "")
current_magisk_build=$(cat "$WORKING_DIR/currentmagiskbuild.txt" 2>/dev/null || echo "")

# Get latest versions
latest_magisk_build=$(curl -s https://api.github.com/repos/topjohnwu/magisk/releases/latest | jq -r .tag_name)

# Check and update avbroot if needed
if [[ ! "$latest_avb_build" == "$current_avb_build" ]]; then
    log "INFO" "Updating avbroot to version $latest_avb_build..."
    if ! wget "https://github.com/chenxiaolong/avbroot/releases/download/v$latest_avb_build/avbroot-$latest_avb_build-x86_64-unknown-linux-gnu.zip" -P "$WORKING_DIR"; then
        log "ERROR" "Failed to download avbroot update"
        exit 1
    fi
    
    # Always install to /opt/android-ota/
    sudo rm -f /opt/android-ota/avbroot
    sudo unzip -j "$WORKING_DIR/avbroot-$latest_avb_build-x86_64-unknown-linux-gnu.zip" avbroot -d /opt/android-ota
    sudo chmod 777 /opt/android-ota/avbroot
    
    rm "$WORKING_DIR/avbroot-$latest_avb_build-x86_64-unknown-linux-gnu.zip"
    echo "$latest_avb_build" > "$WORKING_DIR/currentavbbuild.txt"
    log "INFO" "avbroot updated successfully"
fi

# Check and update custota-tool if needed
if [[ ! "$latest_cust_build" == "$current_cust_build" ]]; then
    log "INFO" "Updating custota-tool to version $latest_cust_build..."
    if ! wget "https://github.com/chenxiaolong/Custota/releases/download/v$latest_cust_build/custota-tool-$latest_cust_build-x86_64-unknown-linux-gnu.zip" -P "$WORKING_DIR"; then
        log "ERROR" "Failed to download custota-tool update"
        exit 1
    fi
    
    # Always install to /opt/android-ota/
    sudo rm -f /opt/android-ota/custota-tool
    sudo unzip -j "$WORKING_DIR/custota-tool-$latest_cust_build-x86_64-unknown-linux-gnu.zip" custota-tool -d /opt/android-ota
    sudo chmod 777 /opt/android-ota/custota-tool
    
    rm "$WORKING_DIR/custota-tool-$latest_cust_build-x86_64-unknown-linux-gnu.zip"
    echo "$latest_cust_build" > "$WORKING_DIR/currentcustbuild.txt"
    log "INFO" "custota-tool updated successfully"
fi

# Check and update Magisk if needed
if [[ ! "$latest_magisk_build" == "$current_magisk_build" ]] || [ ! -f "$MAGISK_APK" ]; then
    log "INFO" "Updating Magisk to version $latest_magisk_build..."
    if ! wget "https://github.com/topjohnwu/Magisk/releases/download/$latest_magisk_build/Magisk-$latest_magisk_build.apk" -P "$WORKING_DIR"; then
        log "ERROR" "Failed to download Magisk update"
        exit 1
    fi
    # Remove old Magisk APK if it exists
    rm -f "$MAGISK_APK"
    # Move the downloaded file to the correct location
    mv "$WORKING_DIR/Magisk-$latest_magisk_build.apk" "$MAGISK_APK"
    echo "$latest_magisk_build" > "$WORKING_DIR/currentmagiskbuild.txt"
    log "INFO" "Magisk updated successfully"
fi

# Check for required files
log "INFO" "Checking required files..."
check_file "$SCRIPT_DIR/$PYTHON_SCRIPT"
if [ "$USE_KERNELSU" = true ]; then
    check_file "$KERNELSU_BOOT"
elif [ "$ROOTLESS" = false ]; then
    check_file "$MAGISK_APK"
fi
check_file "$KEYS_DIR/avb.key"
check_file "$KEYS_DIR/ota.key"
check_file "$KEYS_DIR/ota.crt"

# Check if magisk-preinit-device is set
if [ -z "$MAGISK_PREINIT_DEVICE" ]; then
    log "ERROR" "MAGISK_PREINIT_DEVICE environment variable not set"
    exit 1
fi

# Check if web directory exists and is writable
if [ ! -d "$WEB_DIR" ]; then
    log "ERROR" "Web directory '$WEB_DIR' not found"
    exit 1
fi

if [ ! -w "$WEB_DIR" ]; then
    log "ERROR" "Web directory '$WEB_DIR' is not writable"
    exit 1
fi

# Start OTA update process
log "INFO" "Starting OTA update process for device: $DEVICE"

# Check if file exists and verify hash
if [ -f "$OTA_FILE" ]; then
    log "INFO" "OTA file already exists: $OTA_FILENAME"
    if [ -n "$OTA_CHECKSUM" ]; then
        log "INFO" "Verifying file hash..."
        if python3 "$SCRIPT_DIR/$PYTHON_SCRIPT" --verify-hash "$OTA_FILE" "$OTA_CHECKSUM"; then
            log "INFO" "File hash matches, skipping download"
        else
            log "INFO" "File hash mismatch, will re-download"
            rm -f "$OTA_FILE"
        fi
    else
        log "INFO" "No checksum available, skipping download"
    fi
fi

# Fetch latest OTA if needed
if [ ! -f "$OTA_FILE" ]; then
    log "INFO" "Fetching latest OTA for $DEVICE..."
    if [ "$INTERACTIVE" = true ]; then
        OTA_INFO=$(python3 "$SCRIPT_DIR/$PYTHON_SCRIPT" --device "$DEVICE" --output "$OTA_DIR/" --json)
    else
        OTA_INFO=$(python3 "$SCRIPT_DIR/$PYTHON_SCRIPT" --device "$DEVICE" --output "$OTA_DIR/" --json --non-interactive)
    fi

    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to fetch OTA information"
        exit 1
    fi

    # Parse the JSON output to get filename and checksum
    OTA_FILENAME=$(echo "$OTA_INFO" | jq -r '.filename')
    OTA_CHECKSUM=$(echo "$OTA_INFO" | jq -r '.checksum')
    OTA_FILE="$OTA_DIR/$OTA_FILENAME"
fi

# Get the downloaded OTA filename
OTA_FILE=$(ls -t "$OTA_DIR"/*.zip 2>/dev/null | head -n1)
if [ -z "$OTA_FILE" ]; then
    log "ERROR" "No OTA file found in $OTA_DIR"
    exit 1
fi

# Generate output filename without timestamp
PATCHED_OTA="$OTA_DIR/$(basename "$OTA_FILE" .zip | sed 's/_patched$//').patched.zip"

# Check if patched OTA already exists
if [ -f "$PATCHED_OTA" ]; then
    log "INFO" "Previous patched OTA found: $PATCHED_OTA"
fi

# Patch OTA with Magisk or KernelSU
log "INFO" "Patching OTA..."
if [ "$ROOTLESS" = true ]; then
    log "INFO" "Using rootless mode (no Magisk/KernelSU)"
    PASSPHRASE_AVB="$PASSPHRASE_AVB" PASSPHRASE_OTA="$PASSPHRASE_OTA" "$AVBROOT" ota patch \
        --input "$OTA_FILE" \
        --output "$PATCHED_OTA" \
        --rootless \
        --key-avb "$KEYS_DIR/avb.key" \
        --key-ota "$KEYS_DIR/ota.key" \
        --cert-ota "$KEYS_DIR/ota.crt" \
        --pass-avb-env-var PASSPHRASE_AVB \
        --pass-ota-env-var PASSPHRASE_OTA
elif [ "$USE_KERNELSU" = true ]; then
    log "INFO" "Using KernelSU for root access"
    PASSPHRASE_AVB="$PASSPHRASE_AVB" PASSPHRASE_OTA="$PASSPHRASE_OTA" "$AVBROOT" ota patch \
        --input "$OTA_FILE" \
        --output "$PATCHED_OTA" \
        --prepatched "$KERNELSU_BOOT" \
        --key-avb "$KEYS_DIR/avb.key" \
        --key-ota "$KEYS_DIR/ota.key" \
        --cert-ota "$KEYS_DIR/ota.crt" \
        --pass-avb-env-var PASSPHRASE_AVB \
        --pass-ota-env-var PASSPHRASE_OTA
else
    log "INFO" "Using Magisk for root access"
    PASSPHRASE_AVB="$PASSPHRASE_AVB" PASSPHRASE_OTA="$PASSPHRASE_OTA" "$AVBROOT" ota patch \
        --input "$OTA_FILE" \
        --output "$PATCHED_OTA" \
        --magisk "$MAGISK_APK" \
        --magisk-preinit-device "$MAGISK_PREINIT_DEVICE" \
        --key-avb "$KEYS_DIR/avb.key" \
        --key-ota "$KEYS_DIR/ota.key" \
        --cert-ota "$KEYS_DIR/ota.crt" \
        --pass-avb-env-var PASSPHRASE_AVB \
        --pass-ota-env-var PASSPHRASE_OTA
fi

if [ $? -ne 0 ]; then
    log "ERROR" "Failed to patch OTA"
    exit 1
fi

# Generate signature
log "INFO" "Generating signature..."
PASSPHRASE_OTA="$PASSPHRASE_OTA" "$CUSTOTA_TOOL" gen-csig \
    --input "$PATCHED_OTA" \
    --output "$PATCHED_OTA.csig" \
    --key "$KEYS_DIR/ota.key" \
    --cert "$KEYS_DIR/ota.crt" \
    --passphrase-env-var PASSPHRASE_OTA

if [ $? -ne 0 ]; then
    log "ERROR" "Failed to generate signature"
    exit 1
fi

# Generate update info JSON file
log "INFO" "Generating update info JSON file..."
"$CUSTOTA_TOOL" gen-update-info \
    --file "$WEB_DIR/$DEVICE.json" \
    --location "$(basename "$PATCHED_OTA")"

if [ $? -ne 0 ]; then
    log "ERROR" "Failed to generate update info JSON file"
    exit 1
fi

# Set proper ownership and permissions for JSON file
chown "$WEB_USER:$WEB_GROUP" "$WEB_DIR/$(basename "$PATCHED_OTA")"
chown "$WEB_USER:$WEB_GROUP" "$WEB_DIR/$(basename "$PATCHED_OTA.csig")"
chown "$WEB_USER:$WEB_GROUP" "$WEB_DIR/$DEVICE.json"
chmod 664 "$WEB_DIR/$(basename "$PATCHED_OTA")"
chmod 664 "$WEB_DIR/$(basename "$PATCHED_OTA.csig")"
chmod 664 "$WEB_DIR/$DEVICE.json"

# Function to clean up old builds from web directory
cleanup_web_builds() {
    local web_dir="$1"
    local device="$2"
    local current_build="$3"
    
    log "INFO" "Cleaning up old builds from web directory..."
    
    # Get list of builds for the device
    local builds=($(ls -t "$web_dir"/"$device"-ota-*.zip.patched 2>/dev/null))
    
    if [ ${#builds[@]} -le 2 ]; then
        log "INFO" "No old builds to clean up"
        return
    fi
    
    # Keep the two most recent builds
    for ((i=2; i<${#builds[@]}; i++)); do
        local build="${builds[$i]}"
        local build_base="${build%.zip.patched}"
        
        # Remove the patched OTA file
        rm -f "$build"
        
        # Remove the signature file if it exists
        rm -f "$build_base.zip.patched.csig"
        
        log "INFO" "Removed old build: $build"
    done
}

# Cleanup old files
log "INFO" "Cleaning up old files..."
find "$OTA_DIR" -type f -name "*.zip" -mtime +$RETENTION_DAYS -delete
find "$OTA_DIR" -type f -name "*.csig" -mtime +$RETENTION_DAYS -delete

# Clean up old builds from web directory
cleanup_web_builds "$WEB_DIR" "$DEVICE" "$(basename "$PATCHED_OTA")"

log "INFO" "OTA update process completed successfully"

