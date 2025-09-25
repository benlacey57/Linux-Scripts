#!/bin/bash

# Conky Installation and Configuration Script
# Author: System Administrator
# Description: Installs Conky with custom widgets, themes, and monitoring scripts

set -euo pipefail

# Configuration Variables
SCRIPT_DIR="$HOME/scripts/conky"
CONFIG_DIR="$HOME/.config/conky"
CACHE_DIR="$SCRIPT_DIR/cache"
LOG_FILE="$SCRIPT_DIR/install.log"
PYTHON_VENV="$SCRIPT_DIR/venv"

# Default configuration
GITHUB_USERNAME="benlacey57"
WEBSITES_TO_MONITOR=("https://benlacey.co.uk" "https://media-wolf.co.uk")
CHECK_INTERVAL=300  # 5 minutes
DOCKER_ENABLED=true
VPN_INTERFACE="tun0"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root for security reasons"
    fi
}

# Create necessary directories
create_directories() {
    log "Creating directory structure..."
    mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR" "$CACHE_DIR" "$SCRIPT_DIR/python" "$SCRIPT_DIR/configs"
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y conky-all python3 python3-pip python3-venv curl jq wget git
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y conky python3 python3-pip curl jq wget git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm conky python python-pip curl jq wget git
    else
        error_exit "Unsupported package manager. Please install conky, python3, pip, curl, jq, wget, and git manually."
    fi
}

# Setup Python virtual environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    
    python3 -m venv "$PYTHON_VENV"
    source "$PYTHON_VENV/bin/activate"
    
    pip install --upgrade pip
    pip install requests psutil docker
}

# Get GitHub username if not set
get_github_username() {
    if [[ -z "$GITHUB_USERNAME" ]]; then
        read -p "Enter your GitHub username (optional): " GITHUB_USERNAME
    fi
}

# Create configuration manager
create_config_manager() {
    log "Creating configuration manager..."
    
    # Configuration manager script will be created from artifact
    chmod +x "$SCRIPT_DIR/config_manager.sh"
}

# Create system manager
create_system_manager() {
    log "Creating system manager..."
    
    # System manager script will be created from artifact
    chmod +x "$SCRIPT_DIR/conky_manager.sh"
    
    # Create convenient symlink
    if [[ ! -f "$HOME/bin/conky-manager" ]]; then
        mkdir -p "$HOME/bin"
        ln -sf "$SCRIPT_DIR/conky_manager.sh" "$HOME/bin/conky-manager"
    fi
}

# Create main conky configuration using modular system
create_main_config() {
    log "Creating modular Conky configuration..."
    
    # Use configuration manager to build initial config
    "$SCRIPT_DIR/config_manager.sh" build
}

# Create Python scripts
create_python_scripts() {
    log "Creating Python monitoring scripts..."
    
    # Copy enhanced monitoring utilities
    create_enhanced_monitoring
    # Create individual wrapper scripts
    create_github_script
    create_docker_script
    create_website_monitor_script
    create_vpn_script
}

# Create enhanced monitoring utilities
create_enhanced_monitoring() {
    # The enhanced monitoring utilities will be created from the artifact
    log "Enhanced monitoring utilities created"
}

# GitHub statistics script
create_github_script() {
    cat > "$SCRIPT_DIR/python/github_stats.py" << EOF
#!/usr/bin/env python3
import sys
from pathlib import Path

# Add enhanced monitoring to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from enhanced_monitoring import main_github
    main_github("$GITHUB_USERNAME")
except ImportError:
    print("GitHub: Enhanced monitoring not available")
except Exception as e:
    print(f"GitHub: Error - {e}")
EOF
    chmod +x "$SCRIPT_DIR/python/github_stats.py"
}

# Create Docker statistics script  
create_docker_script() {
    cat > "$SCRIPT_DIR/python/docker_stats.py" << 'EOF'
#!/usr/bin/env python3
import sys
from pathlib import Path

# Add enhanced monitoring to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from enhanced_monitoring import main_docker
    main_docker()
except ImportError:
    print("Docker: Enhanced monitoring not available")
except Exception as e:
    print(f"Docker: Error - {e}")
EOF
    chmod +x "$SCRIPT_DIR/python/docker_stats.py"
}

# Create website monitor script
create_website_monitor_script() {
    # Convert bash array to Python list format
    websites_python=$(printf '"%s", ' "${WEBSITES_TO_MONITOR[@]}")
    websites_python="[${websites_python%, }]"
    
    cat > "$SCRIPT_DIR/python/website_monitor.py" << EOF
#!/usr/bin/env python3
import sys
from pathlib import Path

# Add enhanced monitoring to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from enhanced_monitoring import main_websites
    websites = ${websites_python}
    main_websites(websites)
except ImportError:
    print("Monitor: Enhanced monitoring not available")
except Exception as e:
    print(f"Monitor: Error - {e}")
EOF
    chmod +x "$SCRIPT_DIR/python/website_monitor.py"
}

# Create VPN status script
create_vpn_script() {
    cat > "$SCRIPT_DIR/python/vpn_status.py" << EOF
#!/usr/bin/env python3
import sys
from pathlib import Path

# Add enhanced monitoring to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from enhanced_monitoring import main_vpn
    main_vpn("$VPN_INTERFACE")
except ImportError:
    print("VPN: Enhanced monitoring not available")
except Exception as e:
    print(f"VPN: Error - {e}")
EOF
    chmod +x "$SCRIPT_DIR/python/vpn_status.py"
}

# Setup autostart
setup_autostart() {
    log "Setting up autostart..."
    
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/conky.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Comment=System monitoring widget
Exec=conky -c ~/.config/conky/conky.conf
Icon=conky
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
}

# Main installation process
main() {
    log "Starting Conky installation process..."
    
    check_root
    create_directories
    install_dependencies
    setup_python_env
    get_github_username
    create_config_manager
    create_system_manager
    create_main_config
    create_python_scripts
    setup_autostart
    
    log "Installation completed successfully!"
    echo -e "${GREEN}Conky installation complete!${NC}"
    echo -e "${BLUE}Configuration files: $CONFIG_DIR${NC}"
    echo -e "${BLUE}Scripts directory: $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}System manager: $SCRIPT_DIR/conky_manager.sh (or 'conky-manager')${NC}"
    echo -e "${YELLOW}Config manager: $SCRIPT_DIR/config_manager.sh${NC}"
    echo -e "${YELLOW}You can start Conky with: conky-manager start${NC}"
    echo -e "${YELLOW}Or log out and back in to start automatically${NC}"
}

# Run main function
main "$@"
