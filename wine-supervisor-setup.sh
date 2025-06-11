#!/bin/bash

SCRIPT_VERSION="1.0.1"
SCRIPT_NAME="wine-supervisor-setup.sh"
SCRIPT_URL="https://raw.githubusercontent.com/swarup-developer/bgt-script/refs/heads/main/wine-supervisor-setup.sh?token=GHSAT0AAAAAADCENM3Z5IDXNTW4TZP5B7JM2CEMYSQ"

check_for_update() {
    echo "🔄 Checking for script updates..."
    remote_version=$(curl -s "$SCRIPT_URL" | grep "^SCRIPT_VERSION=" | cut -d '"' -f2)

    if [[ -z "$remote_version" ]]; then
        echo "❌ Could not retrieve remote version. Skipping update check."
        return
    fi

    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo "📢 Update available: $remote_version (Current: $SCRIPT_VERSION)"
        read -p "Do you want to update the script now? (yes/no): " update_choice
        if [[ "${update_choice,,}" == "yes" || "${update_choice,,}" == "y" ]]; then
            echo "Downloading latest version..."
            curl -o "$SCRIPT_NAME" "$SCRIPT_URL"
            chmod +x "$SCRIPT_NAME"
            echo "✅ Updated successfully to version $remote_version!"
            echo "💡 Please re-run the script: ./$(basename "$SCRIPT_NAME")"
            exit 0
        else
            echo "Skipping update."
        fi
    else
        echo "✅ You are using the latest version: $SCRIPT_VERSION"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

setup_wine() {
    echo "📦 Updating system and installing Wine dependencies..."
    sudo dpkg --add-architecture i386
    sudo apt update

    if ! command_exists wine; then
        echo "Installing Wine..."
        sudo apt install -y wine wine64 wine32:i386 winetricks
    else
        echo "✅ Wine is already installed."
    fi

    echo "🎯 Setting up fresh Wine prefix..."
    WINEPREFIX=~/.wine32
    WINEARCH=win32
    rm -rf "$WINEPREFIX"
    WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" winecfg

    echo "📚 Installing core libraries..."
    WINEPREFIX="$WINEPREFIX" winetricks corefonts vcrun2013 vcrun6 dotnet35sp1

    echo "✅ Wine setup complete. Version: $(wine --version)"
}

install_supervisor() {
    echo "🔍 Checking if Supervisor is installed..."
    if ! command_exists supervisorctl; then
        echo "Installing Supervisor..."
        sudo apt update
        sudo apt install supervisor -y
    else
        echo "✅ Supervisor is already installed."
    fi
}

setup_app() {
    echo "🛠️ Starting Supervisor app setup..."

    read -p "Give your app a name (used in Supervisor): " appname
    read -p "Enter the name of the .exe file (example: game.exe): " exefile
    read -p "Enter full path to folder containing your EXE file: " folder

    if [[ ! -f "$folder/$exefile" ]]; then
        echo "❌ ERROR: File '$folder/$exefile' not found!"
        return 1
    fi

    read -p "Enter your Linux username (e.g. ubuntu): " username
    read -p "Do you want it to autostart on boot? (yes/no): " auto
    read -p "Do you want to save logs? (yes/no): " log

    autostart_value=false
    [[ "${auto,,}" == "yes" || "${auto,,}" == "y" ]] && autostart_value=true

    config_file="/etc/supervisor/conf.d/$appname.conf"
    sudo bash -c "cat > $config_file" <<EOL
[program:$appname]
command=/usr/bin/wine $folder/$exefile
directory=$folder
autostart=$autostart_value
autorestart=true
user=$username
EOL

    if [[ "${log,,}" == "yes" || "${log,,}" == "y" ]]; then
        sudo bash -c "echo stdout_logfile=/var/log/${appname}_out.log >> $config_file"
        sudo bash -c "echo stderr_logfile=/var/log/${appname}_err.log >> $config_file"
    fi

    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start "$appname"

    sleep 2
    status=$(sudo supervisorctl status "$appname")
    echo "📊 Status: $status"

    if [[ "$status" == *"RUNNING"* ]]; then
        echo "✅ $appname setup successfully!"
        return 0
    else
        echo "❌ $appname failed to start. Cleaning up..."
        sudo rm -f "$config_file"
        return 1
    fi
}

supervisor_menu() {
    while true; do
        echo -e "\n🔧 Supervisor Control Panel:"
        echo "[0] Remove Previously Installed App"
        echo "[1] Start App"
        echo "[2] Stop App"
        echo "[3] Restart App"
        echo "[4] Status"
        echo "[5] Backup App Config"
        echo "[6] Setup New App"
        echo "[7] Exit"
        read -p "Choose an option: " option
        case $option in
            0)
                read -p "Enter the app name to remove: " oldapp
                sudo supervisorctl stop "$oldapp" 2>/dev/null
                sudo rm -f /etc/supervisor/conf.d/"$oldapp".conf 2>/dev/null
                echo "❌ Removed old config: $oldapp"
                ;;
            1)
                read -p "App name: " name
                sudo supervisorctl start "$name"
                ;;
            2)
                read -p "App name: " name
                sudo supervisorctl stop "$name"
                ;;
            3)
                read -p "App name: " name
                sudo supervisorctl restart "$name"
                ;;
            4)
                sudo supervisorctl status
                ;;
            5)
                read -p "Enter the app name to backup: " backupapp
                backup_dir=~/supervisor_backup
                mkdir -p "$backup_dir"
                if [[ -f /etc/supervisor/conf.d/"$backupapp".conf ]]; then
                    cp /etc/supervisor/conf.d/"$backupapp".conf "$backup_dir"
                    echo "📦 Backup created at $backup_dir/$backupapp.conf"
                else
                    echo "❌ Config file for '$backupapp' not found."
                fi
                ;;
            6)
                setup_app
                ;;
            7)
                echo "👋 Exiting."
                break
                ;;
            *)
                echo "❌ Invalid option."
                ;;
        esac
    done
}

# Execute script logic
check_for_update
setup_wine
install_supervisor
supervisor_menu
