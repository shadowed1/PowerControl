#!/bin/bash
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)
rm -f ~/Install_PowerControl.sh 2>/dev/null
curl -L https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/Install_PowerControl.sh -o ~/Install_PowerControl.sh
chmod +x ~/Install_PowerControl.sh
sudo mkdir -p /usr/local/bin
sudo -E bash ~/Install_PowerControl.sh
