#!/usr/bin/env bash

# SSH Key Generator Script
# Generates SSH keys with user prompts and configures ssh-agent

set -euo pipefail

# Configuration Variables
readonly DEFAULT_KEY_TYPE="ed25519"
readonly DEFAULT_RSA_BITS="4096"
readonly DEFAULT_KEY_DIR="$HOME/.ssh"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SSH_CONFIG="$HOME/.ssh/config"
readonly BASHRC="$HOME/.bashrc"
readonly PROFILE="$HOME/.profile"

# Colours for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Colour

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Validation functions
validate_key_type() {
    local key_type="$1"
    case "$key_type" in
        rsa|dsa|ecdsa|ed25519)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_rsa_bits() {
    local bits="$1"
    if [[ "$bits" =~ ^[0-9]+$ ]] && [ "$bits" -ge 2048 ]; then
        return 0
    fi
    return 1
}

# Check prerequisites
check_prerequisites() {
    command -v ssh-keygen >/dev/null 2>&1 || error_exit "ssh-keygen not found. Please install OpenSSH client."
    command -v ssh-agent >/dev/null 2>&1 || error_exit "ssh-agent not found. Please install OpenSSH client."
    
    if [[ ! -d "$DEFAULT_KEY_DIR" ]]; then
        log_info "Creating SSH directory: $DEFAULT_KEY_DIR"
        mkdir -p "$DEFAULT_KEY_DIR"
        chmod 700 "$DEFAULT_KEY_DIR"
    fi
}

# Get user input with validation
get_key_type() {
    local key_type
    while true; do
        echo -n "Enter key type (rsa/dsa/ecdsa/ed25519) [default: $DEFAULT_KEY_TYPE]: "
        read -r key_type
        key_type="${key_type:-$DEFAULT_KEY_TYPE}"
        
        if validate_key_type "$key_type"; then
            echo "$key_type"
            return 0
        fi
        log_error "Invalid key type. Please choose: rsa, dsa, ecdsa, or ed25519"
    done
}

get_key_bits() {
    local key_type="$1"
    local bits
    
    if [[ "$key_type" != "rsa" ]]; then
        echo ""
        return 0
    fi
    
    while true; do
        echo -n "Enter RSA key size in bits [default: $DEFAULT_RSA_BITS]: "
        read -r bits
        bits="${bits:-$DEFAULT_RSA_BITS}"
        
        if validate_rsa_bits "$bits"; then
            echo "$bits"
            return 0
        fi
        log_error "Invalid key size. Minimum is 2048 bits for RSA keys."
    done
}

get_key_filename() {
    local key_type="$1"
    local filename
    local default_name="id_${key_type}"
    
    echo -n "Enter filename for the key [default: $default_name]: "
    read -r filename
    filename="${filename:-$default_name}"
    
    # Ensure full path
    if [[ "$filename" != /* ]]; then
        filename="$DEFAULT_KEY_DIR/$filename"
    fi
    
    # Check if file exists
    if [[ -f "$filename" || -f "${filename}.pub" ]]; then
        log_warning "Key files already exist: $filename"
        echo -n "Overwrite existing keys? (y/N): "
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            log_info "Please choose a different filename."
            get_key_filename "$key_type"
            return
        fi
    fi
    
    echo "$filename"
}

get_comment() {
    local comment
    local default_comment="$(whoami)@$(hostname) $(date +'%Y-%m-%d')"
    
    echo -n "Enter comment for the key [default: $default_comment]: "
    read -r comment
    echo "${comment:-$default_comment}"
}

# Generate SSH key
generate_key() {
    local key_type="$1"
    local key_bits="$2"
    local filename="$3"
    local comment="$4"
    
    local ssh_keygen_cmd="ssh-keygen -t $key_type"
    
    if [[ -n "$key_bits" && "$key_type" == "rsa" ]]; then
        ssh_keygen_cmd="$ssh_keygen_cmd -b $key_bits"
    fi
    
    ssh_keygen_cmd="$ssh_keygen_cmd -f $filename -C '$comment'"
    
    log_info "Generating SSH key..."
    log_info "Command: $ssh_keygen_cmd"
    
    if eval "$ssh_keygen_cmd"; then
        log_success "SSH key generated successfully:"
        log_info "Private key: $filename"
        log_info "Public key: ${filename}.pub"
        
        # Set proper permissions
        chmod 600 "$filename"
        chmod 644 "${filename}.pub"
        
        return 0
    else
        error_exit "Failed to generate SSH key"
    fi
}

# Configure ssh-agent to start on boot
configure_ssh_agent() {
    local shell_config
    
    # Determine which shell config to use
    if [[ -f "$BASHRC" ]]; then
        shell_config="$BASHRC"
    elif [[ -f "$PROFILE" ]]; then
        shell_config="$PROFILE"
    else
        log_warning "No suitable shell configuration file found. Creating ~/.profile"
        touch "$PROFILE"
        shell_config="$PROFILE"
    fi
    
    # Check if ssh-agent configuration already exists
    if grep -q "ssh-agent" "$shell_config" 2>/dev/null; then
        log_info "SSH agent configuration already exists in $shell_config"
        return 0
    fi
    
    log_info "Adding SSH agent configuration to $shell_config"
    
    cat >> "$shell_config" << 'EOF'

# SSH Agent Configuration
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Check for a currently running instance of the agent
    RUNNING_AGENT="$(ps -ax | grep 'ssh-agent -s' | grep -v grep | wc -l | tr -d '[:space:]')"
    if [ "$RUNNING_AGENT" = "0" ]; then
        # Launch a new instance of the agent
        ssh-agent -s &> "$HOME/.ssh/ssh-agent"
    fi
    eval "$(cat "$HOME/.ssh/ssh-agent")"
fi
EOF
    
    log_success "SSH agent will now start automatically on login"
}

# Add key to ssh-agent
add_key_to_agent() {
    local filename="$1"
    
    # Start ssh-agent if not running
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        log_info "Starting ssh-agent..."
        eval "$(ssh-agent -s)"
    fi
    
    log_info "Adding key to ssh-agent..."
    if ssh-add "$filename"; then
        log_success "Key added to ssh-agent successfully"
    else
        log_warning "Failed to add key to ssh-agent. You can add it manually later with: ssh-add $filename"
    fi
}

# Display public key
show_public_key() {
    local filename="$1"
    
    echo
    log_success "Your public key (copy this to servers/services):"
    echo
    cat "${filename}.pub"
    echo
}

# Main function
main() {
    log_info "SSH Key Generator"
    echo
    
    check_prerequisites
    
    local key_type
    local key_bits
    local filename
    local comment
    
    key_type=$(get_key_type)
    key_bits=$(get_key_bits "$key_type")
    filename=$(get_key_filename "$key_type")
    comment=$(get_comment)
    
    echo
    log_info "Configuration Summary:"
    log_info "Key Type: $key_type"
    [[ -n "$key_bits" ]] && log_info "Key Size: $key_bits bits"
    log_info "Filename: $filename"
    log_info "Comment: $comment"
    echo
    
    echo -n "Generate key with these settings? (Y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_info "Key generation cancelled"
        exit 0
    fi
    
    generate_key "$key_type" "$key_bits" "$filename" "$comment"
    configure_ssh_agent
    add_key_to_agent "$filename"
    show_public_key "$filename"
    
    log_success "SSH key setup completed successfully!"
    log_info "Remember to add your public key to remote servers/services"
    log_info "Restart your shell or run 'source ~/.bashrc' to load ssh-agent"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
