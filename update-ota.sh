#!/bin/bash

# Function to check directory access
check_directory_access() {
    local dir="$1"
    local check_write="$2"
    
    if [ ! -d "$dir" ]; then
        log "ERROR" "Directory '$dir' does not exist"
        exit 1
    fi
    
    if [ ! -r "$dir" ]; then
        log "ERROR" "No read access to directory '$dir'"
        exit 1
    fi
    
    if [ "$check_write" = true ] && [ ! -w "$dir" ]; then
        log "ERROR" "No write access to directory '$dir'"
        exit 1
    fi
}

# Function to ensure directory exists with correct permissions
ensure_directory() {
    local dir="$1"
    local perms="$2"
    local owner="$3"
    local group="$4"
    
    if [ ! -d "$dir" ]; then
        log "INFO" "Creating directory: $dir"
        if ! sudo mkdir -p "$dir"; then
            log "ERROR" "Failed to create directory: $dir"
            exit 1
        fi
    fi
    
    log "INFO" "Setting permissions for: $dir"
    if ! sudo chmod "$perms" "$dir"; then
        log "ERROR" "Failed to set permissions for: $dir"
        exit 1
    fi
    
    if ! sudo chown "$owner:$group" "$dir"; then
        log "ERROR" "Failed to set ownership for: $dir"
        exit 1
    fi
}

# Function to log messages with different levels
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format message based on level and always show on console
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
    
    # Only try to write to log file if we have write access
    if [ -w "$LOG_FILE" ] || [ -w "$(dirname "$LOG_FILE")" ]; then
        echo "$timestamp - [$level] $message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Function to check and fix permissions
check_and_fix_permissions() {
    local path="$1"
    local perms="$2"
    local owner="$3"
    local group="$4"
    local type="$5"
    
    if [ ! -e "$path" ]; then
        log "ERROR" "$type '$path' does not exist"
        log "INFO" "Run: sudo touch $path"
        log "INFO" "Run: sudo chown $owner:$group $path"
        log "INFO" "Run: sudo chmod $perms $path"
        return 1
    fi
    
    local current_perms=$(stat -c %a "$path")
    local current_owner=$(stat -c %U "$path")
    local current_group=$(stat -c %G "$path")
    
    if [ "$current_perms" != "$perms" ] || [ "$current_owner" != "$owner" ] || [ "$current_group" != "$group" ]; then
        log "ERROR" "Incorrect permissions/ownership for $type '$path'"
        log "INFO" "Current: $current_owner:$current_group ($current_perms)"
        log "INFO" "Required: $owner:$group ($perms)"
        log "INFO" "Run: sudo chown $owner:$group $path"
        log "INFO" "Run: sudo chmod $perms $path"
        return 1
    fi
    
    return 0
}

# Set installation paths
INSTALL_DIR="/opt/android-ota"
WEB_DIR="/var/www/ota"
WEB_USER="www-data"
WEB_GROUP="www-data"

# Check if we need to set up directories
if [ ! -d "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR/ota" ] || [ ! -d "$INSTALL_DIR/keys" ] || [ ! -w "$INSTALL_DIR" ]; then
    echo -e "\033[0;32m[INFO]\033[0m Initial setup required. Requesting root access..."
    
    # Try sudo first, fall back to doas if sudo not available
    if command -v sudo >/dev/null 2>&1; then
        ELEVATE="sudo"
    elif command -v doas >/dev/null 2>&1; then
        ELEVATE="doas"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Neither sudo nor doas is available. Cannot perform initial setup."
        exit 1
    fi
    
    # Create and set up directories with proper permissions
    $ELEVATE mkdir -p "$INSTALL_DIR"
    $ELEVATE mkdir -p "$INSTALL_DIR/keys"
    $ELEVATE mkdir -p "$INSTALL_DIR/ota"
    $ELEVATE mkdir -p "$INSTALL_DIR/updates"
    $ELEVATE mkdir -p "$WEB_DIR"
    
    # Set proper ownership and permissions
    $ELEVATE chown root:$WEB_GROUP "$INSTALL_DIR"
    $ELEVATE chmod 775 "$INSTALL_DIR"
    
    $ELEVATE chown root:$WEB_GROUP "$INSTALL_DIR/keys"
    $ELEVATE chmod 750 "$INSTALL_DIR/keys"  # Group can read but not write
    
    $ELEVATE chown root:$WEB_GROUP "$INSTALL_DIR/ota"
    $ELEVATE chmod 775 "$INSTALL_DIR/ota"
    
    $ELEVATE chown root:$WEB_GROUP "$INSTALL_DIR/updates"
    $ELEVATE chmod 775 "$INSTALL_DIR/updates"
    
    $ELEVATE chown $WEB_USER:$WEB_GROUP "$WEB_DIR"
    $ELEVATE chmod 775 "$WEB_DIR"
    
    # Create and set up log file
    $ELEVATE touch "$LOG_FILE"
    $ELEVATE chown root:$WEB_GROUP "$LOG_FILE"
    $ELEVATE chmod 664 "$LOG_FILE"
    
    # Create credentials file with proper permissions
    $ELEVATE touch "$INSTALL_DIR/credentials"
    $ELEVATE chown root:$WEB_GROUP "$INSTALL_DIR/credentials"
    $ELEVATE chmod 640 "$INSTALL_DIR/credentials"  # Group can read but not write
    
    # Create lock file directory with proper permissions
    $ELEVATE touch "$LOCK_FILE"
    $ELEVATE chown root:$WEB_GROUP "$LOCK_FILE"
    $ELEVATE chmod 664 "$LOCK_FILE"
    $ELEVATE rm -f "$LOCK_FILE"  # Remove the empty file, just created to set permissions
    
    # Check if user is in web group, add if not
    if ! groups | grep -q "\b${WEB_GROUP}\b"; then
        echo -e "\033[0;32m[INFO]\033[0m Adding user to ${WEB_GROUP} group..."
        if ! $ELEVATE usermod -a -G "$WEB_GROUP" "$USER"; then
            echo -e "\033[0;31m[ERROR]\033[0m Failed to add user to ${WEB_GROUP} group"
            echo -e "\033[0;32m[INFO]\033[0m Please run: sudo usermod -a -G ${WEB_GROUP} \$USER"
            exit 1
        fi
        echo -e "\033[0;33m[WARN]\033[0m You must log out and back in for group changes to take effect"
        echo -e "\033[0;32m[INFO]\033[0m Please restart this script after logging back in"
        exit 0
    fi
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

# Tool paths
AVBROOT="$INSTALL_DIR/avbroot"
CUSTOTA_TOOL="$INSTALL_DIR/custota-tool"

# Create log file if it doesn't exist and set permissions
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chown "root:$WEB_GROUP" "$LOG_FILE"
    sudo chmod 664 "$LOG_FILE"
fi

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
        log "INFO" "Removing lock file..."
        rm -f "$LOCK_FILE"
    fi
    
    # Clear sensitive variables from memory
    unset PASSPHRASE_AVB
    unset PASSPHRASE_OTA
    
    # Log exit reason
    if [ -n "$signal" ]; then
        case "$signal" in
            "SIGINT")
                log "INFO" "Script interrupted by user (CTRL-C)"
                ;;
            "SIGTERM")
                log "INFO" "Script terminated"
                ;;
            "SIGTSTP")
                log "INFO" "Script suspended by user (CTRL-Z)"
                ;;
            *)
                log "INFO" "Script terminated by signal $signal"
                ;;
        esac
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
    
    # If this was SIGTSTP (CTRL-Z), re-raise the signal after cleanup
    if [ "$signal" = "SIGTSTP" ]; then
        kill -SIGSTOP $$
    else
        exit $exit_code
    fi
}

# Function to handle SIGTSTP (CTRL-Z)
handle_sigtstp() {
    cleanup "SIGTSTP"
}

# Set up trap for cleanup
trap 'cleanup' EXIT
trap 'cleanup SIGINT' SIGINT
trap 'cleanup SIGTERM' SIGTERM
trap 'handle_sigtstp' SIGTSTP

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

# Check if user is in required group
if [ "$EUID" -eq 0 ]; then
    log "WARN" "Running script as root is not recommended for security reasons"
    log "WARN" "Consider running as a non-root user in the ${WEB_GROUP} group instead"
elif ! groups | grep -q "\b${WEB_GROUP}\b"; then
    log "ERROR" "Current user is not in the ${WEB_GROUP} group"
    log "INFO" "Please log out and back in if you were just added to the group"
    log "INFO" "Or run: sudo usermod -a -G ${WEB_GROUP} \$USER"
    exit 1
fi

# Check if lock file directory is writable
if [ ! -w "$(dirname "$LOCK_FILE")" ]; then
    if [ -d "$INSTALL_DIR" ] && [ ! -w "$INSTALL_DIR" ]; then
        log "ERROR" "Base directory '$INSTALL_DIR' is not writable by group ${WEB_GROUP}"
        log "INFO" "Run: sudo chmod 775 $INSTALL_DIR"
        log "INFO" "Run: sudo chown root:${WEB_GROUP} $INSTALL_DIR"
        exit 1
    fi
    log "ERROR" "Cannot write to lock file directory: $(dirname "$LOCK_FILE")"
    exit 1
fi

# Check if log file directory is writable
if [ ! -w "$(dirname "$LOG_FILE")" ]; then
    log "ERROR" "Cannot write to log file directory: $(dirname "$LOG_FILE")"
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
    local repo_name="$1"
    local tool_name="$2"
    local tool_path="$3"
    local latest_build="$4"
    local zip_name="$5"
    
    log "INFO" "Downloading and installing $tool_name..."
    if ! wget "https://github.com/chenxiaolong/$repo_name/releases/download/v$latest_build/$zip_name" -P "$WORKING_DIR"; then
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
    install_tool "avbroot" "avbroot" "$AVBROOT" "$latest_avb_build" "avbroot-$latest_avb_build-x86_64-unknown-linux-gnu.zip"
fi

# Check and install custota-tool if missing
if [ ! -f "$CUSTOTA_TOOL" ]; then
    install_tool "Custota" "custota-tool" "$CUSTOTA_TOOL" "$latest_cust_build" "custota-tool-$latest_cust_build-x86_64-unknown-linux-gnu.zip"
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
    log "INFO" "Please create the credentials file with the following content:"
    log "INFO" "PASSPHRASE_AVB='your_avb_passphrase'"
    log "INFO" "PASSPHRASE_OTA='your_ota_passphrase'"
    log "INFO" "Then set permissions:"
    log "INFO" "Run: sudo touch $CREDENTIALS_FILE"
    log "INFO" "Run: sudo chown root:$WEB_GROUP $CREDENTIALS_FILE"
    log "INFO" "Run: sudo chmod 640 $CREDENTIALS_FILE"
    exit 1
fi

if [ ! -r "$CREDENTIALS_FILE" ]; then
    log "ERROR" "Cannot read credentials file: $CREDENTIALS_FILE"
    log "INFO" "Please ensure the file has correct permissions (640) and ownership"
    log "INFO" "Run: sudo chown root:$WEB_GROUP $CREDENTIALS_FILE"
    log "INFO" "Run: sudo chmod 640 $CREDENTIALS_FILE"
    exit 1
fi

if [ "$(stat -c %a "$CREDENTIALS_FILE")" != "640" ]; then
    log "ERROR" "Credentials file must have permissions 640"
    log "INFO" "Current permissions: $(stat -c %a "$CREDENTIALS_FILE")"
    log "INFO" "Run: sudo chmod 640 $CREDENTIALS_FILE"
    exit 1
fi

if [ "$(stat -c %G "$CREDENTIALS_FILE")" != "$WEB_GROUP" ]; then
    log "ERROR" "Credentials file must be owned by group $WEB_GROUP"
    log "INFO" "Current group: $(stat -c %G "$CREDENTIALS_FILE")"
    log "INFO" "Run: sudo chown root:$WEB_GROUP $CREDENTIALS_FILE"
    exit 1
fi

# Source credentials file
if ! source "$CREDENTIALS_FILE" 2>/dev/null; then
    log "ERROR" "Failed to source credentials file"
    log "INFO" "Please check the file contents and permissions"
    exit 1
fi

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
        # Capture only the last line which should be the JSON output
        OTA_INFO=$(python3 "$SCRIPT_DIR/$PYTHON_SCRIPT" --device "$DEVICE" --output "$OTA_DIR/" --json 2>/dev/null | tail -n 1)
    else
        # Capture only the last line which should be the JSON output
        OTA_INFO=$(python3 "$SCRIPT_DIR/$PYTHON_SCRIPT" --device "$DEVICE" --output "$OTA_DIR/" --json --non-interactive 2>/dev/null | tail -n 1)
    fi

    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to fetch OTA information"
        exit 1
    fi

    # Parse the JSON output to get filename and checksum
    if ! OTA_FILENAME=$(echo "$OTA_INFO" | jq -r '.filename'); then
        log "ERROR" "Failed to parse filename from JSON output"
        exit 1
    fi

    if ! OTA_CHECKSUM=$(echo "$OTA_INFO" | jq -r '.checksum'); then
        log "ERROR" "Failed to parse checksum from JSON output"
        exit 1
    fi

    if [ -z "$OTA_FILENAME" ] || [ "$OTA_FILENAME" = "null" ]; then
        log "ERROR" "No filename found in JSON output"
        exit 1
    fi

    if [ -z "$OTA_CHECKSUM" ] || [ "$OTA_CHECKSUM" = "null" ]; then
        log "ERROR" "No checksum found in JSON output"
        exit 1
    fi

    OTA_FILE="$OTA_DIR/$OTA_FILENAME"
fi

# Get the downloaded OTA filename - explicitly exclude .patched.zip files
OTA_FILE=$(ls -t "$OTA_DIR"/*.zip 2>/dev/null | grep -v '\.patched\.zip$' | head -n1)
if [ -z "$OTA_FILE" ]; then
    log "ERROR" "No OTA file found in $OTA_DIR"
    exit 1
fi

# Get the base filename without .zip
OTA_BASENAME=$(basename "$OTA_FILE" .zip)

# Generate output filename - this will be the final patched filename
PATCHED_OTA="$OTA_DIR/$OTA_BASENAME.patched.zip"

# Check if patched OTA already exists
if [ -f "$PATCHED_OTA" ]; then
    if [ "$FORCE" = true ]; then
        log "INFO" "Previous patched OTA found, removing due to --force: $(basename "$PATCHED_OTA")"
        rm -f "$PATCHED_OTA"
        rm -f "$PATCHED_OTA.csig"
    else
        log "INFO" "Previous patched OTA found: $(basename "$PATCHED_OTA")"
        log "INFO" "Skipping update process. Use --force to override."
        exit 0
    fi
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

# Copy files to web directory
log "INFO" "Copying files to web directory..."
if ! cp "$PATCHED_OTA" "$WEB_DIR/"; then
    log "ERROR" "Failed to copy patched OTA file to web directory"
    exit 1
fi

if ! cp "$PATCHED_OTA.csig" "$WEB_DIR/"; then
    log "ERROR" "Failed to copy signature file to web directory"
    # Clean up the partially copied file
    rm -f "$WEB_DIR/$(basename "$PATCHED_OTA")"
    exit 1
fi

# Generate update info JSON file
log "INFO" "Generating update info JSON file..."
"$CUSTOTA_TOOL" gen-update-info \
    --file "$WEB_DIR/$DEVICE.json" \
    --location "$(basename "$PATCHED_OTA")"

if [ $? -ne 0 ]; then
    log "ERROR" "Failed to generate update info JSON file"
    # Clean up the copied files
    rm -f "$WEB_DIR/$(basename "$PATCHED_OTA")"
    rm -f "$WEB_DIR/$(basename "$PATCHED_OTA").csig"
    exit 1
fi

# Function to clean up old builds from web directory
cleanup_web_builds() {
    local web_dir="$1"
    local device="$2"
    local current_build="$3"
    
    log "INFO" "Cleaning up old builds from web directory..."
    
    # Get list of builds for the device, only looking at .patched.zip files
    local builds=($(ls -t "$web_dir"/"$device"-ota-*.patched.zip 2>/dev/null))
    
    if [ ${#builds[@]} -le 2 ]; then
        log "INFO" "No old builds to clean up"
        return
    fi
    
    # Keep the two most recent builds
    for ((i=2; i<${#builds[@]}; i++)); do
        local build="${builds[$i]}"
        
        # Remove the patched OTA file
        rm -f "$build"
        
        # Remove the signature file if it exists
        rm -f "$build.csig"
        
        log "INFO" "Removed old build: $(basename "$build")"
    done
}

# Cleanup old files
log "INFO" "Cleaning up old files..."
find "$OTA_DIR" -type f -name "*.zip" -mtime +$RETENTION_DAYS -delete
find "$OTA_DIR" -type f -name "*.csig" -mtime +$RETENTION_DAYS -delete

# Clean up old builds from web directory
cleanup_web_builds "$WEB_DIR" "$DEVICE" "$(basename "$PATCHED_OTA")"

log "INFO" "OTA update process completed successfully"

