#!/bin/bash
# Script to uninstall remote desktop services (XRDP and VNC) on a Linux system
# with user confirmation and cleanup of configurations and firewall rules.

set -euo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Script configuration
SCRIPT_NAME="Ubuntu Remote Desktop Setup"
LOG_FILE="/tmp/remote_desktop_setup.log"

# Function to print coloured output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

uninstall_remote_desktop() {
    print_header "Uninstalling Remote Desktop Services"
    
    echo "This will remove all remote desktop services and configurations."
    read -rp "Are you sure you want to continue? [y/N]: " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_status "Uninstall cancelled."
        return
    fi
    
    print_status "Stopping and disabling services..."
    
    # Stop and disable XRDP
    if systemctl is-active --quiet xrdp; then
        sudo systemctl stop xrdp
        print_status "XRDP service stopped"
    fi
    if systemctl is-enabled --quiet xrdp 2>/dev/null; then
        sudo systemctl disable xrdp
        print_status "XRDP service disabled"
    fi
    
    # Stop and disable VNC
    if systemctl is-active --quiet vncserver@1; then
        sudo systemctl stop vncserver@1
        print_status "VNC service stopped"
    fi
    if systemctl is-enabled --quiet vncserver@1 2>/dev/null; then
        sudo systemctl disable vncserver@1
        print_status "VNC service disabled"
    fi
    
    print_status "Removing packages..."
    sudo apt remove --purge -y xrdp xrdp-pulseaudio-installer tigervnc-standalone-server tigervnc-common 2>/dev/null || true
    sudo apt autoremove -y
    
    print_status "Removing configuration files..."
    rm -rf ~/.vnc 2>/dev/null || true
    sudo rm -f /etc/systemd/system/vncserver@.service 2>/dev/null || true
    sudo rm -f /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla 2>/dev/null || true
    
    print_status "Removing firewall rules..."
    # Remove UFW rules if they exist
    if command -v ufw &> /dev/null; then
        sudo ufw --force delete allow 3389 2>/dev/null || true
        sudo ufw --force delete allow 5901 2>/dev/null || true
        # Remove specific network rules
        local ip_range
        ip_range=$(ip route | grep "$(ip route get 1.1.1.1 | awk '{print $5}' | head -n 1)" | grep -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.' | head -n 1 | awk '{print $1}')
        if [[ -n "$ip_range" ]]; then
            sudo ufw --force delete allow from "$ip_range" to any port 3389 2>/dev/null || true
            sudo ufw --force delete allow from "$ip_range" to any port 5901 2>/dev/null || true
        fi
    fi
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    print_header "Remote desktop services uninstalled successfully!"
    read -rp "Press Enter to continue..."
}

# Example usage of the function
echo print_header "Removal Script for $SCRIPT_NAME"
check_root
uninstall_remote_desktop
print_status "Uninstallation process completed."
print_status "Log file located at: $LOG_FILE"
print_status ""
exit 0