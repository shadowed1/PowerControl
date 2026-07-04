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
SHOW_GPUCONTROL_NOTICE=0
TEST_FILE="/etc/systemd/system/.test"

detect_cpu_type() {
    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || echo "unknown")
    IS_INTEL=0
    IS_AMD=0
    IS_ARM=0
    IS_ASAHI=0
    PERF_PATH=""
    PERF_PATHS=()
    TURBO_PATH=""
    TEMP_PATH=""
    
    case "$CPU_VENDOR" in
        GenuineIntel)
            IS_INTEL=1
            if [ -f "/sys/devices/system/cpu/intel_pstate/max_perf_pct" ]; then
                PERF_PATH="/sys/devices/system/cpu/intel_pstate/max_perf_pct"
                TURBO_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"
            fi
            for zone in /sys/class/thermal/thermal_zone*/temp; do
                if [ -r "$zone" ]; then
                    TEMP_PATH="$zone"
                    break
                fi
            done
            ;;
        AuthenticAMD)
            IS_AMD=1
            if [ -f "/sys/devices/system/cpu/amd_pstate/max_perf_pct" ]; then
                PERF_PATH="/sys/devices/system/cpu/amd_pstate/max_perf_pct"
            else
                mapfile -t PERF_PATHS < <(
                    find /sys/devices/system/cpu/cpufreq/ \
                        -type f -name 'scaling_max_freq' 2>/dev/null
                )
            fi
            for hwmon in /sys/class/hwmon/hwmon*; do
                [ -r "$hwmon/name" ] || continue
                read -r name < "$hwmon/name"
                if [ "$name" = "k10temp" ]; then
                    if [ -r "$hwmon/temp2_input" ]; then
                        TEMP_PATH="$hwmon/temp2_input"
                    elif [ -r "$hwmon/temp1_input" ]; then
                        TEMP_PATH="$hwmon/temp1_input"
                    fi
                    break
                fi
            done
            if [ -z "$TEMP_PATH" ]; then
                for zone in /sys/class/thermal/thermal_zone*/temp; do
                    if [ -r "$zone" ]; then
                        TEMP_PATH="$zone"
                        break
                    fi
                done
            fi
            ;;
        *)
            IS_ARM=1

            mapfile -t PERF_PATHS < <(
                find /sys/devices/system/cpu/cpufreq/ \
                    -type f -name 'scaling_max_freq' 2>/dev/null
            )

            local uname_str
            uname_str=$(uname -r)
            if echo "$uname_str" | grep -qi 'asahi'; then
                IS_ASAHI=1
                for hwmon in /sys/class/hwmon/hwmon*; do
                    for label_path in "$hwmon"/power*_label; do
                        [ -r "$label_path" ] || continue
                        read -r label < "$label_path"
                        if [ "$label" = "Heatpipe Power" ]; then
                            ASAHI_HEATPIPE_PATH="${label_path%_label}_input"
                            break 2
                        fi
                    done
                done
            fi

            for zone in /sys/class/thermal/thermal_zone*/temp; do
                if [ -r "$zone" ]; then
                    TEMP_PATH="$zone"
                    break
                fi
            done
            ;;
    esac
}

detect_gpu_freq() {
    GPU_FREQ_PATH=""
    GPU_MAX_FREQ=""
    GPU_TYPE="unknown"

    # Intel Xe
    if ls /sys/class/drm/card*/gt_max_freq_mhz >/dev/null 2>&1; then
    GPU_TYPE="intel"

    # pick the first valid one (or you can prioritize iGPU later)
    for f in /sys/class/drm/card*/gt_max_freq_mhz; do
        if [ -f "$f" ]; then
            GPU_FREQ_PATH="$f"
            GPU_MAX_FREQ=$(sudo cat "$GPU_FREQ_PATH" 2>/dev/null)
            break
        fi
    done

    # AMD
    elif [ -f /sys/class/drm/card*/device/pp_od_clk_voltage ]; then
        GPU_TYPE="amd"
        for f in /sys/class/drm/card*/device/pp_od_clk_voltage; do
            if [ -f "$f" ]; then
                mapfile -t SCLK_LINES < <(sudo grep -i '^sclk' "$f" 2>/dev/null)
                if [[ ${#SCLK_LINES[@]} -gt 0 ]]; then
                GPU_MAX_FREQ=$(printf '%s\n' "${SCLK_LINES[@]}" \
                    | sed -n 's/.*\([0-9]\{1,\}\)[Mm][Hh][Zz].*/\1/p' \
                    | sort -nr | head -n1)
                fi
                GPU_FREQ_PATH="$f"
                GPU_MAX_FREQ=${GPU_MAX_FREQ:-0}
                done

    # AMD GCN
    elif [ -f /sys/class/drm/card0/device/pp_dpm_sclk ]; then
        GPU_TYPE="amd"
        PP_DPM_SCLK="/sys/class/drm/card0/device/pp_dpm_sclk"
        GPU_MAX_FREQ=$(grep -oi '[0-9]\+mhz' "$PP_DPM_SCLK" | grep -oi '[0-9]\+' | sort -nr | head -n1)
        GPU_FREQ_PATH="$PP_DPM_SCLK"
        GPU_MAX_FREQ=${GPU_MAX_FREQ:-0}

    # Mali / Adreno
    else
        for d in /sys/class/devfreq/*; do
            if echo "$d" | grep -qiE 'mali|gpu'; then
                if [ -f "$d/max_freq" ]; then
                    GPU_TYPE="mali"
                    GPU_FREQ_PATH="$d/max_freq"
                    GPU_MAX_FREQ=$(sudo cat "$GPU_FREQ_PATH" 2>/dev/null)
                    break
                elif [ -f "$d/available_frequencies" ]; then
                    GPU_TYPE="mali"
                    GPU_FREQ_PATH="$d/available_frequencies"
                    GPU_MAX_FREQ=$(sudo tr ' ' '\n' < "$GPU_FREQ_PATH" 2>/dev/null | sort -nr | head -n1)
                    break
                fi
            fi
        done

        # Adreno Fallback
        if [ "$GPU_TYPE" = "unknown" ] && [ -d /sys/class/kgsl/kgsl-3d0 ]; then
            if [ -f /sys/class/kgsl/kgsl-3d0/max_gpuclk ]; then
                GPU_TYPE="adreno"
                GPU_FREQ_PATH="/sys/class/kgsl/kgsl-3d0/max_gpuclk"
                GPU_MAX_FREQ=$(sudo cat "$GPU_FREQ_PATH" 2>/dev/null)
            elif [ -f /sys/class/kgsl/kgsl-3d0/gpuclk ]; then
                GPU_TYPE="adreno"
                GPU_FREQ_PATH="/sys/class/kgsl/kgsl-3d0/gpuclk"
                GPU_MAX_FREQ=$(sudo cat "$GPU_FREQ_PATH" 2>/dev/null)
            fi
        fi
    fi
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
sudo bash "$INSTALL_DIR/gpucontrol" stop 2>/dev/null
echo "$INSTALL_DIR" | sudo tee "$INSTALL_DIR/.install_path" >/dev/null

declare -a files=(
  "powercontrol" "gpucontrol"
  "Uninstall_PowerControl.sh"
  "Reinstall_PowerControl.sh"
  "version" "no_turbo.service" 
  "powercontrol.service"
  "gpucontrol.service"
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
CONFIG_DIR="/usr/local/bin/PowerControl_Config"
sudo mkdir -p "$CONFIG_DIR"
sudo chown -R 1000:1000 "$CONFIG_DIR" 2>/dev/null
sudo chown 1000:1000 "$CONFIG_DIR/config" 2>/dev/null
sudo curl -fsSL https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/powercontrol-gui.py -o /bin/powercontrol-gui 2>/dev/null
sudo chmod +x /bin/powercontrol-gui 2>/dev/null
sudo mkdir -p /usr/share/applications/ /usr/share/icons/hicolor/48x48/apps/
    cat <<'EOF' | sudo tee /usr/share/applications/powercontrol-gui.desktop > /dev/null
[Desktop Entry]
Version=1.0
Type=Application
Name=PowerControl
Comment=Get the power to control your CPU and GPU! 
Exec=/bin/powercontrol-gui
Icon=powercontrol
Terminal=false
Categories=Utility;System; 
StartupNotify=true
EOF
    sudo curl -Ls https://github.com/shadowed1/PowerControl/blob/main/bin/icons/AutothrottleDark256.png?raw=true -o /usr/share/icons/hicolor/48x48/apps/powercontrol.png 2>/dev/null

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

echo "${RESET}${CYAN}Detected CPU: $CPU_VENDOR"
echo "PERF_PATH: $PERF_PATH"
echo "PERF_PATHS: ${PERF_PATHS[*]}"
echo "TURBO_PATH: $TURBO_PATH"
echo "$RESET"
sudo chmod +x "$INSTALL_DIR/powercontrol" "$INSTALL_DIR/gpucontrol" "$INSTALL_DIR/Uninstall_PowerControl.sh" "$INSTALL_DIR/config.sh" 2>/dev/null
sudo touch "$INSTALL_DIR/.powercontrol_enabled"
detect_gpu_freq
echo "${MAGENTA}Detected GPU Type: $GPU_TYPE"
echo "GPU_FREQ_PATH: $GPU_FREQ_PATH"
echo "GPU_MAX_FREQ: $GPU_MAX_FREQ"
echo "${RESET}"

LOG_DIR="/var/log"
sudo touch "$LOG_DIR/powercontrol.log" 2>/dev/null
sudo chmod 644 "$LOG_DIR/powercontrol.log" 2>/dev/null
echo "${YELLOW}${BOLD}Log files for PowerControl and GPUControl are stored in /var/log/$RESET"

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
  "GPU_TYPE"
  "GPU_FREQ_PATH"
  "GPU_MAX_FREQ"
  "ORIGINAL_GPU_MAX_FREQ"
  "PP_OD_FILE"
  "AMD_SELECTED_SCLK_INDEX"
  "IS_AMD"
  "IS_INTEL"
  "IS_ARM"
  "IS_ASAHI"
  "ASAHI_HEATPIPE_PATH"
)

declare -a ordered_categories=("PowerControl" "GPUControl" "Platform Configuration")
declare -A categories=(
  ["PowerControl"]="MAX_TEMP MIN_TEMP MAX_PERF_PCT MIN_PERF_PCT HOTZONE CPU_POLL RAMP_UP RAMP_DOWN"
  ["GPUControl"]="GPU_MAX_FREQ"
  ["Platform Configuration"]="IS_AMD IS_INTEL IS_ARM IS_ASAHI ASAHI_HEATPIPE_PATH PERF_PATH PERF_PATHS TURBO_PATH GPU_TYPE GPU_FREQ_PATH ORIGINAL_GPU_MAX_FREQ PP_OD_FILE AMD_SELECTED_SCLK_INDEX")
  
if [[ -z "${ORIGINAL_GPU_MAX_FREQ}" ]]; then ORIGINAL_GPU_MAX_FREQ=$GPU_MAX_FREQ; fi
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
  [GPU_MAX_FREQ]=$GPU_MAX_FREQ
  [GPU_TYPE]=$GPU_TYPE
  [GPU_FREQ_PATH]=$GPU_FREQ_PATH
  [ORIGINAL_GPU_MAX_FREQ]=$GPU_MAX_FREQ
  [PP_OD_FILE]=$PP_OD_FILE
  [AMD_SELECTED_SCLK_INDEX]=$AMD_SELECTED_SCLK_INDEX
  [IS_AMD]=$IS_AMD
  [IS_INTEL]=$IS_INTEL
  [IS_ARM]=$IS_ARM
  [IS_ASAHI]=$IS_ASAHI
  [ASAHI_HEATPIPE_PATH]=$ASAHI_HEATPIPE_PATH
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
    sudo rm -r /usr/local/bin/gpucontrol 2>/dev/null
    sudo ln -sf "$INSTALL_DIR/powercontrol" /usr/local/bin/powercontrol
    sudo ln -sf "$INSTALL_DIR/gpucontrol" /usr/local/bin/gpucontrol
    echo ""
    
enable_component_on_boot() {
    local COLOR
    local component="$1"
    local config_file="$2"
    local var_name="STARTUP_$(echo "$component" | tr '[:lower:]' '[:upper:]')"
    local target_file="/etc/systemd/system/$(basename "$config_file")"

     case "$component" in
        "PowerControl")   COLOR=${CYAN}${BOLD} ;;
        "GPUControl")     COLOR=${MAGENTA}${BOLD} ;;
        *)                COLOR=${RESET} ;;
    esac
    
    read -rp "${COLOR}Do you want $component enabled on boot?${RESET}${BOLD} (Y/n):${RESET} " move_config
    if [[ -z "$move_config" || "$move_config" =~ ^[Yy]$ ]]; then
        sudo cp "$config_file" "$target_file"
        echo "$var_name=1" | sudo tee -a "$CONFIG_FILE" > /dev/null
        sudo systemctl daemon-reload
        sudo systemctl enable --now $target_file
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
        enable_component_on_boot "PowerControl" "$INSTALL_DIR/powercontrol.service"
        enable_component_on_boot "GPUControl" "$INSTALL_DIR/gpucontrol.service"
    else
        echo "Skipping boot-time setup."
    fi
else
    echo "${YELLOW}Rootfs verification must be disabled to allow startup on boot. ${RESET}"
fi

if grep -q '^STARTUP_POWERCONTROL=1' "$CONFIG_FILE"; then
    SHOW_POWERCONTROL_NOTICE=1
fi

if grep -q '^STARTUP_GPUCONTROL=1' "$CONFIG_FILE"; then
    SHOW_GPUCONTROL_NOTICE=1
fi

start_component_now() {
    local component="$1"
    local command="$2"
    local COLOR

    case "$component" in
        "PowerControl")   COLOR=${CYAN}${BOLD} ;;
        "GPUControl")     COLOR=${MAGENTA}${BOLD} ;;
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

sudo chown -R 1000:1000 "$CONFIG_DIR" 2>/dev/null
sudo chown 1000:1000 "$CONFIG_DIR/config" 2>/dev/null

echo
start_component_now "PowerControl" "$INSTALL_DIR/powercontrol"
start_component_now "GPuControl" "$INSTALL_DIR/gpucontrol"
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
echo "║  sudo powercontrol startup          # Copy or Remove no_turbo.service & powercontrol.service                       ║"
sleep 0.01
echo "║                                                                                                                    ║"
sleep 0.01
echo "║  sudo powercontrol version      # Check PowerControl version                                                       ║"
sleep 0.01
echo "║  sudo powercontrol reinstall    # Download and reinstall PowerControl                                              ║"
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
sudo -E /bin/powercontrol-gui 2>/dev/null &
