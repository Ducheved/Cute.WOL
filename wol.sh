#!/usr/bin/sudo /bin/bash

declare -A SUPPORTED_WOL_METHODS

if ! command -v ethtool &> /dev/null; then
    OS=$(uname -a)
    if [[ $OS == *"Ubuntu"* ]] || [[ $OS == *"Debian"* ]]; then
        echo -e "\e[34mInstalling ethtool with apt...\e[0m"
        sudo apt update && sudo apt install -y ethtool
    elif [[ $OS == *"CentOS"* ]] || [[ $OS == *"Fedora"* ]]; then
        echo -e "\e[34mInstalling ethtool with yum...\e[0m"
        sudo yum install -y ethtool
    elif [[ $OS == *"Alpine"* ]]; then
        echo -e "\e[34mInstalling ethtool with apk...\e[0m"
        sudo apk add ethtool
    else
        echo -e "\e[31mUnsupported OS. Please install ethtool manually.\e[0m"
        exit 1
    fi
fi

get_wol_method_description() {
    case "$1" in
        p) echo "Wake on PHY activity" ;;
        u) echo "Wake on unicast messages" ;;
        m) echo "Wake on multicast messages" ;;
        b) echo "Wake on broadcast messages" ;;
        a) echo "Wake on ARP" ;;
        g) echo "Wake on MagicPacket™" ;;
        s) echo "Enable SecureOn™ password for MagicPacket™" ;;
    esac
}

ask_user_to_enable_wol() {
    read -p "Do you want to enable Wake-on-LAN for $1? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sudo ethtool -s $1 wol g
        SUPPORTED_WOL_METHODS[$1]="g"
    fi
}

INTERFACES=$(ls /sys/class/net | grep -v "lo\|docker\|br-\|veth\|cbr\|vir\|tun\|tap\|flannel\|cni0\|calico")

for INTERFACE in $INTERFACES; do
    if ethtool $INTERFACE | grep -q "Supports Wake-on:"; then
        WOL_SETTINGS=$(ethtool $INTERFACE | grep "Wake-on:" | awk '{print $2}')
        SUPPORTED_WOL_METHODS[$INTERFACE]=$WOL_SETTINGS
        if [[ $WOL_SETTINGS != *"g"* ]]; then
            ask_user_to_enable_wol $INTERFACE
        fi
    fi
done

printf "\e[1;33m%-20s %-20s %-20s %-40s %-20s\e[0m\n" "Interface" "MAC Address" "Wake-on-LAN" "Driver Features" "IP Address"
printf '%.0s-' {1..120}; echo ""
for INTERFACE in $INTERFACES; do
    MAC_ADDRESS=$(cat /sys/class/net/$INTERFACE/address)
    IP_ADDRESS=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [[ ${SUPPORTED_WOL_METHODS[$INTERFACE]} ]]; then
        if [[ ${SUPPORTED_WOL_METHODS[$INTERFACE]} == *"g"* ]]; then
            WOL_STATUS="Enabled"
        else
            WOL_STATUS="Disabled"
        fi
    else
        WOL_STATUS="Not Supported"
    fi
    DRIVER_FEATURES=$(ethtool $INTERFACE | grep "Supports Wake-on:" | sed -e 's/^[ \t]*//')
    printf "%-20s %-20s %-20s %-40s %-20s\n" "$INTERFACE" "$MAC_ADDRESS" "$WOL_STATUS" "$DRIVER_FEATURES" "$IP_ADDRESS"
    printf '%.0s-' {1..120}; echo ""
done

if [[ ${#SUPPORTED_WOL_METHODS[@]} -gt 0 ]]; then
    echo -e "\n\e[1;33mSupports Wake-on values explanation:\e[0m"
    printf "\e[1;33m%-10s %-70s %-40s\e[0m\n" "Value" "Meaning" "Interfaces"
    printf '%.0s-' {1..120}; echo ""
    for METHOD in p u m b a g s; do
        INTERFACES=""
        for INTERFACE in "${!SUPPORTED_WOL_METHODS[@]}"; do
            if [[ ${SUPPORTED_WOL_METHODS[$INTERFACE]} == *"$METHOD"* ]]; then
                INTERFACES+="$INTERFACE "
            fi
        done
        printf "\e[1m%-10s %-70s %-40s\e[0m\n" "$METHOD" "$(get_wol_method_description $METHOD)" "$INTERFACES"
    done
    printf '%.0s-' {1..120}; echo ""
fi