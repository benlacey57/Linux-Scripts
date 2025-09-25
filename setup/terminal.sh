#!/bin/bash

# =============================================================================
# Powerlevel10k & Terminal Development Environment Installer
# =============================================================================
# Description: Automated installation of Powerlevel10k theme with essential
# terminal improvements for development environments
# Author: Development Setup Script
# Version: 1.0.0
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="../logs/terminal-setup.log"

# Default installation paths
readonly ZSH_CUSTOM="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
readonly OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
readonly P10K_THEME_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"

# Repository URLs
readonly OH_MY_ZSH_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
readonly P10K_REPO="https://github.com/romkatv/powerlevel10k.git"
readonly ZSH_SYNTAX_REPO="https://github.com/zsh-users/zsh-syntax-highlighting.git"
readonly ZSH_AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"
readonly ZSH_COMPLETIONS_REPO="https://github.com/zsh-users/zsh-completions.git"

# Plugin directories
readonly ZSH_PLUGINS_DIR="${ZSH_CUSTOM}/plugins"
readonly SYNTAX_PLUGIN_DIR="${ZSH_PLUGINS_DIR}/zsh-syntax-highlighting"
readonly AUTOSUGGESTIONS_PLUGIN_DIR="${ZSH_PLUGINS_DIR}/zsh-autosuggestions"
readonly COMPLETIONS_PLUGIN_DIR="${ZSH_PLUGINS_DIR}/zsh-completions"

# Font URLs for Nerd Fonts (MesloLGS variants recommended by p10k)
readonly FONT_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
readonly FONTS=(
    "MesloLGS%20NF%20Regular.ttf"
    "MesloLGS%20NF%20Bold.ttf"
    "MesloLGS%20NF%20Italic.ttf"
    "MesloLGS%20NF%20Bold%20Italic.ttf"
)

# Colours for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Colour

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local response
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt (Y/n): " response
            response="${response:-y}"
        else
            read -p "$prompt (y/N): " response
            response="${response:-n}"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed"
        return 1
    fi
    return 0
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for essential commands
    for cmd in git curl zsh; do
        if ! check_command "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and run again"
        
        # Provide installation hints based on OS
        if command -v apt-get &> /dev/null; then
            log_info "Try: sudo apt-get update && sudo apt-get install ${missing_deps[*]}"
        elif command -v brew &> /dev/null; then
            log_info "Try: brew install ${missing_deps[*]}"
        elif command -v yum &> /dev/null; then
            log_info "Try: sudo yum install ${missing_deps[*]}"
        fi
        
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

install_oh_my_zsh() {
    if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        log_info "Oh My Zsh already installed at $OH_MY_ZSH_DIR"
        return 0
    fi
    
    log_info "Installing Oh My Zsh..."
    
    # Clone Oh My Zsh repository
    if git clone "$OH_MY_ZSH_REPO" "$OH_MY_ZSH_DIR" 2>/dev/null; then
        log_success "Oh My Zsh installed successfully"
    else
        log_error "Failed to install Oh My Zsh"
        return 1
    fi
    
    # Create custom directories
    mkdir -p "${ZSH_CUSTOM}/themes" "${ZSH_CUSTOM}/plugins"
}

install_powerlevel10k() {
    log_info "Installing Powerlevel10k theme..."
    
    if [[ -d "$P10K_THEME_DIR" ]]; then
        log_info "Powerlevel10k already exists. Updating..."
        cd "$P10K_THEME_DIR" && git pull origin master
    else
        if git clone --depth=1 "$P10K_REPO" "$P10K_THEME_DIR" 2>/dev/null; then
            log_success "Powerlevel10k installed successfully"
        else
            log_error "Failed to install Powerlevel10k"
            return 1
        fi
    fi
}

install_zsh_plugins() {
    log_info "Installing essential zsh plugins..."
    
    # Install zsh-syntax-highlighting
    if [[ ! -d "$SYNTAX_PLUGIN_DIR" ]]; then
        git clone "$ZSH_SYNTAX_REPO" "$SYNTAX_PLUGIN_DIR"
        log_success "zsh-syntax-highlighting installed"
    fi
    
    # Install zsh-autosuggestions
    if [[ ! -d "$AUTOSUGGESTIONS_PLUGIN_DIR" ]]; then
        git clone "$ZSH_AUTOSUGGESTIONS_REPO" "$AUTOSUGGESTIONS_PLUGIN_DIR"
        log_success "zsh-autosuggestions installed"
    fi
    
    # Install zsh-completions
    if [[ ! -d "$COMPLETIONS_PLUGIN_DIR" ]]; then
        git clone "$ZSH_COMPLETIONS_REPO" "$COMPLETIONS_PLUGIN_DIR"
        log_success "zsh-completions installed"
    fi
}

install_fonts() {
    log_info "Installing recommended fonts..."
    
    # Determine font directory based on OS
    local font_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        font_dir="$HOME/Library/Fonts"
    else
        font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"
    fi
    
    # Download and install fonts
    for font in "${FONTS[@]}"; do
        local font_file="${font//%20/ }"  # URL decode
        local font_path="$font_dir/$font_file"
        
        if [[ ! -f "$font_path" ]]; then
            if curl -fsSL "$FONT_BASE_URL/$font" -o "$font_path"; then
                log_success "Installed font: $font_file"
            else
                log_warning "Failed to download font: $font_file"
            fi
        else
            log_info "Font already exists: $font_file"
        fi
    done
    
    # Update font cache on Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v fc-cache &> /dev/null; then
        fc-cache -f -v "$font_dir" &> /dev/null
        log_success "Font cache updated"
    fi
}

configure_zshrc() {
    local zshrc="$HOME/.zshrc"
    
    log_info "Configuring .zshrc..."
    
    # Backup existing .zshrc
    backup_file "$zshrc"
    
    # Create new .zshrc configuration
    cat > "$zshrc" << 'EOF'
# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Update behaviour
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Plugins
plugins=(
    git
    docker
    docker-compose
    kubectl
    npm
    node
    python
    pip
    brew
    macos
    vscode
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-completions
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_GB.UTF-8
export EDITOR='code'

# Aliases for development
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias c='clear'
alias h='history'
alias j='jobs -l'
alias which='type -all'
alias du='du -kh'
alias df='df -kTh'

# Git aliases
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gc='git commit -v'
alias gca='git commit -v -a'
alias gcam='git commit -a -m'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gd='git diff'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gp='git push'
alias gst='git status'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dsp='docker system prune'

# Development aliases
alias py='python3'
alias pip='pip3'
alias serve='python3 -m http.server'
alias myip='curl http://ipecho.net/plain; echo'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'

# Enhanced ls colours
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLICOLOR=1
    export LSCOLORS=ExFxBxDxCxegedabagacad
else
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Load Powerlevel10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

    log_success ".zshrc configured with development-friendly settings"
}

# =============================================================================
# MAIN INSTALLATION ROUTINE
# =============================================================================

main() {
    log_info "Starting Powerlevel10k and terminal improvements installation"
    log_info "Log file: $LOG_FILE"
    
    # Check if running as root (not recommended)
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root is not recommended for this installation"
        if ! prompt_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    fi
    
    # Prerequisites check
    check_prerequisites
    
    # Check if zsh is the default shell
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        log_warning "zsh is not your default shell"
        if prompt_yes_no "Would you like to change your default shell to zsh?" "y"; then
            if chsh -s "$(which zsh)"; then
                log_success "Default shell changed to zsh"
                log_info "You'll need to restart your terminal or log out/in for the change to take effect"
            else
                log_error "Failed to change default shell"
            fi
        fi
    fi
    
    # Installation steps
    install_oh_my_zsh || exit 1
    install_powerlevel10k || exit 1
    install_zsh_plugins || exit 1
    install_fonts || exit 1
    configure_zshrc || exit 1
    
    log_success "Installation completed successfully!"
    
    # Post-installation instructions
    echo
    log_info "=== POST-INSTALLATION STEPS ==="
    log_info "1. Restart your terminal or run: exec zsh"
    log_info "2. Configure your terminal font to 'MesloLGS NF' (size 12-14 recommended)"
    log_info "3. Run 'p10k configure' to customise your prompt"
    log_info "4. The configuration has been saved to ~/.zshrc"
    echo
    
    if prompt_yes_no "Would you like to configure Powerlevel10k now?" "y"; then
        exec zsh -c "source ~/.zshrc && p10k configure"
    else
        log_info "You can run 'p10k configure' anytime to customise your prompt"
    fi
    
    log_info "Installation log saved to: $LOG_FILE"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $SCRIPT_NAME [OPTION]"
        echo "Install Powerlevel10k and terminal improvements for development"
        echo
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  -v, --version  Show version information"
        echo
        exit 0
        ;;
    -v|--version)
        echo "$SCRIPT_NAME version 1.0.0"
        exit 0
        ;;
    "")
        # No arguments, proceed with installation
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use '$SCRIPT_NAME --help' for usage information"
        exit 1
        ;;
esac

# Error handling
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Execute main function
main "$@"
