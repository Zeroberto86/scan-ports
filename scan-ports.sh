#!/usr/bin/env bash
#
# Script Name: scan-ports
# Version: 1.0
# Description: Script for scanning ports
# Author: Zeroberto86
# Created Date: 26.06.2023
# License: GNU GPL
#

# set -x

# Check if the user has sudo privileges
if ! sudo -v &>/dev/null; then
  echo "You do not have sudo privileges."
  exit 0
fi

SCAN_LOG='/tmp/scan_results.log'
if [[ -f $SCAN_LOG ]]; then
  sudo rm -rf $SCAN_LOG
fi

install -m 755 /dev/null $SCAN_LOG

# function all letters to lowercase
function lowercase(){
    local TEXT="$1"
    echo $TEXT | tr '[:upper:]' '[:lower:]' 
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install packages on Debian/Ubuntu
install_packages_debian() {
    sudo apt-get update
    sudo apt-get install -y "$@"
}

# Function to install packages on Fedora
install_packages_fedora() {
    sudo dnf install -y "$@"
}

# Function to install packages on CentOS
install_packages_centos() {
    sudo yum install -y "$@"
}

# Function to install packages on Arch Linux
install_packages_arch() {
    sudo pacman -Sy --noconfirm "$@"
}

# Check if packages are already installed
packages=("netcat" "nmap" "curl" "jq")
missing_packages=()
for package in "${packages[@]}"; do
    if ! command_exists "$package"; then
        missing_packages+=("$package")
    fi
done

if ! [[ ${#missing_packages[@]} -eq 0 ]]; then

# Determine the Linux distribution
if command_exists lsb_release; then
    distro=$(lowercase $(lsb_release -si))
else
    distro=$(cat /etc/os-release | grep -oP '(?<=^ID=).+' | tr -d '"')
fi

# Install packages based on the Linux distribution
case "$distro" in
    debian*|ubuntu*)
        install_packages_debian "${missing_packages[@]}"
        ;;
    fedora*)
        install_packages_fedora "${missing_packages[@]}"
        ;;
    centos*)
        install_packages_centos "${missing_packages[@]}"
        ;;
    arch*)
        install_packages_arch "${missing_packages[@]}"
        ;;
    *)
        echo "Unsupported distribution: $distro. Cannot install packages."
        exit 1
        ;;
esac

# Check if installation was successful
for package in "${missing_packages[@]}"; do
    if command_exists "$package"; then
        echo "$package has been successfully installed."
    else
        echo "Failed to install $package."
    fi
done

fi

# Function for scanning a port on a host and analyzing the running service
scan_port() {
    local HOST="$1"
    local PORT="$2"
    local TIMEOUT=3

    # Use the nc (netcat) command to check port availability and retrieve service information
    SCAN_RESULT=$(nc -zvw$TIMEOUT "$HOST" "$PORT" 2>&1 </dev/null)
   
    # Check if the port is open
    if [[ $SCAN_RESULT =~ succeeded ]] || [[ $SCAN_RESULT =~ open ]]; then
        SERVICE_NAME=$(timeout $TIMEOUT_NMAP nmap -T4 -p "$PORT" -sV --open "$HOST" 2>/dev/null | grep -e "^$PORT" | sed -E 's/[[:space:]]+/ /g' | awk '{for (i=3; i<=NF; i++) printf "%s", $i " "}')
        if [[ -z $SERVICE_NAME ]]; then
            SERVICE_NAME='unknown'
        fi
        # echo -e "${YELLOW}Port ${GREEN}$PORT${YELLOW} on host ${GREEN}$HOST${YELLOW} is ${GREEN}open${YELLOW}; service is ${BLUE}$SERVICE_NAME${END}" >> /tmp/scan_file.log
        echo -e "Port $PORT on host $HOST is open; service is $SERVICE_NAME" | tee -a $SCAN_LOG &>/dev/null
    # else
    #     echo "Port $PORT on host $HOST is closed."
    fi

}

# Enter the host (IP address or domain name) to scan
if [[ -z $1 ]]; then
    echo -e "\nYou can use script with argument: scan-ports <ip-address> <start-port> <end-port> <time-out sec>\n"
    echo -e "Example: scan-ports 192.168.0.1 21 445 30"
    read -p "Enter the host to scan (IP address or domain name): " HOST
else
    HOST=$1
fi

# Enter the range of ports to scan
if [[ -z $2 ]] && [[ -z $3 ]]; then
read -p "Enter the range of ports (start and end port, separated by a space): " START_PORT END_PORT
else
    START_PORT=$2
    END_PORT=$3
fi
# Check the entered values
if ! [[ $START_PORT =~ ^[0-9]+$ ]] || ! [[ $END_PORT =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid port range. Ports must contain only numbers."
    exit 1
fi

if (( $START_PORT > $END_PORT )); then
    echo "Error: Invalid port range. The end port must be larger than the start port."
    exit 1
fi

if [[ -z $4 ]]; then
    TIMEOUT_NMAP=60
else
    TIMEOUT_NMAP=$4
fi

if ! [[ $TIMEOUT_NMAP =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid timeout."
    exit 1
fi

# Scan the ports in the specified range (parallel execution)
for ((PORT = START_PORT; PORT <= END_PORT; PORT++)); do
    printf "\x1b[30;43mScanning in progress, please wait...\x1b[0m\r" 
    scan_port "$HOST" "$PORT" &
    sleep 0.5
done

# Wait for all scanning processes to finish
wait

if [ ! -s "$SCAN_LOG" ]; then
  printf "\x1b[2K\x1b[30;43mOpen ports not found...\x1b[0m\n"
fi

# color output
sort -n -k2 $SCAN_LOG | sed -E 's/Port ([0-9]+)/Port \x1b[01;32m\1\x1b[0m/g; s/([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/\x1b[01;31m\0\x1b[0m/g; s/service is ([^;]+)/service is \x1b[01;33m\1\x1b[0m/g'