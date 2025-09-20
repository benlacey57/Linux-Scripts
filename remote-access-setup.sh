#!/bin/bash

# Ubuntu Remote Desktop Setup Script
# Supports XRDP and VNC server installation and configuration
# Author: Assistant
# Version: 1.0

set -euo pipefail

# Colours for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Colour

# Script configuration
readonly SCRIPT_NAME="Ubuntu Remote Desktop Setup"
readonly LOG_FILE="/tmp/remote_desktop_setup.log"

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

# Function to check Ubuntu version
check_ubuntu() {
    if ! command -v lsb_release &> /dev/null; then
        print_error "This script is designed for Ubuntu systems."
        exit 1
    fi
    
    local ubuntu_version
    ubuntu_version=$(lsb_release -rs)
    print_status "Detected Ubuntu version: $ubuntu_version"
}

# Function to update system packages
update_system() {
    print_status "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    print_status "System update completed."
}

# Function to install XRDP
install_xrdp() {
    print_header "Installing XRDP..."
    
    # Install XRDP packages
    sudo apt install -y xrdp xrdp-pulseaudio-installer
    
    # Add user to ssl-cert group
    sudo adduser "$USER" ssl-cert
    
    # Configure XRDP
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    
    # Configure firewall if UFW is active
    if sudo ufw status | grep -q "Status: active"; then
        print_status "Configuring UFW firewall for XRDP..."
        sudo ufw allow 3389/tcp
    fi
    
    # Create polkit rule to avoid authentication prompts
    sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla > /dev/null << 'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
    
    # Restart XRDP service
    sudo systemctl restart xrdp
    
    print_status "XRDP installation completed."
    print_status "XRDP is accessible on port 3389"
}

# Function to install VNC server
install_vnc() {
    print_header "Installing VNC Server..."
    
    # Install VNC packages
    sudo apt install -y tigervnc-standalone-server tigervnc-common
    
    # Create VNC directory
    mkdir -p "$HOME/.vnc"
    
    # Create VNC startup script
    cat > "$HOME/.vnc/xstartup" << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Try different desktop environments in order of preference
if command -v gnome-session &> /dev/null; then
    exec gnome-session
elif command -v startxfce4 &> /dev/null; then
    exec startxfce4
elif command -v startkde &> /dev/null; then
    exec startkde
else
    # Fallback to basic window manager
    exec /etc/X11/Xsession
fi
EOF
    
    chmod +x "$HOME/.vnc/xstartup"
    
    # Set VNC password
    print_status "Setting up VNC password..."
    echo "Please set a password for VNC access (6-8 characters):"
    vncpasswd
    
    # Create systemd service for VNC
    sudo tee "/etc/systemd/system/vncserver@.service" > /dev/null << EOF
[Unit]
Description=Start VNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$HOME
PIDFile=$HOME/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1920x1080 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start VNC service
    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    sudo systemctl start vncserver@1.service
    
    # Configure firewall if UFW is active
    if sudo ufw status | grep -q "Status: active"; then
        print_status "Configuring UFW firewall for VNC..."
        sudo ufw allow 5901/tcp
    fi
    
    print_status "VNC Server installation completed."
    print_status "VNC is accessible on port 5901"
}

# Function to display network information
show_network_info() {
    print_header "Network Information"
    
    local ip_address
    ip_address=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)
    
    print_status "Your Ubuntu laptop's IP address: $ip_address"
    echo ""
    print_status "Connection details:"
    
    if systemctl is-active --quiet xrdp; then
        print_status "  XRDP: $ip_address:3389"
        print_status "  Use Microsoft Remote Desktop app"
    fi
    
    if systemctl is-active --quiet vncserver@1; then
        print_status "  VNC: $ip_address:5901"
        print_status "  Use VNC Viewer app"
    fi
}

# Function to show mobile app recommendations
show_mobile_apps() {
    print_header "Recommended Mobile Apps"
    echo ""
    print_status "For XRDP connections:"
    print_status "  Android/iOS: Microsoft Remote Desktop"
    echo ""
    print_status "For VNC connections:"
    print_status "  Android/iOS: VNC Viewer by RealVNC"
    echo ""
    print_status "Both apps are available in Google Play Store and Apple App Store"
}

# Function to backup firewall configuration
backup_firewall_config() {
    local backup_dir="$HOME/firewall-backups"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/firewall-rules-$timestamp.txt"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    print_status "Creating firewall backup: $backup_file"
    
    # Create comprehensive backup
    cat > "$backup_file" << EOF
# Firewall Configuration Backup
# Created: $(date)
# Hostname: $(hostname)
# User: $USER
# Script: $SCRIPT_NAME

=== UFW STATUS ===
$(sudo ufw status verbose 2>/dev/null || echo "UFW not available")

=== UFW RULES (NUMBERED) ===
$(sudo ufw status numbered 2>/dev/null || echo "UFW not available")

=== UFW CONFIGURATION FILES ===
UFW Default Policy:
$(sudo cat /etc/default/ufw 2>/dev/null | grep -E '^(DEFAULT_|IPV6)' || echo "UFW config not accessible")

=== IPTABLES RULES ===
Filter Table:
$(sudo iptables -L -n --line-numbers 2>/dev/null || echo "iptables not accessible")

NAT Table:
$(sudo iptables -t nat -L -n --line-numbers 2>/dev/null || echo "iptables NAT not accessible")

=== IP6TABLES RULES ===
$(sudo ip6tables -L -n --line-numbers 2>/dev/null || echo "ip6tables not accessible")

=== CUSTOM RULES FILES ===
$(find /etc/ufw -name "*.rules" -exec echo "File: {}" \; -exec cat {} \; 2>/dev/null || echo "UFW rules files not accessible")

=== SYSTEM INFORMATION ===
Network Interfaces:
$(ip addr show 2>/dev/null | grep -E '^[0-9]+:' || echo "Network info not accessible")

Routing Table:
$(ip route show 2>/dev/null || echo "Routing info not accessible")

=== BACKUP COMPLETE ===
EOF
    
    if [[ -f "$backup_file" ]]; then
        print_status "Firewall configuration backed up successfully"
        print_status "Backup location: $backup_file"
        return 0
    else
        print_error "Failed to create firewall backup"
        return 1
    fi
}

# Function to list firewall backups
list_firewall_backups() {
    local backup_dir="$HOME/firewall-backups"
    
    print_header "Available Firewall Backups"
    echo ""
    
    if [[ -d "$backup_dir" ]]; then
        local backups
        backups=$(find "$backup_dir" -name "firewall-rules-*.txt" -type f 2>/dev/null | sort -r)
        
        if [[ -n "$backups" ]]; then
            echo "Backup files (newest first):"
            echo "$backups" | while read -r backup; do
                local filename
                filename=$(basename "$backup")
                local filesize
                filesize=$(du -h "$backup" 2>/dev/null | cut -f1)
                local modification_time
                modification_time=$(stat -c '%y' "$backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
                echo "  $filename ($filesize) - $modification_time"
            done
        else
            print_warning "No firewall backups found"
        fi
    else
        print_warning "No backup directory found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to restore firewall configuration
restore_firewall_config() {
    local backup_dir="$HOME/firewall-backups"
    
    print_header "Restore Firewall Configuration"
    echo ""
    
    if [[ ! -d "$backup_dir" ]]; then
        print_error "No backup directory found"
        read -p "Press Enter to continue..."
        return
    fi
    
    local backups
    backups=$(find "$backup_dir" -name "firewall-rules-*.txt" -type f 2>/dev/null | sort -r)
    
    if [[ -z "$backups" ]]; then
        print_error "No firewall backups found"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Available backups:"
    local counter=1
    declare -a backup_array
    
    echo "$backups" | while read -r backup; do
        local filename
        filename=$(basename "$backup")
        local modification_time
        modification_time=$(stat -c '%y' "$backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "$counter) $filename - $modification_time"
        backup_array[$counter]="$backup"
        ((counter++))
    done
    
    echo "$((counter))) Cancel"
    echo ""
    
    # Read backup files into array for selection
    readarray -t backup_files <<< "$backups"
    
    read -p "Select backup to restore (1-$counter): " backup_choice
    
    if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [[ $backup_choice -ge 1 ]] && [[ $backup_choice -lt $counter ]]; then
        local selected_backup="${backup_files[$((backup_choice-1))]}"
        
        print_warning "This will reset UFW and attempt to restore the selected configuration"
        print_warning "Current firewall rules will be lost!"
        echo ""
        read -p "Are you sure you want to continue? [y/N]: " confirm
        
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            print_status "Creating backup of current configuration before restore..."
            backup_firewall_config
            
            print_status "Restoring firewall configuration from: $(basename "$selected_backup")"
            
            # Reset UFW
            echo "y" | sudo ufw --force reset 2>/dev/null
            
            # Extract and apply UFW rules from backup
            print_status "Parsing backup file for UFW rules..."
            
            # This is a simplified restore - in practice, you'd need more sophisticated parsing
            # For now, we'll show the backup content and provide manual instructions
            echo ""
            print_status "Backup file contents:"
            echo "===================="
            cat "$selected_backup"
            echo "===================="
            echo ""
            
            print_warning "Automatic restore is complex due to UFW's rule format."
            print_status "Please manually reconfigure rules based on the backup above."
            print_status "Common commands:"
            echo "  sudo ufw enable"
            echo "  sudo ufw allow from [network] to any port [port]"
            echo "  sudo ufw deny [port]"
            
        else
            print_status "Restore cancelled"
        fi
    elif [[ $backup_choice -eq $counter ]]; then
        print_status "Restore cancelled"
    else
        print_error "Invalid selection"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to clean old backups
clean_old_backups() {
    local backup_dir="$HOME/firewall-backups"
    
    print_header "Clean Old Firewall Backups"
    echo ""
    
    if [[ ! -d "$backup_dir" ]]; then
        print_warning "No backup directory found"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Cleanup options:"
    echo "1) Keep last 5 backups"
    echo "2) Keep last 10 backups"
    echo "3) Delete backups older than 30 days"
    echo "4) Delete backups older than 90 days"
    echo "5) Delete all backups"
    echo "6) Cancel"
    echo ""
    
    read -p "Select cleanup option (1-6): " cleanup_choice
    
    case $cleanup_choice in
        1)
            cleanup_keep_last_n 5
            ;;
        2)
            cleanup_keep_last_n 10
            ;;
        3)
            cleanup_older_than_days 30
            ;;
        4)
            cleanup_older_than_days 90
            ;;
        5)
            cleanup_all_backups
            ;;
        6)
            print_status "Cleanup cancelled"
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Helper function to keep last N backups
cleanup_keep_last_n() {
    local keep_count=$1
    local backup_dir="$HOME/firewall-backups"
    
    local backups
    backups=$(find "$backup_dir" -name "firewall-rules-*.txt" -type f 2>/dev/null | sort -r)
    
    if [[ -z "$backups" ]]; then
        print_warning "No backups to clean"
        return
    fi
    
    local total_count
    total_count=$(echo "$backups" | wc -l)
    
    if [[ $total_count -le $keep_count ]]; then
        print_status "Only $total_count backups found, nothing to clean"
        return
    fi
    
    local to_delete
    to_delete=$(echo "$backups" | tail -n +$((keep_count + 1)))
    
    echo "Will delete $((total_count - keep_count)) old backups:"
    echo "$to_delete" | while read -r file; do
        echo "  $(basename "$file")"
    done
    echo ""
    
    read -p "Continue? [y/N]: " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        echo "$to_delete" | while read -r file; do
            rm -f "$file" && print_status "Deleted: $(basename "$file")"
        done
        print_status "Cleanup completed - kept last $keep_count backups"
    else
        print_status "Cleanup cancelled"
    fi
}

# Helper function to delete backups older than N days
cleanup_older_than_days() {
    local days=$1
    local backup_dir="$HOME/firewall-backups"
    
    local old_backups
    old_backups=$(find "$backup_dir" -name "firewall-rules-*.txt" -type f -mtime +$days 2>/dev/null)
    
    if [[ -z "$old_backups" ]]; then
        print_status "No backups older than $days days found"
        return
    fi
    
    echo "Backups older than $days days:"
    echo "$old_backups" | while read -r file; do
        local modification_time
        modification_time=$(stat -c '%y' "$file" 2>/dev/null | cut -d' ' -f1)
        echo "  $(basename "$file") - $modification_time"
    done
    echo ""
    
    read -p "Delete these backups? [y/N]: " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        echo "$old_backups" | while read -r file; do
            rm -f "$file" && print_status "Deleted: $(basename "$file")"
        done
        print_status "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Helper function to delete all backups
cleanup_all_backups() {
    local backup_dir="$HOME/firewall-backups"
    
    print_warning "This will delete ALL firewall backups!"
    read -p "Are you absolutely sure? [y/N]: " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        rm -f "$backup_dir"/firewall-rules-*.txt 2>/dev/null
        print_status "All firewall backups deleted"
    else
        print_status "Cleanup cancelled"
    fi
}
    print_header "Security Hardening Options"
    echo ""
    echo "Available hardening options:"
    echo "1) Local network only access (recommended)"
    echo "2) Specific IP address only"
    echo "3) Skip hardening (not recommended)"
    echo ""
    
    read -p "Choose hardening option (1-3): " hardening_choice
    
    case $hardening_choice in
        1)
            apply_local_network_hardening
            ;;
        2)
            apply_specific_ip_hardening
            ;;
        3)
            print_warning "Skipping security hardening - services will be accessible from any network!"
            ;;
        *)
            print_warning "Invalid choice. Applying local network hardening by default."
            apply_local_network_hardening
            ;;
    esac
}

# Function to apply local network hardening
apply_local_network_hardening() {
    print_status "Applying local network hardening..."
    
    # Create backup before making changes
    if ! backup_firewall_config; then
        print_warning "Failed to create backup, but continuing with hardening..."
    fi
    
    local ip_range
    ip_range=$(ip route | grep "$(ip route get 1.1.1.1 | awk '{print $5}' | head -n 1)" | grep -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.' | head -n 1 | awk '{print $1}')
    
    if [[ -n "$ip_range" ]]; then
        print_status "Detected local network range: $ip_range"
        
        if command -v ufw &> /dev/null; then
            # Remove any existing broad rules
            sudo ufw --force delete allow 3389 2>/dev/null || true
            sudo ufw --force delete allow 5901 2>/dev/null || true
            
            # Add specific network rules
            sudo ufw allow from "$ip_range" to any port 3389 comment "XRDP local network"
            sudo ufw allow from "$ip_range" to any port 5901 comment "VNC local network"
            
            # Ensure UFW is enabled
            echo "y" | sudo ufw enable 2>/dev/null || true
            
            print_status "Firewall configured for local network access only"
            print_status "Backup created before applying changes"
        else
            print_warning "UFW not available. Please install ufw for firewall management."
        fi
    else
        print_error "Could not detect local network range. Manual configuration required."
    fi
}

# Function to apply specific IP hardening
apply_specific_ip_hardening() {
    print_status "Configure specific IP address access..."
    
    # Create backup before making changes
    if ! backup_firewall_config; then
        print_warning "Failed to create backup, but continuing with hardening..."
    fi
    
    echo ""
    echo "Enter the IP addresses that should have access (one per line)."
    echo "Press Enter on empty line when finished:"
    
    local ips=()
    while true; do
        read -p "IP address: " ip
        if [[ -z "$ip" ]]; then
            break
        fi
        
        # Basic IP validation
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ips+=("$ip")
            print_status "Added: $ip"
        else
            print_error "Invalid IP format: $ip"
        fi
    done
    
    if [[ ${#ips[@]} -eq 0 ]]; then
        print_warning "No valid IPs provided. Falling back to local network hardening."
        apply_local_network_hardening
        return
    fi
    
    if command -v ufw &> /dev/null; then
        # Remove any existing rules
        sudo ufw --force delete allow 3389 2>/dev/null || true
        sudo ufw --force delete allow 5901 2>/dev/null || true
        
        # Add rules for each IP
        for ip in "${ips[@]}"; do
            sudo ufw allow from "$ip" to any port 3389 comment "XRDP specific IP"
            sudo ufw allow from "$ip" to any port 5901 comment "VNC specific IP"
            print_status "Added firewall rules for: $ip"
        done
        
        # Ensure UFW is enabled
        echo "y" | sudo ufw enable 2>/dev/null || true
        
        print_status "Firewall configured for specific IP access only"
        print_status "Backup created before applying changes"
    fi
}

# Function for firewall management menu
firewall_management() {
    while true; do
        clear
        print_header "Firewall Management"
        echo ""
        echo "1) View current firewall status"
        echo "2) View all firewall rules"
        echo "3) Apply local network hardening"
        echo "4) Apply specific IP hardening"
        echo "5) Remove all remote desktop firewall rules"
        echo "6) Enable UFW firewall"
        echo "7) Disable UFW firewall"
        echo "8) Reset UFW to defaults"
        echo "9) List firewall backups"
        echo "10) Restore firewall configuration"
        echo "11) Clean old backups"
        echo "12) Return to main menu"
        echo ""
        
        read -p "Enter your choice (1-12): " fw_choice
        
        case $fw_choice in
            1)
                show_firewall_status
                ;;
            2)
                show_all_firewall_rules
                ;;
            3)
                apply_local_network_hardening
                read -p "Press Enter to continue..."
                ;;
            4)
                apply_specific_ip_hardening
                read -p "Press Enter to continue..."
                ;;
            5)
                remove_rd_firewall_rules
                ;;
            6)
                enable_firewall
                ;;
            7)
                disable_firewall
                ;;
            8)
                reset_firewall
                ;;
            9)
                list_firewall_backups
                ;;
            10)
                restore_firewall_config
                ;;
            11)
                clean_old_backups
                ;;
            12)
                return
                ;;
            *)
                print_error "Invalid choice. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to show firewall status
show_firewall_status() {
    print_header "Current Firewall Status"
    echo ""
    
    if command -v ufw &> /dev/null; then
        sudo ufw status verbose
        echo ""
        
        # Check for remote desktop related rules
        local rd_rules
        rd_rules=$(sudo ufw status numbered | grep -E "(3389|5901)" || echo "")
        
        if [[ -n "$rd_rules" ]]; then
            print_status "Remote Desktop Firewall Rules:"
            echo "$rd_rules"
        else
            print_warning "No remote desktop firewall rules found"
        fi
    else
        print_error "UFW firewall is not installed"
        echo "Install with: sudo apt install ufw"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show all firewall rules
show_all_firewall_rules() {
    print_header "All Firewall Rules"
    echo ""
    
    if command -v ufw &> /dev/null; then
        print_status "UFW Status:"
        sudo ufw status numbered
        echo ""
        
        print_status "Raw iptables rules (INPUT chain):"
        sudo iptables -L INPUT -n --line-numbers | grep -E "(3389|5901|ACCEPT|DROP|REJECT)" || echo "No relevant rules found"
    else
        print_error "UFW firewall is not installed"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to remove remote desktop firewall rules
remove_rd_firewall_rules() {
    print_header "Remove Remote Desktop Firewall Rules"
    echo ""
    print_warning "This will remove all firewall rules for ports 3389 (RDP) and 5901 (VNC)"
    read -p "Are you sure you want to continue? [y/N]: " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        if command -v ufw &> /dev/null; then
            # Get rule numbers and delete them
            local rule_numbers
            rule_numbers=$(sudo ufw status numbered | grep -E "(3389|5901)" | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g' | sort -nr)
            
            for rule_num in $rule_numbers; do
                echo "y" | sudo ufw delete "$rule_num" 2>/dev/null || true
            done
            
            # Also try to delete by rule content
            sudo ufw --force delete allow 3389 2>/dev/null || true
            sudo ufw --force delete allow 5901 2>/dev/null || true
            
            print_status "Remote desktop firewall rules removed"
        else
            print_error "UFW not available"
        fi
    else
        print_status "Operation cancelled"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to enable firewall
enable_firewall() {
    print_header "Enable UFW Firewall"
    echo ""
    print_warning "Enabling firewall may block SSH connections if not configured properly"
    read -p "Continue? [y/N]: " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        if command -v ufw &> /dev/null; then
            echo "y" | sudo ufw enable
            print_status "UFW firewall enabled"
        else
            print_error "UFW not installed. Installing..."
            sudo apt update && sudo apt install -y ufw
            echo "y" | sudo ufw enable
            print_status "UFW installed and enabled"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Function to disable firewall
disable_firewall() {
    print_header "Disable UFW Firewall"
    echo ""
    read -p "Are you sure you want to disable the firewall? [y/N]: " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        if command -v ufw &> /dev/null; then
            sudo ufw disable
            print_status "UFW firewall disabled"
        else
            print_status "UFW not installed - nothing to disable"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Function to reset firewall
reset_firewall() {
    print_header "Reset UFW Firewall"
    echo ""
    print_warning "This will remove ALL firewall rules and reset to defaults"
    read -p "Are you sure you want to continue? [y/N]: " confirm
    
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        if command -v ufw &> /dev/null; then
            echo "y" | sudo ufw --force reset
            print_status "UFW firewall reset to defaults"
        else
            print_status "UFW not installed - nothing to reset"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Function for troubleshooting
troubleshooter() {
    while true; do
        clear
        print_header "Remote Desktop Troubleshooter"
        echo ""
        echo "Common issues and solutions:"
        echo "1) Cannot connect from mobile device"
        echo "2) Services not starting"
        echo "3) Authentication failures"
        echo "4) Performance issues"
        echo "5) Firewall blocking connections"
        echo "6) Run comprehensive diagnostic"
        echo "7) Restart all remote desktop services"
        echo "8) Return to main menu"
        echo ""
        
        read -p "Select an issue to troubleshoot (1-8): " trouble_choice
        
        case $trouble_choice in
            1)
                troubleshoot_connection
                ;;
            2)
                troubleshoot_services
                ;;
            3)
                troubleshoot_authentication
                ;;
            4)
                troubleshoot_performance
                ;;
            5)
                troubleshoot_firewall
                ;;
            6)
                run_comprehensive_diagnostic
                ;;
            7)
                restart_all_services
                ;;
            8)
                return
                ;;
            *)
                print_error "Invalid choice. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Troubleshooting functions
troubleshoot_connection() {
    print_header "Connection Troubleshooting"
    echo ""
    
    local ip_address
    ip_address=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)
    
    print_status "Step 1: Verify network connectivity"
    echo "Your IP address: $ip_address"
    echo "Try pinging from your mobile device: ping $ip_address"
    echo ""
    
    print_status "Step 2: Check service status"
    if systemctl is-active --quiet xrdp; then
        echo -e "XRDP: ${GREEN}Running${NC}"
    else
        echo -e "XRDP: ${RED}Not running${NC}"
        echo "Try: sudo systemctl start xrdp"
    fi
    
    if systemctl is-active --quiet vncserver@1; then
        echo -e "VNC: ${GREEN}Running${NC}"
    else
        echo -e "VNC: ${RED}Not running${NC}"
        echo "Try: sudo systemctl start vncserver@1"
    fi
    echo ""
    
    print_status "Step 3: Check firewall"
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        local rd_rules
        rd_rules=$(sudo ufw status | grep -E "(3389|5901)" || echo "")
        if [[ -n "$rd_rules" ]]; then
            echo -e "Firewall rules: ${GREEN}Found${NC}"
            echo "$rd_rules"
        else
            echo -e "Firewall rules: ${RED}Missing${NC}"
            echo "Consider running firewall management to add rules"
        fi
    else
        echo "Firewall: Disabled or not configured"
    fi
    echo ""
    
    print_status "Step 4: Check ports"
    local rdp_listening vnc_listening
    rdp_listening=$(ss -tlnp | grep ":3389 " || echo "")
    vnc_listening=$(ss -tlnp | grep ":5901 " || echo "")
    
    if [[ -n "$rdp_listening" ]]; then
        echo -e "Port 3389 (RDP): ${GREEN}Listening${NC}"
    else
        echo -e "Port 3389 (RDP): ${RED}Not listening${NC}"
    fi
    
    if [[ -n "$vnc_listening" ]]; then
        echo -e "Port 5901 (VNC): ${GREEN}Listening${NC}"
    else
        echo -e "Port 5901 (VNC): ${RED}Not listening${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Additional troubleshooting functions would continue here...
troubleshoot_services() {
    print_header "Service Troubleshooting"
    echo ""
    
    print_status "Checking XRDP service..."
    if systemctl is-installed xrdp &>/dev/null; then
        sudo systemctl status xrdp --no-pager -l
        echo ""
        print_status "Recent XRDP logs:"
        sudo journalctl -u xrdp --no-pager -n 10
    else
        echo "XRDP not installed"
    fi
    echo ""
    
    print_status "Checking VNC service..."
    if systemctl is-installed vncserver@1 &>/dev/null; then
        sudo systemctl status vncserver@1 --no-pager -l
        echo ""
        print_status "Recent VNC logs:"
        sudo journalctl -u vncserver@1 --no-pager -n 10
    else
        echo "VNC not installed"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Continue with more troubleshooting functions...
troubleshoot_authentication() {
    print_header "Authentication Troubleshooting"
    echo ""
    
    print_status "Current user information:"
    echo "Username: $USER"
    echo "User ID: $(id -u)"
    echo "Groups: $(groups)"
    echo ""
    
    print_status "For XRDP connections:"
    echo "- Use your Ubuntu username: $USER"
    echo "- Use your Ubuntu password"
    echo "- Make sure account is not locked"
    echo ""
    
    print_status "For VNC connections:"
    if [[ -f "$HOME/.vnc/passwd" ]]; then
        echo -e "- VNC password: ${GREEN}Set${NC}"
        echo "- Use the password you set during VNC configuration"
    else
        echo -e "- VNC password: ${RED}Not set${NC}"
        echo "- Run: vncpasswd to set VNC password"
    fi
    echo ""
    
    print_status "Check account status:"
    if command -v passwd &> /dev/null; then
        passwd -S "$USER" 2>/dev/null || echo "Cannot check password status"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

troubleshoot_performance() {
    print_header "Performance Troubleshooting"
    echo ""
    
    print_status "System resources:"
    echo "CPU usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "Disk usage: $(df -h / | tail -1 | awk '{print $5}')"
    echo ""
    
    print_status "Active remote desktop processes:"
    ps aux | grep -E "(xrdp|vnc)" | grep -v grep || echo "No processes found"
    echo ""
    
    print_status "Performance recommendations:"
    echo "1. Close unnecessary applications"
    echo "2. Use lower screen resolution (1280x720 instead of 1920x1080)"
    echo "3. Disable desktop effects and animations"
    echo "4. Use lightweight desktop environment (XFCE instead of GNOME)"
    echo ""
    
    read -p "Press Enter to continue..."
}

troubleshoot_firewall() {
    print_header "Firewall Troubleshooting"
    echo ""
    
    if command -v ufw &> /dev/null; then
        print_status "UFW Status:"
        sudo ufw status verbose
        echo ""
        
        print_status "Remote desktop rules:"
        sudo ufw status numbered | grep -E "(3389|5901)" || echo "No remote desktop rules found"
        echo ""
        
        print_status "Quick fixes:"
        echo "1. Add local network access:"
        echo "   sudo ufw allow from 192.168.0.0/16 to any port 3389"
        echo "   sudo ufw allow from 192.168.0.0/16 to any port 5901"
        echo ""
        echo "2. Temporarily disable firewall for testing:"
        echo "   sudo ufw disable"
        echo ""
        echo "3. Reset and reconfigure:"
        echo "   sudo ufw --force reset"
    else
        print_error "UFW not installed"
        echo "Install with: sudo apt install ufw"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

run_comprehensive_diagnostic() {
    print_header "Comprehensive Diagnostic"
    echo ""
    print_status "Running complete system check..."
    echo ""
    
    # System info
    print_status "=== SYSTEM INFORMATION ==="
    echo "OS: $(lsb_release -ds 2>/dev/null)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    # Network
    print_status "=== NETWORK CONFIGURATION ==="
    local ip_address
    ip_address=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)
    echo "Primary IP: $ip_address"
    echo "Network interfaces:"
    ip addr show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/://'
    echo ""
    
    # Services
    print_status "=== SERVICE STATUS ==="
    services=("xrdp" "vncserver@1")
    for service in "${services[@]}"; do
        if systemctl is-installed "$service" &>/dev/null; then
            local status enabled
            status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
            echo "$service: $status ($enabled)"
        else
            echo "$service: not installed"
        fi
    done
    echo ""
    
    # Ports
    print_status "=== PORT STATUS ==="
    ports=("3389" "5901")
    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            echo "Port $port: LISTENING"
        else
            echo "Port $port: NOT LISTENING"
        fi
    done
    echo ""
    
    # Firewall
    print_status "=== FIREWALL STATUS ==="
    if command -v ufw &> /dev/null; then
        sudo ufw status | head -5
        echo ""
        sudo ufw status | grep -E "(3389|5901)" || echo "No remote desktop rules"
    else
        echo "UFW not installed"
    fi
    echo ""
    
    # Recent errors
    print_status "=== RECENT ERRORS ==="
    echo "XRDP errors (last 5):"
    sudo journalctl -u xrdp --no-pager -n 5 -p err 2>/dev/null || echo "No XRDP errors or service not installed"
    echo ""
    echo "VNC errors (last 5):"
    sudo journalctl -u vncserver@1 --no-pager -n 5 -p err 2>/dev/null || echo "No VNC errors or service not installed"
    echo ""
    
    print_status "=== DIAGNOSTIC COMPLETE ==="
    read -p "Press Enter to continue..."
}

restart_all_services() {
    print_header "Restart All Remote Desktop Services"
    echo ""
    
    read -p "This will restart XRDP and VNC services. Continue? [y/N]: " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        print_status "Restarting services..."
        
        if systemctl is-installed xrdp &>/dev/null; then
            sudo systemctl restart xrdp
            print_status "XRDP restarted"
        fi
        
        if systemctl is-installed vncserver@1 &>/dev/null; then
            sudo systemctl restart vncserver@1
            print_status "VNC restarted"
        fi
        
        print_status "All services restarted successfully"
    else
        print_status "Operation cancelled"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to uninstall remote desktop services
uninstall_remote_desktop() {
    print_header "Uninstalling Remote Desktop Services"
    
    echo "This will remove all remote desktop services and configurations."
    read -p "Are you sure you want to continue? [y/N]: " confirm
    
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
    read -p "Press Enter to continue..."
}

# Function to show comprehensive status
show_status() {
    print_header "Remote Desktop Status Report"
    echo ""
    
    # System Information
    print_status "=== SYSTEM INFORMATION ==="
    echo "Hostname: $(hostname)"
    echo "User: $USER"
    echo "Ubuntu Version: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    # Network Information
    print_status "=== NETWORK INFORMATION ==="
    local ip_address
    ip_address=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1 2>/dev/null || echo 'Unknown')
    echo "Primary IP Address: $ip_address"
    
    # Show all network interfaces
    echo "Network Interfaces:"
    ip addr show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/://'
    echo ""
    
    # Service Status
    print_status "=== SERVICE STATUS ==="
    
    # XRDP Status
    echo "XRDP Service:"
    if systemctl is-installed xrdp &>/dev/null; then
        if systemctl is-active --quiet xrdp; then
            echo -e "  Status: ${GREEN}Running${NC}"
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
        
        if systemctl is-enabled --quiet xrdp 2>/dev/null; then
            echo -e "  Autostart: ${GREEN}Enabled${NC}"
        else
            echo -e "  Autostart: ${RED}Disabled${NC}"
        fi
        
        echo "  Protocol: RDP"
        echo "  Default Port: 3389"
        echo "  Connection: $ip_address:3389"
    else
        echo -e "  Status: ${YELLOW}Not Installed${NC}"
    fi
    echo ""
    
    # VNC Status
    echo "VNC Service:"
    if systemctl is-installed vncserver@1 &>/dev/null || command -v vncserver &>/dev/null; then
        if systemctl is-active --quiet vncserver@1; then
            echo -e "  Status: ${GREEN}Running${NC}"
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
        
        if systemctl is-enabled --quiet vncserver@1 2>/dev/null; then
            echo -e "  Autostart: ${GREEN}Enabled${NC}"
        else
            echo -e "  Autostart: ${RED}Disabled${NC}"
        fi
        
        echo "  Protocol: VNC"
        echo "  Default Port: 5901"
        echo "  Connection: $ip_address:5901"
        
        # VNC Password status
        if [[ -f "$HOME/.vnc/passwd" ]]; then
            echo -e "  VNC Password: ${GREEN}Set${NC}"
        else
            echo -e "  VNC Password: ${RED}Not Set${NC}"
        fi
    else
        echo -e "  Status: ${YELLOW}Not Installed${NC}"
    fi
    echo ""
    
    # Firewall Status
    print_status "=== FIREWALL STATUS ==="
    if command -v ufw &> /dev/null; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -n 1)
        echo "UFW Status: $ufw_status"
        
        if sudo ufw status | grep -q "Status: active"; then
            echo ""
            echo "Active UFW Rules:"
            sudo ufw status numbered | grep -E "(3389|5901)" || echo "  No remote desktop rules found"
        fi
    else
        echo "UFW: Not installed"
    fi
    echo ""
    
    # Open Ports
    print_status "=== OPEN PORTS (Remote Desktop Related) ==="
    echo "Checking ports 3389 (RDP) and 5901 (VNC)..."
    
    if command -v ss &> /dev/null; then
        local rdp_port vnc_port
        rdp_port=$(ss -tlnp | grep ":3389 " || echo "")
        vnc_port=$(ss -tlnp | grep ":5901 " || echo "")
        
        if [[ -n "$rdp_port" ]]; then
            echo -e "  Port 3389 (RDP): ${GREEN}Open${NC}"
        else
            echo -e "  Port 3389 (RDP): ${RED}Closed${NC}"
        fi
        
        if [[ -n "$vnc_port" ]]; then
            echo -e "  Port 5901 (VNC): ${GREEN}Open${NC}"
        else
            echo -e "  Port 5901 (VNC): ${RED}Closed${NC}"
        fi
    else
        echo "  Cannot check ports (ss command not available)"
    fi
    echo ""
    
    # Connection Information
    print_status "=== CONNECTION INFORMATION ==="
    echo "Login Credentials:"
    echo "  Username: $USER"
    echo "  Password: [Use your Ubuntu login password for XRDP]"
    
    if [[ -f "$HOME/.vnc/passwd" ]]; then
        echo "  VNC Password: [Configured separately during VNC setup]"
    fi
    echo ""
    
    echo "Mobile Apps:"
    echo "  For RDP: Microsoft Remote Desktop"
    echo "  For VNC: VNC Viewer by RealVNC"
    echo ""
    
    # Security Information
    print_status "=== SECURITY INFORMATION ==="
    local ip_range
    ip_range=$(ip route | grep "$(ip route get 1.1.1.1 | awk '{print $5}' | head -n 1)" | grep -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.' | head -n 1 | awk '{print $1}' 2>/dev/null || echo 'Unknown')
    
    if [[ -n "$ip_range" && "$ip_range" != "Unknown" ]]; then
        echo "Local Network Range: $ip_range"
        echo "Security: Configured for local network access only"
    else
        print_warning "Network range detection failed - manual security review recommended"
    fi
    
    echo ""
    print_status "=== END OF STATUS REPORT ==="
    echo ""
    read -p "Press Enter to continue..."
}

# Main installation menu
main_menu() {
    while true; do
        clear
        print_header "$SCRIPT_NAME"
        echo ""
        echo "Please select an option:"
        echo "1) Install XRDP only (RDP protocol - works with Microsoft Remote Desktop)"
        echo "2) Install VNC only (VNC protocol - works with VNC Viewer)"
        echo "3) Install both XRDP and VNC"
        echo "4) Show status and connection information"
        echo "5) Firewall management and security hardening"
        echo "6) Troubleshooter"
        echo "7) Uninstall remote desktop services"
        echo "8) Exit"
        echo ""
        
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            1)
                install_xrdp
                prompt_security_hardening
                show_network_info
                show_mobile_apps
                print_header "XRDP installation completed successfully!"
                read -p "Press Enter to continue..."
                ;;
            2)
                install_vnc
                prompt_security_hardening
                show_network_info
                show_mobile_apps
                print_header "VNC installation completed successfully!"
                read -p "Press Enter to continue..."
                ;;
            3)
                install_xrdp
                install_vnc
                prompt_security_hardening
                show_network_info
                show_mobile_apps
                print_header "Both XRDP and VNC installation completed successfully!"
                read -p "Press Enter to continue..."
                ;;
            4)
                show_status
                ;;
            5)
                firewall_management
                ;;
            6)
                troubleshooter
                ;;
            7)
                uninstall_remote_desktop
                ;;
            8)
                print_status "Exiting $SCRIPT_NAME"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to prompt for security hardening after installation
prompt_security_hardening() {
    echo ""
    print_header "Security Configuration"
    echo ""
    print_warning "Your remote desktop services are now accessible to anyone who can reach your network."
    echo "It's strongly recommended to apply security hardening."
    echo ""
    read -p "Apply security hardening now? [Y/n]: " security_choice
    
    if [[ $security_choice != "n" && $security_choice != "N" ]]; then
        security_hardening
    else
        print_warning "Security hardening skipped. Your services may be vulnerable!"
        print_status "You can apply hardening later from the firewall management menu."
    fi
}

# Main execution function
main() {
    # Initialize log file
    echo "=== Remote Desktop Setup Log - $(date) ===" > "$LOG_FILE"
    
    # Perform checks
    check_root
    check_ubuntu
    
    # Check if this is first run or returning to menu
    if [[ "${1:-}" != "--menu-only" ]]; then
        # Update system on first run
        read -p "Update system packages before proceeding? (recommended) [Y/n]: " update_choice
        if [[ $update_choice != "n" && $update_choice != "N" ]]; then
            update_system
        fi
    fi
    
    # Show main menu
    main_menu
}

# Trap to handle script interruption
trap 'print_error "Script interrupted by user"; exit 130' INT

# Run main function
main "$@"
