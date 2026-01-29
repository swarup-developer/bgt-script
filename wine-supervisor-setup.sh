#!/bin/bash

SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="wine-supervisor-setup.sh"
SCRIPT_URL="https://raw.githubusercontent.com/swarup-developer/bgt-script/refs/heads/main/wine-supervisor-setup.sh"

CONFIG_DIR="$HOME/.wine-supervisor"
STATE_FILE="$CONFIG_DIR/state.conf"
ENV_FILE="$CONFIG_DIR/wine.env"
BACKUP_DIR="$HOME/supervisor_backup"

DRY_RUN=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

init_config() {
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<EOL
INSTALLED_APPS=()
WINE_PREFIX="$HOME/.wine32"
WINE_ARCH="win32"
EOL
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        cat > "$ENV_FILE" <<EOL
export WINEPREFIX="$HOME/.wine32"
export WINEARCH="win32"
EOL
    fi
    
    source "$ENV_FILE"
}

cleanup() {
    rm -f /tmp/wine-setup-*
    echo -e "${YELLOW}Cleanup completed${NC}"
}

trap cleanup EXIT ERR

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

validate_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        return 0
    else
        log_error "Path does not exist: $path"
        return 1
    fi
}

validate_exe() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log_success "Executable found: $file"
        return 0
    else
        log_error "Executable not found: $file"
        return 1
    fi
}

validate_username() {
    local username="$1"
    if id "$username" &>/dev/null; then
        log_success "User exists: $username"
        return 0
    else
        log_error "User does not exist: $username"
        return 1
    fi
}

validate_yes_no() {
    local input="$1"
    local normalized
    normalized="${input,,}"
    if [[ "$normalized" == "yes" || "$normalized" == "y" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_for_update() {
    log_info "Checking for script updates..."
    local remote_version
    remote_version=$(curl -s "$SCRIPT_URL" | grep "^SCRIPT_VERSION=" | cut -d '"' -f2)

    if [[ -z "$remote_version" ]]; then
        log_warning "Could not check for updates"
        return
    fi

    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        log_warning "Update available: $remote_version (Current: $SCRIPT_VERSION)"
        echo -e "${CYAN}Do you want to update the script now? (yes/no):${NC} "
        read -r update_choice
        if [[ "$(validate_yes_no "$update_choice")" == "true" ]]; then
            log_info "Downloading latest version..."
            curl -o "$SCRIPT_NAME.new" "$SCRIPT_URL"
            chmod +x "$SCRIPT_NAME.new"
            mv "$SCRIPT_NAME.new" "$SCRIPT_NAME"
            log_success "Updated successfully to version $remote_version!"
            echo "Please re-run the script: ./$SCRIPT_NAME"
            exit 0
        else
            log_info "Skipping update."
        fi
    else
        log_success "You are using the latest version: $SCRIPT_VERSION"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

setup_wine() {
    if command_exists wine; then
        log_success "Wine is already installed. Skipping Wine setup."
        return
    fi

    log_info "Updating system and installing Wine dependencies..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install Wine and dependencies"
        return
    fi
    
    sudo dpkg --add-architecture i386
    sudo apt update
    sudo apt install -y wine wine64 wine32:i386 winetricks

    log_info "Setting up fresh Wine prefix..."
    source "$ENV_FILE"
    
    rm -rf "$WINEPREFIX"
    WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" winecfg

    log_info "Installing core libraries..."
    WINEPREFIX="$WINEPREFIX" winetricks corefonts vcrun2013 vcrun6 dotnet35sp1

    log_success "Wine setup complete. Version: $(wine --version)"
}

install_supervisor() {
    log_info "Checking if Supervisor is installed..."
    if ! command_exists supervisorctl; then
        log_info "Installing Supervisor..."
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would install Supervisor"
            return
        fi
        sudo apt update
        sudo apt install supervisor -y
        sudo systemctl enable supervisor
        sudo systemctl start supervisor
    else
        log_success "Supervisor is already installed."
        
        if sudo systemctl is-active --quiet supervisor; then
            log_success "Supervisor daemon is running"
        else
            log_warning "Supervisor daemon is not running. Starting it..."
            sudo systemctl start supervisor
        fi
    fi
}

add_to_state() {
    local appname="$1"
    if ! grep -q "^INSTALLED_APPS=.*$appname" "$STATE_FILE"; then
        sed -i "s/INSTALLED_APPS=(/INSTALLED_APPS=($appname /" "$STATE_FILE"
    fi
}

remove_from_state() {
    local appname="$1"
    sed -i "s/$appname //g" "$STATE_FILE"
}

backup_config() {
    local appname="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/${appname}_${timestamp}.conf"
    
    if [[ -f "/etc/supervisor/conf.d/$appname.conf" ]]; then
        cp "/etc/supervisor/conf.d/$appname.conf" "$backup_file"
        log_success "Backup created: $backup_file"
        echo "$backup_file"
    fi
}

rollback_config() {
    local appname="$1"
    local backup_file="$2"
    
    if [[ -f "$backup_file" ]]; then
        sudo cp "$backup_file" "/etc/supervisor/conf.d/$appname.conf"
        sudo supervisorctl reread
        sudo supervisorctl update
        log_success "Rolled back to: $backup_file"
    else
        log_error "Backup file not found: $backup_file"
    fi
}

setup_app() {
    local appname exefile folder username auto log autostart_value
    local config_file backup_file
    
    log_info "Starting Supervisor app setup..."

    echo -e "${CYAN}Give your app a name (used in Supervisor):${NC} "
    read -r appname
    
    echo -e "${CYAN}Enter the name of the .exe file (example: game.exe):${NC} "
    read -r exefile
    
    echo -e "${CYAN}Enter full path to folder containing your EXE file:${NC} "
    read -r folder

    validate_path "$folder" || return 1
    validate_exe "$folder/$exefile" || return 1

    echo -e "${CYAN}Enter your Linux username (e.g. ubuntu):${NC} "
    read -r username
    validate_username "$username" || return 1

    echo -e "${CYAN}Do you want it to autostart on boot? (yes/no):${NC} "
    read -r auto
    autostart_value=$(validate_yes_no "$auto")

    echo -e "${CYAN}Do you want to save logs? (yes/no):${NC} "
    read -r log

    if [[ -f "/etc/supervisor/conf.d/$appname.conf" ]]; then
        backup_file=$(backup_config "$appname")
    fi

    config_file="/etc/supervisor/conf.d/$appname.conf"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would create config: $config_file"
        log_info "[DRY-RUN] Command: /usr/bin/wine $folder/$exefile"
        return 0
    fi
    
    source "$ENV_FILE"
    
    sudo bash -c "cat > $config_file" <<EOL
[program:$appname]
command=/usr/bin/wine $folder/$exefile
directory=$folder
autostart=$autostart_value
autorestart=true
user=$username
environment=WINEPREFIX="$WINEPREFIX",WINEARCH="$WINEARCH"
EOL

    if [[ "$(validate_yes_no "$log")" == "true" ]]; then
        sudo bash -c "echo stdout_logfile=/var/log/${appname}_out.log >> $config_file"
        sudo bash -c "echo stderr_logfile=/var/log/${appname}_err.log >> $config_file"
        sudo bash -c "echo stdout_logfile_maxbytes=10MB >> $config_file"
        sudo bash -c "echo stderr_logfile_maxbytes=10MB >> $config_file"
    fi

    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start "$appname"

    sleep 2
    local status
    status=$(sudo supervisorctl status "$appname")
    log_info "Status: $status"

    if [[ "$status" == *"RUNNING"* ]]; then
        log_success "$appname setup successfully!"
        add_to_state "$appname"
        return 0
    else
        log_error "$appname failed to start."
        if [[ -n "$backup_file" ]]; then
            echo -e "${CYAN}Do you want to rollback to previous config? (yes/no):${NC} "
            read -r rollback_choice
            if [[ "$(validate_yes_no "$rollback_choice")" == "true" ]]; then
                rollback_config "$appname" "$backup_file"
            fi
        else
            log_warning "Cleaning up failed configuration..."
            sudo rm -f "$config_file"
        fi
        return 1
    fi
}

list_wine_apps() {
    log_info "Wine applications managed by Supervisor:"
    echo ""
    
    local apps
    apps=$(sudo supervisorctl status | grep -E "wine|\.exe" || true)
    
    if [[ -z "$apps" ]]; then
        log_warning "No Wine applications found"
    else
        echo "$apps" | while read -r line; do
            if [[ "$line" == *"RUNNING"* ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" == *"STOPPED"* ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo -e "${YELLOW}$line${NC}"
            fi
        done
    fi
    echo ""
}

health_check() {
    log_info "Running health check on Wine processes..."
    
    local wine_procs
    wine_procs=$(ps aux | grep -E "wine.*\.exe" | grep -v grep || true)
    
    if [[ -z "$wine_procs" ]]; then
        log_warning "No Wine processes currently running"
        return
    fi
    
    echo ""
    echo -e "${CYAN}Active Wine Processes:${NC}"
    echo "$wine_procs" | while read -r line; do
        local mem cpu
        mem=$(echo "$line" | awk '{print $4}')
        cpu=$(echo "$line" | awk '{print $3}')
        local proc_info
        proc_info=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "}')
        
        if (( $(echo "$mem > 10.0" | bc -l) )); then
            echo -e "${YELLOW}[HIGH MEM: $mem%]${NC} $proc_info"
        else
            echo -e "${GREEN}[MEM: $mem%]${NC} $proc_info"
        fi
    done
    echo ""
}

list_backups() {
    log_info "Available configuration backups:"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_warning "No backups found"
        return
    fi
    
    ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{print $9, "(" $5 ", " $6 " " $7 ")"}'
    echo ""
}

restore_backup() {
    local backup_file appname
    
    list_backups
    
    echo -e "${CYAN}Enter the backup filename to restore:${NC} "
    read -r backup_file
    
    if [[ ! -f "$BACKUP_DIR/$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    appname=$(echo "$backup_file" | cut -d'_' -f1)
    
    rollback_config "$appname" "$BACKUP_DIR/$backup_file"
    
    echo -e "${CYAN}Do you want to restart the app? (yes/no):${NC} "
    read -r restart_choice
    if [[ "$(validate_yes_no "$restart_choice")" == "true" ]]; then
        sudo supervisorctl restart "$appname"
        log_success "App restarted: $appname"
    fi
}

show_help() {
    cat <<EOF
${GREEN}Wine-Supervisor Setup Script v${SCRIPT_VERSION}${NC}

${CYAN}Usage:${NC}
    $0 [OPTIONS]

${CYAN}Options:${NC}
    --dry-run       Preview changes without applying them
    --help          Show this help message

${CYAN}Description:${NC}
    This script helps you manage Windows applications on Linux using Wine and Supervisor.
    It provides a complete solution for installing, configuring, and monitoring Wine apps
    as system services.

${CYAN}Features:${NC}
    • Automated Wine and Supervisor installation
    • Interactive app configuration with validation
    • Backup and rollback capabilities
    • Health monitoring for Wine processes
    • Color-coded status messages
    • Configuration persistence

${CYAN}Configuration Files:${NC}
    State File:  $STATE_FILE
    Env File:    $ENV_FILE
    Backups:     $BACKUP_DIR

${CYAN}Examples:${NC}
    ./$SCRIPT_NAME
    ./$SCRIPT_NAME --dry-run

${CYAN}Author:${NC} Swarup Developer
${CYAN}Repository:${NC} https://github.com/swarup-developer/bgt-script

EOF
}

supervisor_menu() {
    while true; do
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════${NC}"
        echo -e "${GREEN}    Wine-Supervisor Control Panel${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}[0]${NC}  Remove Previously Installed App"
        echo -e "${CYAN}[1]${NC}  Start App"
        echo -e "${CYAN}[2]${NC}  Stop App"
        echo -e "${CYAN}[3]${NC}  Restart App"
        echo -e "${CYAN}[4]${NC}  Status (All Apps)"
        echo -e "${CYAN}[5]${NC}  List Wine Apps"
        echo -e "${CYAN}[6]${NC}  Backup App Config"
        echo -e "${CYAN}[7]${NC}  List Backups"
        echo -e "${CYAN}[8]${NC}  Restore from Backup"
        echo -e "${CYAN}[9]${NC}  Setup New App"
        echo -e "${CYAN}[10]${NC} Health Check"
        echo -e "${CYAN}[11]${NC} View Logs"
        echo -e "${CYAN}[12]${NC} Exit"
        echo -e "${GREEN}═══════════════════════════════════════════${NC}"
        echo -e -n "${CYAN}Choose an option:${NC} "
        read -r option
        
        case $option in
            0)
                echo -e "${CYAN}Enter the app name to remove:${NC} "
                read -r oldapp
                sudo supervisorctl stop "$oldapp" 2>/dev/null
                sudo rm -f "/etc/supervisor/conf.d/$oldapp.conf" 2>/dev/null
                sudo supervisorctl reread
                sudo supervisorctl update
                remove_from_state "$oldapp"
                log_success "Removed app: $oldapp"
                ;;
            1)
                echo -e "${CYAN}App name:${NC} "
                read -r name
                sudo supervisorctl start "$name"
                ;;
            2)
                echo -e "${CYAN}App name:${NC} "
                read -r name
                sudo supervisorctl stop "$name"
                ;;
            3)
                echo -e "${CYAN}App name:${NC} "
                read -r name
                sudo supervisorctl restart "$name"
                ;;
            4)
                sudo supervisorctl status
                ;;
            5)
                list_wine_apps
                ;;
            6)
                echo -e "${CYAN}Enter the app name to backup:${NC} "
                read -r backupapp
                backup_config "$backupapp"
                ;;
            7)
                list_backups
                ;;
            8)
                restore_backup
                ;;
            9)
                setup_app
                ;;
            10)
                health_check
                ;;
            11)
                echo -e "${CYAN}Enter app name to view logs:${NC} "
                read -r logapp
                echo -e "${CYAN}View [1] Output logs or [2] Error logs?${NC} "
                read -r logchoice
                if [[ "$logchoice" == "1" ]]; then
                    sudo tail -n 50 "/var/log/${logapp}_out.log" 2>/dev/null || log_error "Log file not found"
                else
                    sudo tail -n 50 "/var/log/${logapp}_err.log" 2>/dev/null || log_error "Log file not found"
                fi
                ;;
            12)
                log_success "Exiting Wine-Supervisor Setup. Goodbye!"
                break
                ;;
            *)
                log_error "Invalid option. Please try again."
                ;;
        esac
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_warning "DRY-RUN MODE ENABLED - No changes will be made"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    init_config
    check_for_update
    setup_wine
    install_supervisor
    supervisor_menu
}

main "$@"
