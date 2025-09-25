#!/bin/bash

# =============================================================================
# Comprehensive Linux Development Environment Setup Script
# =============================================================================
# Description: Automated installation with workflow enhancement tools
# Author: Development Team
# Version: 2.0.0
# =============================================================================

# Configuration Variables
readonly SCRIPT_NAME="dev-setup"
readonly SCRIPT_VERSION="2.0.0"
readonly LOG_FILE="logs/${SCRIPT_NAME}.log"
readonly TEMP_DIR="/tmp/${SCRIPT_NAME}"
readonly USER_HOME="${HOME}"
readonly NODE_VERSION="20"
readonly PHP_VERSION="8.2"
readonly PYTHON_VERSION="3.11"

# Feature flags
readonly INSTALL_DATABASE_TOOLS="${INSTALL_DATABASE_TOOLS:-true}"
readonly INSTALL_CLI_ENHANCEMENTS="${INSTALL_CLI_ENHANCEMENTS:-true}"
readonly INSTALL_SECURITY_TOOLS="${INSTALL_SECURITY_TOOLS:-true}"
readonly INSTALL_API_TOOLS="${INSTALL_API_TOOLS:-true}"

# Core VS Code Extensions
readonly VSCODE_EXTENSIONS=(
    "ms-vscode.vscode-typescript-next"
    "bradlc.vscode-tailwindcss"
    "ms-python.python"
    "ms-vscode.vscode-json"
    "esbenp.prettier-vscode"
    "formulahendry.auto-rename-tag"
    "christian-kohler.path-intellisense"
    "ms-vscode.vscode-eslint"
    "bmewburn.vscode-intelephense-client"
    "onecentlin.laravel-extension-pack"
    "ms-vscode-remote.remote-containers"
    "github.copilot"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode.remote-explorer"
    "ms-azuretools.vscode-docker"
    "hashicorp.terraform"
    "redhat.vscode-yaml"
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "streetsidesoftware.code-spell-checker"
    "gruntfuggly.todo-tree"
    "eamodio.gitlens"
    "formulahendry.code-runner"
    "rangav.vscode-thunder-client"
)

# Colour Codes for Output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Colour

# =============================================================================
# Utility Functions
# =============================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

print_step() {
    local step="$1"
    local message="$2"
    echo -e "\n${CYAN}[${step}]${NC} ${message}"
    log_message "INFO" "${step}: ${message}"
}

print_success() {
    local message="$1"
    echo -e "${GREEN}✓ ${message}${NC}"
    log_message "SUCCESS" "${message}"
}

print_error() {
    local message="$1"
    echo -e "${RED}✗ ${message}${NC}" >&2
    log_message "ERROR" "${message}"
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠ ${message}${NC}"
    log_message "WARNING" "${message}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons"
        exit 1
    fi
}

create_temp_dir() {
    if [[ ! -d "${TEMP_DIR}" ]]; then
        mkdir -p "${TEMP_DIR}" || {
            print_error "Failed to create temporary directory"
            exit 1
        }
    fi
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
        print_success "Cleaned up temporary files"
    fi
}

# =============================================================================
# Installation Functions
# =============================================================================

update_system() {
    print_step "1" "Updating system packages"
    
    sudo apt update && sudo apt upgrade -y || {
        print_error "Failed to update system packages"
        return 1
    }
    
    sudo apt install -y curl wget gpg software-properties-common apt-transport-https ca-certificates gnupg lsb-release || {
        print_error "Failed to install essential packages"
        return 1
    }
    
    print_success "System packages updated"
}

install_git() {
    print_step "2" "Installing Git with enhanced configuration"
    
    if command -v git &> /dev/null; then
        print_warning "Git already installed"
    else
        sudo apt install -y git || {
            print_error "Failed to install Git"
            return 1
        }
        print_success "Git installed successfully"
    fi
    
    # Configure Git with useful aliases and settings
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    
    # Better Git settings
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input
    git config --global core.safecrlf warn
    
    print_success "Git configuration enhanced with aliases and settings"
}

install_docker() {
    print_step "3" "Installing Docker and Docker Compose"
    
    if command -v docker &> /dev/null; then
        print_warning "Docker already installed"
    else
        # Remove old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || {
            print_error "Failed to add Docker GPG key"
            return 1
        }
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
            print_error "Failed to install Docker"
            return 1
        }
        
        # Add user to docker group
        sudo usermod -aG docker "${USER}"
        print_success "Docker installed successfully"
    fi
    
    # Install Docker Compose standalone
    if ! command -v docker-compose &> /dev/null; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null || {
            print_warning "Failed to install Docker Compose standalone"
        }
        sudo chmod +x /usr/local/bin/docker-compose 2>/dev/null
        print_success "Docker Compose standalone installed"
    fi
    
    print_warning "Please log out and back in for Docker group permissions to take effect"
}

install_vscode() {
    print_step "4" "Installing Visual Studio Code"
    
    if command -v code &> /dev/null; then
        print_warning "VS Code already installed"
    else
        # Add Microsoft GPG key and repository
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        
        sudo apt update
        sudo apt install -y code || {
            print_error "Failed to install VS Code"
            return 1
        }
        
        print_success "VS Code installed successfully"
    fi
    
    # Install extensions
    print_step "4a" "Installing VS Code extensions"
    for extension in "${VSCODE_EXTENSIONS[@]}"; do
        code --install-extension "${extension}" --force 2>/dev/null && \
            print_success "Installed extension: ${extension}" || \
            print_warning "Failed to install extension: ${extension}"
    done
}

install_nvm_node() {
    print_step "5" "Installing NVM and Node.js"
    
    if [[ -d "${USER_HOME}/.nvm" ]]; then
        print_warning "NVM already installed"
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash || {
            print_error "Failed to install NVM"
            return 1
        }
        
        print_success "NVM installed successfully"
    fi
    
    # Source NVM
    export NVM_DIR="${USER_HOME}/.nvm"
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
    [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
    
    # Install Node.js
    nvm install "${NODE_VERSION}" && nvm use "${NODE_VERSION}" && nvm alias default "${NODE_VERSION}" || {
        print_error "Failed to install Node.js"
        return 1
    }
    
    print_success "Node.js ${NODE_VERSION} installed successfully"
}

install_php() {
    print_step "6" "Installing PHP and Composer"
    
    # Add PHP repository
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    
    # Install PHP and common extensions
    sudo apt install -y "php${PHP_VERSION}" \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-common" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-zip" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-bcmath" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-sqlite3" || {
        print_error "Failed to install PHP"
        return 1
    }
    
    # Install Composer
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/tmp
        sudo mv /tmp/composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer || {
            print_error "Failed to install Composer"
            return 1
        }
    fi
    
    print_success "PHP ${PHP_VERSION} and Composer installed successfully"
}

install_laravel() {
    print_step "7" "Installing Laravel installer and PHP tools"
    
    composer global require laravel/installer || {
        print_error "Failed to install Laravel installer"
        return 1
    }
    
    # Install PHP code quality tools
    composer global require squizlabs/php_codesniffer friendsofphp/php-cs-fixer phpmd/phpmd 2>/dev/null || {
        print_warning "Some PHP code quality tools failed to install"
    }
    
    # Add Composer global bin to PATH if not already present
    if [[ ":$PATH:" != *":${USER_HOME}/.composer/vendor/bin:"* ]]; then
        echo 'export PATH="${HOME}/.composer/vendor/bin:$PATH"' >> "${USER_HOME}/.bashrc"
    fi
    
    print_success "Laravel installer and PHP tools installed successfully"
}

install_python() {
    print_step "8" "Installing Python and development tools"
    
    sudo apt install -y "python${PYTHON_VERSION}" \
        "python${PYTHON_VERSION}-pip" \
        "python${PYTHON_VERSION}-venv" \
        python3-dev \
        python3-setuptools || {
        print_error "Failed to install Python"
        return 1
    }
    
    # Install Python development and security tools
    pip3 install --user black flake8 mypy pylint bandit detect-secrets locust 2>/dev/null || {
        print_warning "Some Python tools failed to install"
    }
    
    print_success "Python ${PYTHON_VERSION} and development tools installed successfully"
}

install_modern_cli_tools() {
    if [[ "${INSTALL_CLI_ENHANCEMENTS}" != "true" ]]; then
        print_warning "Skipping CLI enhancements (disabled in config)"
        return 0
    fi
    
    print_step "9" "Installing modern CLI enhancement tools"
    
    # Modern alternatives to common CLI tools
    sudo apt install -y bat exa fd-find ripgrep fzf tree jq unzip || {
        print_warning "Some CLI tools failed to install"
    }
    
    # HTTPie for API testing
    sudo apt install -y httpie || print_warning "HTTPie installation failed"
    
    # The Silver Searcher
    sudo apt install -y silversearcher-ag || print_warning "Silver Searcher installation failed"
    
    # Shellcheck for bash script linting
    sudo apt install -y shellcheck || print_warning "Shellcheck installation failed"
    
    # Zoxide (smart cd command)
    curl -sS https://webinstall.dev/zoxide | bash 2>/dev/null || print_warning "Zoxide installation failed"
    
    # Starship prompt
    curl -sS https://starship.rs/install.sh | sh -s -- --yes 2>/dev/null || print_warning "Starship installation failed"
    
    print_success "Modern CLI tools installed"
}

install_database_tools() {
    if [[ "${INSTALL_DATABASE_TOOLS}" != "true" ]]; then
        print_warning "Skipping database tools (disabled in config)"
        return 0
    fi
    
    print_step "10" "Installing database management tools"
    
    # Database clients and tools
    sudo apt install -y sqlite3 sqlitebrowser mysql-client postgresql-client || {
        print_warning "Some database clients failed to install"
    }
    
    # Redis tools
    sudo apt install -y redis-tools || print_warning "Redis tools installation failed"
    
    # Advanced CLI tools for databases
    pip3 install --user mycli pgcli 2>/dev/null || print_warning "Database CLI tools installation failed"
    
    # DBeaver Community Edition via snap
    if command -v snap &> /dev/null; then
        sudo snap install dbeaver-ce 2>/dev/null || print_warning "DBeaver installation failed"
        sudo snap install beekeeper-studio 2>/dev/null || print_warning "Beekeeper Studio installation failed"
    fi
    
    print_success "Database tools installed"
}

install_api_development_tools() {
    if [[ "${INSTALL_API_TOOLS}" != "true" ]]; then
        print_warning "Skipping API development tools (disabled in config)"
        return 0
    fi
    
    print_step "11" "Installing API development and testing tools"
    
    # Postman via snap
    if command -v snap &> /dev/null; then
        sudo snap install postman 2>/dev/null || print_warning "Postman installation failed"
        sudo snap install insomnia 2>/dev/null || print_warning "Insomnia installation failed"
    fi
    
    # Global npm packages for API development and code quality
    npm install -g @stoplight/prism-cli swagger-codegen-cli graphql-cli eslint prettier audit-ci loadtest clinic 2>/dev/null || {
        print_warning "Some npm packages failed to install"
    }
    
    print_success "API development tools installed"
}

install_monitoring_tools() {
    print_step "12" "Installing system monitoring and performance tools"
    
    # Enhanced system monitoring
    sudo apt install -y btop iotop nethogs htop apache2-utils || {
        print_warning "Some monitoring tools failed to install"
    }
    
    # Tmux for terminal multiplexing
    sudo apt install -y tmux || print_warning "Tmux installation failed"
    
    print_success "Monitoring and performance tools installed"
}

install_security_tools() {
    if [[ "${INSTALL_SECURITY_TOOLS}" != "true" ]]; then
        print_warning "Skipping security tools (disabled in config)"
        return 0
    fi
    
    print_step "13" "Installing security analysis tools"
    
    # Network security tools
    sudo apt install -y nmap || print_warning "Nmap installation failed"
    
    # Let's Encrypt certbot
    sudo apt install -y certbot || print_warning "Certbot installation failed"
    
    # mkcert for local SSL certificates
    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" 2>/dev/null && {
        chmod +x mkcert-v*-linux-amd64
        sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert 2>/dev/null
        print_success "mkcert installed"
    } || print_warning "mkcert installation failed"
    
    # Security scanners via npm
    npm install -g git-secrets 2>/dev/null || print_warning "git-secrets installation failed"
    
    print_success "Security tools installed"
}

install_productivity_tools() {
    print_step "14" "Installing productivity and documentation tools"
    
    # File management and productivity utilities
    sudo apt install -y mc ranger pandoc vim nano build-essential || {
        print_warning "Some productivity tools failed to install"
    }
    
    # Flatpak for universal packages
    sudo apt install -y flatpak || print_warning "Flatpak installation failed"
    if command -v flatpak &> /dev/null; then
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null
    fi
    
    print_success "Productivity tools installed"
}

install_cli_tools() {
    print_step "15" "Installing CLI development tools"
    
    # GitHub CLI
    if ! command -v gh &> /dev/null; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || {
            print_warning "Failed to add GitHub CLI GPG key"
        }
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh || print_warning "Failed to install GitHub CLI"
    fi
    
    # Deployment CLI tools via npm
    npm install -g vercel netlify-cli 2>/dev/null || print_warning "Failed to install deployment CLI tools"
    
    # Kubernetes tools
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" 2>/dev/null && {
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        print_success "kubectl installed"
    } || print_warning "kubectl installation failed"
    
    # Helm
    curl https://baltocdn.com/helm/signing.asc | sudo apt-key add - 2>/dev/null
    sudo apt install -y helm 2>/dev/null || print_warning "Helm installation failed"
    
    # Terraform
    sudo apt install -y terraform 2>/dev/null || print_warning "Terraform installation failed"
    
    print_success "CLI development tools installation completed"
}

create_development_structure() {
    print_step "16" "Creating development directory structure"
    
    mkdir -p "${USER_HOME}/Development"/{projects,tools,scripts,docs}
    mkdir -p "${USER_HOME}/Development/projects"/{web,mobile,backend,frontend}
    mkdir -p "${USER_HOME}/.local/bin"
    
    # Add ~/.local/bin to PATH if not already present
    if [[ ":$PATH:" != *":${USER_HOME}/.local/bin:"* ]]; then
        echo 'export PATH="${HOME}/.local/bin:$PATH"' >> "${USER_HOME}/.bashrc"
    fi
    
    print_success "Development directory structure created"
}

# =============================================================================
# Main Installation Process
# =============================================================================

main() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Comprehensive Development Environment Setup"
    echo "  Version: ${SCRIPT_VERSION}"
    echo "=============================================="
    echo -e "${NC}"
    
    # Configuration summary
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Database Tools: ${INSTALL_DATABASE_TOOLS}"
    echo "  CLI Enhancements: ${INSTALL_CLI_ENHANCEMENTS}"
    echo "  Security Tools: ${INSTALL_SECURITY_TOOLS}"
    echo "  API Tools: ${INSTALL_API_TOOLS}"
    echo ""
    
    # Pre-installation checks
    check_roo
    create_temp_dir
    
    # Set up signal handling for cleanup
    trap cleanup EXIT
    
    # Start logging
    log_message "INFO" "Starting comprehensive installation process"
    
    # Run installation functions
    update_system || exit 1
    install_git || exit 1
    install_docker || exit 1
    install_vscode || exit 1
    install_nvm_node || exit 1
    install_php || exit 1
    install_laravel || exit 1
    install_python || exit 1
    install_modern_cli_tools
    install_database_tools
    install_api_development_tools
    install_monitoring_tools
    install_security_tools
    install_productivity_tools
    install_cli_tools
    create_development_structure
    
    echo -e "\n${GREEN}"
    echo "=============================================="
    echo "  Comprehensive Installation Complete!"
    echo "=============================================="
    echo -e "${NC}"
    
    print_success "All development tools and workflow enhancements have been installed"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Restart your terminal or run 'source ~/.bashrc'"
    echo "2. Log out and back in for Docker group permissions"
    echo "3. Configure your Git user details:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
    echo "4. Generate SSH key for GitHub:"
    echo "   ssh-keygen -t ed25519 -C 'your.email@example.com'"
    
    echo -e "\n${CYAN}Installed Tools Summary:${NC}"
    echo "• Core Development: Docker, VS Code, Git, Node.js, PHP, Python"
    echo "• Modern CLI Tools: bat, exa, fd, ripgrep, fzf, zoxide, starship"
    echo "• Database Management: mycli, pgcli, DBeaver, Beekeeper Studio"
    echo "• API Development: Postman, Insomnia, HTTPie, Thunder Client"
    echo "• Code Quality: ESLint, Prettier, PHP-CS-Fixer, Black, Shellcheck"
    echo "• System Monitoring: btop, iotop, nethogs, tmux"
    echo "• Security Tools: nmap, mkcert, certbot, detect-secrets"
    echo "• DevOps Tools: kubectl, helm, terraform"
    echo "• Productivity: pandoc, ranger, mc, flatpak"
    
    log_message "INFO" "Comprehensive installation process completed successfully"
}

# Run main function
main "$@"
