#!/bin/bash
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)
INSTALL_DIR="@INSTALL_DIR@"
trap 'echo "Uninstall interrupted."; exit 1' SIGINT SIGTERM


remove_file_with_message() {
    local file="$1"
    if [ -f "$file" ]; then
        sudo rm "$file" && echo "Removed: $file"
    elif [ -L "$file" ]; then
        sudo rm "$file" && echo "Removed symlink: $file"
    else
        echo "Not found: $file"
    fi
}

echo "${GREEN}0: Quit$RESET"
echo "${YELLOW}1: Remove powercontrol.conf and no_turbo.conf from /etc/init$RESET"
echo "${RED}2: Full Uninstall (remove all files, symlinks, startup files, and user config for PowerControl$RESET"

read -rp "Enter (0-2): " choice

case "$choice" in
    0)
        echo "Uninstall canceled."
        ;;
    1)
        echo "Removing init files..."
        remove_file_with_message /etc/init/no_turbo.conf
        remove_file_with_message /etc/init/powercontrol.conf
        ;;
    2)
        echo "Stopping background services..."
        sudo bash "$INSTALL_DIR/powercontrol" stop 2>/dev/null
        sudo bash "$INSTALL_DIR/powercontrol" max_perf_pct 100 2>/dev/null
        sudo bash "$INSTALL_DIR/powercontrol" no_turbo 0 2>/dev/null
        remove_file_with_message "$INSTALL_DIR/no_turbo.service"
        remove_file_with_message "$INSTALL_DIR/powercontrol.service"
        remove_file_with_message /etc/init/no_turbo.conf
        remove_file_with_message /etc/init/powercontrol.conf
        sudo rm -f /usr/local/bin/Install_Powercontrol.sh 2>/dev/null
        remove_file_with_message /usr/local/bin/powercontrol
        remove_file_with_message /var/log/powercontrol.log
        remove_file_with_message "$INSTALL_DIR/version"
        sudo rm -f "$INSTALL_DIR/.powercontrol_enabled" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/Reinstall_PowerControl.sh" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/config.sh.bak" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/.install_path" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/.powercontrol_pid" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/.powercontrol_monitor.pid" 2>/dev/null
        sudo rm -f "$INSTALL_DIR/config" 2>/dev/null
        sudo rm -f "$CHARD_ROOT/bin/powercontrol-gui" 2>/dev/null
        sudo rm -f "/usr/local/bin/.PowerControl.install_dir" 2>/dev/null
        sudo rm -f "/usr/local/bin/PowerControl_Config" 2>/dev/null
        sudo rm -f "/usr/local/bin/powercontrol_conf.sh" 2>/dev/null
        rm -rf /home/chronos/user/MyFiles/Downloads/PowerControl_Config 2>/dev/null
        remove_file_with_message "$INSTALL_DIR/powercontrol"
        remove_file_with_message "$INSTALL_DIR/Uninstall_PowerControl.sh"

        if [ -d "$INSTALL_DIR" ] && [ -z "$(ls -A "$INSTALL_DIR")" ]; then
            sudo rm -rf "$INSTALL_DIR" && echo "Removed: $INSTALL_DIR"
        else
            echo "Installation directory not found or still contains files: $INSTALL_DIR"
        fi
        echo "Stopping PowerControl..."
        echo ""
        sleep 1
echo "${RED}╔═══════════════════════════════╗${RESET}"
echo "${YELLOW}║ ╔═══════════════════════════╗ ║${RESET}"
echo "${GREEN}║ ║ ╔═══════════════════════╗ ║ ║${RESET}"
echo "${RESET}║ ║ ║  Uninstall Complete!  ║ ║ ║${RESET}"
echo "${CYAN}║ ║ ╚═══════════════════════╝ ║ ║${RESET}"
echo "${BLUE}║ ╚═══════════════════════════╝ ║${RESET}"
echo "${MAGENTA}╚═══════════════════════════════╝${RESET}"
echo ""
        sudo pkill -f "/usr/local/bin/powercontrol" >/dev/null 2>&1

trap '' SIGTERM

exit 0
        ;;
    *)
        echo "${RED}Invalid option.$RESET"
        exit 1
        ;;
esac
