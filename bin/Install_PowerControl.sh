#!/bin/bash
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)
SHOW_POWERCONTROL_NOTICE=0
TEST_FILE="/etc/init/.boot_test"
detect_cpu_type() {
    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || echo "unknown")
    IS_INTEL=0
    IS_AMD=0
    IS_ARM=0
    PERF_PATH=""
    PERF_PATHS=()
    TURBO_PATH=""

    case "$CPU_VENDOR" in
        GenuineIntel)
            IS_INTEL=1
            if [ -f "/sys/devices/system/cpu/intel_pstate/max_perf_pct" ]; then
                PERF_PATH="/sys/devices/system/cpu/intel_pstate/max_perf_pct"
                TURBO_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"
            fi
            ;;
        AuthenticAMD)
            IS_AMD=1
            if [ -f "/sys/devices/system/cpu/amd_pstate/max_perf_pct" ]; then
                PERF_PATH="/sys/devices/system/cpu/amd_pstate/max_perf_pct"
            else
                mapfile -t PERF_PATHS < <(find /sys/devices/system/cpu/cpufreq/ -type f -name 'scaling_max_freq' 2>/dev/null)
            fi
            ;;
        *)
            IS_ARM=1
            mapfile -t PERF_PATHS < <(find /sys/devices/system/cpu/cpufreq/ -type f -name 'scaling_max_freq' 2>/dev/null)
            ;;
    esac
}



INSTALL_DIR="/usr/local/bin/PowerControl"
DEFAULT_INSTALL_DIR="/usr/local/bin/PowerControl"

if [ -f "$DEFAULT_INSTALL_DIR/.install_path" ]; then
    INSTALL_DIR=$(sudo cat "$DEFAULT_INSTALL_DIR/.install_path")
    echo -e "${CYAN}Found existing Install Path: ${BOLD}$INSTALL_DIR${RESET}"
else
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
fi

while true; do
    read -rp "${GREEN}Enter desired Install Path - ${RESET}${GREEN}${BOLD}leave blank for default: $INSTALL_DIR:$RESET " choice
    if [ -n "$choice" ]; then
        INSTALL_DIR="${choice}"
    fi
    INSTALL_DIR="${INSTALL_DIR%/}"

    echo -e "\n${CYAN}You entered: ${BOLD}$INSTALL_DIR${RESET}"
    read -rp "${YELLOW}${BOLD}Confirm this install path? Enter key counts as yes!${RESET}${BOLD} (Y/n): ${RESET}" confirm
    case "$confirm" in
        [Yy]* | "")
            sudo mkdir -p "$INSTALL_DIR"
            echo ""
            break
            ;;
        [Nn]*)
            echo -e "${BLUE}Cancelled.${RESET}\n"
            ;;
        *)
            echo -e "${RED}Please answer Y/n.${RESET}"
            ;;
    esac
done

echo "${BLUE}Stopping PowerControl (in case of reinstall)${RESET}"
sudo bash "$INSTALL_DIR/powercontrol" stop 2>/dev/null
echo "$INSTALL_DIR" | sudo tee "$INSTALL_DIR/.install_path" >/dev/null

declare -a files=(
  "powercontrol"
  "Uninstall_PowerControl.sh"
  "Reinstall_PowerControl.sh"
  "version" "no_turbo.conf" 
  "powercontrol.conf"
)

for file in "${files[@]}"; do
    dest="$INSTALL_DIR/$file"

    echo "${BLUE}Downloading $file to $dest...${RESET}"
    if sudo curl -fsSL "https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/$file" -o "$dest"; then
        if grep -q "@INSTALL_DIR@" "$dest"; then
            sed -i "s|@INSTALL_DIR@|$INSTALL_DIR|g" "$dest"
        fi
        sudo chmod +x "$dest" 2>/dev/null
    else
        echo "${RED}Failed to download $file. Skipping.${RESET}"
    fi
    sleep 0.1
done

OLD_CONFIG_PATH="$INSTALL_DIR/config.sh"
CONFIG_DIR="/usr/local/bin/ChromeOS_PowerControl_Config"
sudo mkdir -p "$CONFIG_DIR"
sudo chown -R 1000:1000 "$CONFIG_DIR"
sudo curl -fsSL https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/gui.py -o /bin/powercontrol-gui 2>/dev/null
sudo chmod +x /bin/powercontrol-gui 2>/dev/null
alias powercontrol-gui='sudo -E powercontrol-gui' 
sudo mkdir -p /usr/share/applications/ /usr/share/icons/hicolor/48x48/apps/
    cat <<'EOF' | sudo tee /usr/share/applications/powercontrol-gui.desktop > /dev/null
[Desktop Entry]
Version=1.0
Type=Application
Name=PowerControl
Comment=Get the power to control your CPU! 
Exec=sudo -E /bin/powercontrol-gui
Icon=powercontrol
Terminal=true
Categories=Utility;System; 
StartupNotify=true
EOF
    sudo curl -Ls https://github.com/shadowed1/PowerControl/blob/main/icons/powercontrol_200p.png?raw=true -o /usr/share/icons/hicolor/48x48/apps/powercontrol.png 2>/dev/null
fi

NEW_CONFIG_PATH="$CONFIG_DIR/config"
BASHRC="$HOME/.bashrc"

if [[ -f "$OLD_CONFIG_PATH" ]]; then
    cp "$OLD_CONFIG_PATH" "$NEW_CONFIG_PATH"
    sudo rm "$OLD_CONFIG_PATH"
    sudo chmod 666 "$NEW_CONFIG_PATH" 2>/dev/null
elif [[ -f "$NEW_CONFIG_PATH" ]]; then
    echo "${GREEN}Existing config preserved at:${BOLD} $NEW_CONFIG_PATH"
else
    echo "${RESET}${BLUE}No config found — downloading default config${RESET}"
    if curl -fsSL "$CONFIG_URL" -o "$NEW_CONFIG_PATH"; then
        sudo chmod 644 "$NEW_CONFIG_PATH" 2>/dev/null
    else
        echo "${RESET}${RED}Failed to download default config${RESET}"
    fi
fi

CONFIG_FILE="$NEW_CONFIG_PATH"
detect_cpu_type

if [ "$IS_INTEL" -eq 1 ]; then
    SHOW_POWERCONTROL_NOTICE=1
fi
echo ""
echo "${RESET}${BLUE}$BACKLIGHT_NAME"
echo "$BRIGHTNESS_PATH"
echo "$MAX_BRIGHTNESS_PATH${RESET}"
echo ""

echo "${RESET}${CYAN}Detected CPU Vendor: $CPU_VENDOR"
echo "PERF_PATH: $PERF_PATH"
echo "PERF_PATHS: ${PERF_PATHS[*]}"
echo "TURBO_PATH: $TURBO_PATH"
echo "$RESET"
sudo chmod +x "$INSTALL_DIR/powercontrol" "$INSTALL_DIR/Uninstall_PowerControl.sh" "$INSTALL_DIR/config.sh" 2>/dev/null
sudo touch "$INSTALL_DIR/.powercontrol_enabled"

LOG_DIR="/var/log"
sudo touch "$LOG_DIR/powercontrol.log" 2>/dev/null
sudo chmod 644 "$LOG_DIR/powercontrol.log" 2>/dev/null
echo "${YELLOW}${BOLD}Log file for PowerControl is stored in /var/log/$RESET"

USER_HOME="$HOME"
echo ""

declare -a ordered_keys=(
  "MAX_TEMP"
  "MAX_PERF_PCT"
  "MIN_TEMP"
  "MIN_PERF_PCT"
  "HOTZONE"
  "CPU_POLL"
  "RAMP_UP"
  "RAMP_DOWN"
  "PERF_PATH"
  "PERF_PATHS"
  "TURBO_PATH"
  "IS_AMD"
  "IS_INTEL"
  "IS_ARM"
)

declare -a ordered_categories=("PowerControl" "Platform Configuration")
declare -A categories=(
  ["PowerControl"]="MAX_TEMP MIN_TEMP MAX_PERF_PCT MIN_PERF_PCT HOTZONE CPU_POLL RAMP_UP RAMP_DOWN"
  ["Platform Configuration"]="IS_AMD IS_INTEL IS_ARM PERF_PATH PERF_PATHS TURBO_PATH"
)

if [[ -z "${MAX_TEMP}" ]]; then MAX_TEMP=90; fi
if [[ -z "${MIN_TEMP}" ]]; then MIN_TEMP=63; fi
if [[ -z "${MAX_PERF_PCT}" ]]; then MAX_PERF_PCT=100; fi
if [[ -z "${MIN_PERF_PCT}" ]]; then MIN_PERF_PCT=10; fi
if [[ -z "${HOTZONE}" ]]; then HOTZONE=79; fi
if [[ -z "${CPU_POLL}" ]]; then CPU_POLL=1; fi
if [[ -z "${RAMP_UP}" ]]; then RAMP_UP=10; fi
if [[ -z "${RAMP_DOWN}" ]]; then RAMP_DOWN=10; fi

declare -A defaults=(
  [MAX_TEMP]=$MAX_TEMP
  [MIN_TEMP]=$MIN_TEMP
  [MAX_PERF_PCT]=$MAX_PERF_PCT
  [MIN_PERF_PCT]=$MIN_PERF_PCT
  [HOTZONE]=$HOTZONE
  [CPU_POLL]=$CPU_POLL
  [RAMP_UP]=$RAMP_UP
  [RAMP_DOWN]=$RAMP_DOWN
  [PERF_PATH]=$PERF_PATH
  [TURBO_PATH]=$TURBO_PATH
  [IS_AMD]=$IS_AMD
  [IS_INTEL]=$IS_INTEL
  [IS_ARM]=$IS_ARM
)

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE" 2>/dev/null
fi

> "$CONFIG_FILE" 

for category in "${ordered_categories[@]}"; do
  echo "# --- ${category} ---" >> "$CONFIG_FILE"
  for key in ${categories[$category]}; do
    if [ -n "${!key+x}" ]; then
      if declare -p "$key" 2>/dev/null | grep -q 'declare -a'; then
        eval "arr=(\"\${${key}[@]}\")"
        printf '%s=(' "$key" >> "$CONFIG_FILE"
        for elem in "${arr[@]}"; do
          printf '"%s" ' "$elem" >> "$CONFIG_FILE"
        done
        echo ")" >> "$CONFIG_FILE"
      else
        val="${!key}"
        echo "$key=$val" >> "$CONFIG_FILE"
      fi
    else
      val="${defaults[$key]}"
      echo "$key=$val" >> "$CONFIG_FILE"
    fi
  done
  echo >> "$CONFIG_FILE"
done
echo "${GREEN}${BOLD}Installing to: $INSTALL_DIR $RESET"
echo ""
    sudo rm -r /usr/local/bin/powercontrol 2>/dev/null
    sudo ln -sf "$INSTALL_DIR/powercontrol" /usr/local/bin/powercontrol
    echo ""
    
enable_component_on_boot() {
    local COLOR
    local component="$1"
    local config_file="$2"
    local var_name="STARTUP_$(echo "$component" | tr '[:lower:]' '[:upper:]')"
    local target_file="/etc/init/$(basename "$config_file")"

     case "$component" in
        "PowerControl")   COLOR=${CYAN}${BOLD} ;;
        *)                COLOR=${RESET} ;;
    esac
    
    read -rp "${COLOR}Do you want $component enabled on boot?${RESET}${BOLD} (Y/n):${RESET} " move_config
    if [[ -z "$move_config" || "$move_config" =~ ^[Yy]$ ]]; then
        sudo cp "$config_file" "$target_file"
        echo "$var_name=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
        echo ""
    else
        echo "$component must be started manually on boot."
        echo "$var_name=0" | sudo tee -a "$CONFIG_FILE" > /dev/null

        if [ -f "$target_file" ]; then
            sudo rm -f "$target_file"
        fi
        echo ""
    fi
}


if sudo touch "$TEST_FILE" 2>/dev/null; then
    sudo rm -f "$TEST_FILE"

    if [[ -z "$link_cmd" || "$link_cmd" =~ ^[Yy]$ ]]; then
        enable_component_on_boot "PowerControl" "$INSTALL_DIR/powercontrol.conf"
    else
        echo "Skipping boot-time setup."
    fi
else
    echo "${YELLOW}Rootfs verification must be disabled to allow startup on boot. ${RESET}"
fi

if grep -q '^STARTUP_POWERCONTROL=1' "$CONFIG_FILE"; then
    SHOW_POWERCONTROL_NOTICE=1
fi

start_component_now() {
    local component="$1"
    local command="$2"
    local COLOR

    case "$component" in
        "PowerControl")   COLOR=${CYAN}${BOLD} ;;
        *)                COLOR=${RESET} ;;
    esac

   read -rp "${COLOR}Do you want to start $component now?${RESET}${BOLD} (Y/n): ${RESET} " start_now
    if [[ -z "$start_now" || "$start_now" =~ ^[Yy]$ ]]; then
        sudo "$command" start
        echo ""

    else
        echo "You can run it later with: sudo $command start"
        echo ""
    fi
}

echo
start_component_now "PowerControl" "$INSTALL_DIR/powercontrol"
echo "${CYAN}"
sleep 0.01
echo "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
sleep 0.01
echo "║                                                  PowerControl:                                                     ║"
sleep 0.01
echo "╠════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣"
sleep 0.01
echo "║                                                                                                                    ║"
sleep 0.01
echo "║  powercontrol                       # Show status                                                                  ║"
sleep 0.01
echo "║  powercontrol help                  # Help menu                                                                    ║"
sleep 0.01
echo "║  powercontrol monitor               # Toggle on/off live monitoring in terminal                                    ║"
sleep 0.01
echo "║  sudo powercontrol start            # Throttle CPU based on temperature curve                                      ║"
sleep 0.01
echo "║  sudo powercontrol stop             # Restore default CPU settings                                                 ║"
sleep 0.01
echo "║  sudo powercontrol no_turbo 1       # 0 = Enable, 1 = Disable Turbo Boost                                          ║"
sleep 0.01
echo "║  sudo powercontrol max 75           # Set max performance percentage                                               ║"
sleep 0.01
echo "║  sudo powercontrol min 20           # Set minimum performance at max temp                                          ║"
sleep 0.01
echo "║  sudo powercontrol max_temp 86      # Max temperature threshold - Limit is 90°C                                    ║"
sleep 0.01
echo "║  sudo powercontrol min_temp 60      # Min temperature threshold                                                    ║"
sleep 0.01
echo "║  sudo powercontrol hotzone 78       # Temperature threshold for aggressive thermal management                      ║"
sleep 0.01
echo "║  sudo powercontrol cpu_poll 1       # Interval in seconds PowerControl operates at (0.1s to 5s)                    ║"
sleep 0.01
echo "║  sudo powercontrol ramp_up 15       # % in steps CPU will increase in clockspeed per second                        ║"
sleep 0.01
echo "║  sudo powercontrol ramp_down 20     # % in steps CPU will decrease in clockspeed per second                        ║"
sleep 0.01
echo "║  sudo powercontrol startup          # Copy or Remove no_turbo.conf & powercontrol.conf at: /etc/init/              ║"
sleep 0.01
echo "║                                                                                                                    ║"
sleep 0.01
echo "║  sudo powercontrol version      # Check PowerControl version                                                       ║"
sleep 0.01
echo "║  sudo powercontrol reinstall    # Download and reinstall PowerControl                                     ║"
sleep 0.01
echo "║  sudo powercontrol uninstall    # Run uninstaller                                                                  ║"
sleep 0.01
echo "║                                                                                                                    ║"
sleep 0.01
echo "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
sleep 0.01
echo "   sudo bash "$INSTALL_DIR/Uninstall_PowerControl.sh"  # Alternate uninstall method"
sleep 0.01
echo " ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
sleep 0.01
echo "${RESET}"
