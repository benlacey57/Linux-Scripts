#!/bin/bash

# Conky System Manager
# Provides easy management interface for the Conky installation

set -euo pipefail

SCRIPT_DIR="$HOME/scripts/conky"
CONFIG_DIR="$HOME/.config/conky"
CONFIG_MANAGER="$SCRIPT_DIR/config_manager.sh"
MAIN_CONFIG="$CONFIG_DIR/conky.conf"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Display status
show_status() {
    echo -e "${CYAN}=== Conky Status ===${NC}"
    
    # Check if Conky is running
    if pgrep -f "conky.*conky.conf" > /dev/null; then
        echo -e "Status: ${GREEN}Running${NC}"
        echo -e "PID: $(pgrep -f 'conky.*conky.conf')"
    else
        echo -e "Status: ${RED}Stopped${NC}"
    fi
    
    # Configuration status
    if [[ -f "$MAIN_CONFIG" ]]; then
        echo -e "Config: ${GREEN}Found${NC} ($MAIN_CONFIG)"
    else
        echo -e "Config: ${RED}Missing${NC}"
    fi
    
    # Scripts status
    local python_scripts=(
        "github_stats.py"
        "docker_stats.py" 
        "website_monitor.py"
        "vpn_status.py"
        "enhanced_monitoring.py"
    )
    
    echo -e "\n${CYAN}=== Python Scripts ===${NC}"
    for script in "${python_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/python/$script" ]]; then
            echo -e "  ${GREEN}✓${NC} $script"
        else
            echo -e "  ${RED}✗${NC} $script (missing)"
        fi
    done
    
    # Cache status
    echo -e "\n${CYAN}=== Cache Files ===${NC}"
    local cache_dir="$SCRIPT_DIR/cache"
    if [[ -d "$cache_dir" ]]; then
        local cache_count=$(find "$cache_dir" -name "*.json" | wc -l)
        echo -e "Cache files: $cache_count"
        for cache_file in "$cache_dir"/*.json; do
            if [[ -f "$cache_file" ]]; then
                local age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
                local age_human
                if [[ $age -lt 60 ]]; then
                    age_human="${age}s"
                elif [[ $age -lt 3600 ]]; then
                    age_human="$((age / 60))m"
                else
                    age_human="$((age / 3600))h"
                fi
                echo -e "  $(basename "$cache_file"): ${age_human} old"
            fi
        done
    else
        echo -e "Cache directory: ${RED}Missing${NC}"
    fi
}

# Start Conky
start_conky() {
    if pgrep -f "conky.*conky.conf" > /dev/null; then
        echo -e "${YELLOW}Conky is already running${NC}"
        return 0
    fi
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        echo -e "${RED}Configuration file not found. Run install first.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Starting Conky...${NC}"
    nohup conky -c "$MAIN_CONFIG" > /dev/null 2>&1 &
    sleep 2
    
    if pgrep -f "conky.*conky.conf" > /dev/null; then
        echo -e "${GREEN}Conky started successfully${NC}"
    else
        echo -e "${RED}Failed to start Conky${NC}"
        return 1
    fi
}

# Stop Conky
stop_conky() {
    if ! pgrep -f "conky.*conky.conf" > /dev/null; then
        echo -e "${YELLOW}Conky is not running${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Stopping Conky...${NC}"
    killall conky 2>/dev/null || true
    sleep 1
    
    if ! pgrep -f "conky.*conky.conf" > /dev/null; then
        echo -e "${GREEN}Conky stopped successfully${NC}"
    else
        echo -e "${RED}Failed to stop Conky${NC}"
        return 1
    fi
}

# Restart Conky
restart_conky() {
    echo -e "${GREEN}Restarting Conky...${NC}"
    stop_conky
    sleep 1
    start_conky
}

# Test monitoring scripts
test_scripts() {
    echo -e "${CYAN}=== Testing Monitoring Scripts ===${NC}"
    
    local scripts=(
        "github_stats.py:30"
        "docker_stats.py:10" 
        "website_monitor.py:15"
        "vpn_status.py:5"
    )
    
    for script_info in "${scripts[@]}"; do
        local script="${script_info%:*}"
        local timeout="${script_info#*:}"
        local script_path="$SCRIPT_DIR/python/$script"
        
        echo -n -e "Testing ${script}... "
        
        if [[ ! -f "$script_path" ]]; then
            echo -e "${RED}Missing${NC}"
            continue
        fi
        
        if timeout "$timeout" python3 "$script_path" > /tmp/conky_test_output 2>&1; then
            local output=$(cat /tmp/conky_test_output)
            echo -e "${GREEN}OK${NC} - $output"
        else
            local output=$(cat /tmp/conky_test_output)
            echo -e "${RED}Failed${NC} - $output"
        fi
    done
    
    rm -f /tmp/conky_test_output
}

# Show logs
show_logs() {
    local log_type="${1:-install}"
    
    case "$log_type" in
        "install")
            local log_file="$SCRIPT_DIR/install.log"
            if [[ -f "$log_file" ]]; then
                echo -e "${CYAN}=== Installation Log ===${NC}"
                tail -20 "$log_file"
            else
                echo -e "${RED}Installation log not found${NC}"
            fi
            ;;
        "monitoring")
            local log_file="$SCRIPT_DIR/monitoring.log"
            if [[ -f "$log_file" ]]; then
                echo -e "${CYAN}=== Monitoring Log ===${NC}"
                tail -20 "$log_file"
            else
                echo -e "${RED}Monitoring log not found${NC}"
            fi
            ;;
        "system")
            echo -e "${CYAN}=== System Log (Conky) ===${NC}"
            journalctl --user -u conky --no-pager -n 20 || echo "No systemd logs found"
            ;;
        *)
            echo -e "${RED}Unknown log type: $log_type${NC}"
            echo "Available: install, monitoring, system"
            ;;
    esac
}

# Clean cache
clean_cache() {
    local cache_dir="$SCRIPT_DIR/cache"
    
    if [[ ! -d "$cache_dir" ]]; then
        echo -e "${YELLOW}Cache directory does not exist${NC}"
        return 0
    fi
    
    local cache_count=$(find "$cache_dir" -name "*.json" | wc -l)
    
    if [[ $cache_count -eq 0 ]]; then
        echo -e "${YELLOW}No cache files to clean${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Removing $cache_count cache files...${NC}"
    rm -f "$cache_dir"/*.json
    echo -e "${GREEN}Cache cleaned${NC}"
}

# Update configuration
update_config() {
    if [[ ! -f "$CONFIG_MANAGER" ]]; then
        echo -e "${RED}Configuration manager not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Rebuilding configuration...${NC}"
    "$CONFIG_MANAGER" rebuild
}

# Show help
show_help() {
    cat << EOF
${CYAN}Conky System Manager${NC}

${YELLOW}Usage:${NC} $0 [command]

${YELLOW}Commands:${NC}
  status      - Show system status and information
  start       - Start Conky
  stop        - Stop Conky
  restart     - Restart Conky
  test        - Test all monitoring scripts
  logs        - Show logs [install|monitoring|system]
  clean       - Clean cache files
  config      - Rebuild configuration
  modules     - Manage configuration modules
  help        - Show this help message

${YELLOW}Configuration Management:${NC}
  modules list            - List available modules
  modules enable <name>   - Enable a module
  modules disable <name>  - Disable a module

${YELLOW}Log Types:${NC}
  install     - Installation log
  monitoring  - Python monitoring scripts log
  system      - System/journald logs

${YELLOW}Examples:${NC}
  $0 status                    # Show current status
  $0 restart                   # Restart Conky
  $0 test                      # Test all scripts
  $0 logs monitoring           # Show monitoring logs
  $0 modules enable processes  # Enable processes module
  $0 clean                     # Clean cache files

EOF
}

# Main function
main() {
    case "${1:-status}" in
        "status")
            show_status
            ;;
        "start")
            start_conky
            ;;
        "stop")
            stop_conky
            ;;
        "restart")
            restart_conky
            ;;
        "test")
            test_scripts
            ;;
        "logs")
            show_logs "${2:-install}"
            ;;
        "clean")
            clean_cache
            ;;
        "config")
            update_config
            ;;
        "modules")
            if [[ -f "$CONFIG_MANAGER" ]]; then
                "$CONFIG_MANAGER" "${@:2}"
            else
                echo -e "${RED}Configuration manager not found${NC}"
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
