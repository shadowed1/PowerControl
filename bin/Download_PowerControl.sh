#!/bin/bash
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)
echo ""
echo ""
echo ""
echo ""
echo ""
echo "                                                         ${BOLD}Features:${RESET}"
echo "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
echo "║ Control CPU clockspeed in relation to temperature; enabling lower temperatures under and longer battery life. ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
echo "${RESET}"
echo ""
echo ""
rm -f ~/Install_PowerControl.sh 2>/dev/null
curl -L https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/Install_PowerControl.sh -o ~/Install_PowerControl.sh
chmod +x ~/Install_PowerControl.sh
sudo -E bash ~/Install_PowerControl.sh
