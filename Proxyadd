#!/bin/bash

# Function to validate IP address format
isValidIP() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        echo "Invalid IP address format."
        exit 1
    fi
}

# Ensure the script is run as root
echo "Running as $(whoami)"
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root permissions."
    exec sudo "$0" "$@"
fi

# Main menu function
mainMenu() {
    echo "Choose an option:"
    echo "1) Add a proxy"
    echo "2) Remove a proxy"
    echo "3) List all proxies"
    echo "4) Exit"
    read -r choice

    case $choice in
        1) addProxy ;;
        2) removeProxy ;;
        3) listProxies ;;
        4) exit 0 ;;
        *) echo "Invalid option selected." ;;
    esac
}

# Add a proxy function
addProxy() {
    declare -A validProxyTypes=( ["https"]=1 ["http"]=1 ["socks4"]=1 ["socks5"]=1 )

    echo "Enter proxy type (https, http, socks4, socks5):"
    read -r proxytype

    if [[ -z "${validProxyTypes[$proxytype]}" ]]; then
        echo "Invalid proxy type. Please choose from https, http, socks4, or socks5."
        return
    fi

    echo "Enter proxy IP address:"
    read -r proxyip
    isValidIP $proxyip

    echo "Enter port:"
    read -r port
    if ! [[ $port =~ ^[0-9]+$ ]] || [ "$port" -gt 65535 ]; then
        echo "Invalid port. Please enter a number between 1 and 65535."
        return
    fi

    echo "$proxytype $proxyip $port" >> /etc/proxychains.conf
    echo "Proxy successfully added."
}

# Remove a proxy function
removeProxy() {
    echo "Enter the proxy type, IP, and port to remove (format: type ip port):"
    read -r removeType removeIP removePort
    if isValidIP $removeIP && [[ "$removePort" =~ ^[0-9]+$ ]] && [ "$removePort" -le 65535 ]; then
        grep -v "$removeType $removeIP $removePort" /etc/proxychains.conf > /tmp/proxychains.tmp && mv /tmp/proxychains.tmp /etc/proxychains.conf
        echo "If the proxy was previously listed, it has been removed."
    else
        echo "Invalid input. Ensure the format is correct and values are valid."
    fi
}

# List all proxies function
listProxies() {
    echo "Currently configured proxies:"
    grep -vE '^#|^$' /etc/proxychains.conf
}

# Loop the main menu
while true; do
    mainMenu
done
