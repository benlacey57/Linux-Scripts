#!/usr/bin/env bash

#==============================================================================
# rsync-manager - Intelligent rsync wrapper with progress tracking and resume
#==============================================================================
# Author: Ben (AcousticHigh)
# Description: Production-ready rsync wrapper with automatic network detection,
#              compression optimisation, resume capability, and dry-run preview
#==============================================================================

set -euo pipefail  # Exit on error, undefined variables, pipe failures

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
readonly SCRIPT_NAME="rsync-manager"
readonly VERSION="1.0.0"
readonly LOG_DIR="${HOME}/.rsync"
readonly LOG_FILE="${LOG_DIR}/transfers.log"
readonly STATE_DIR="${LOG_DIR}/state"
readonly CONFIG_FILE="${LOG_DIR}/config"

# Default rsync options
readonly DEFAULT_LOCAL_OPTS="-avh --info=progress2 --info=name0"
readonly DEFAULT_NETWORK_OPTS="-avhz --info=progress2 --info=name0 --partial --compress-level=6"

# Colour codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No colour

#------------------------------------------------------------------------------
# Help Function
#------------------------------------------------------------------------------
show_help() {
    cat << EOF
${CYAN}${SCRIPT_NAME}${NC} v${VERSION}
Intelligent rsync wrapper with automatic optimisation and resume capability

${GREEN}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS] [SOURCE] [DESTINATION]

${GREEN}OPTIONS:${NC}
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -n, --dry-run          Perform dry-run only (no confirmation prompt)
    -d, --delete           Delete files in destination not in source (mirror mode)
    -b, --bandwidth LIMIT   Limit bandwidth in KB/s (e.g., 5000 for 5MB/s)
    -e, --exclude PATTERN   Exclude files matching pattern (can be used multiple times)
    -r, --resume           Resume from last transfer (uses saved state)
    --no-compress          Disable compression even for network transfers
    --stats                Show detailed statistics after transfer
    --archive              Create tar.gz archive before transfer (for many small files)

${GREEN}ARGUMENTS:${NC}
    SOURCE                 Source directory (default: current directory)
    DESTINATION            Destination directory or remote path (user@host:/path)

${GREEN}EXAMPLES:${NC}
    # Interactive mode (prompts for source/destination)
    ${SCRIPT_NAME}

    # Copy current directory to remote server
    ${SCRIPT_NAME} . user@server.com:/backup/

    # Copy with bandwidth limit
    ${SCRIPT_NAME} --bandwidth 5000 /data/ user@server.com:/backup/

    # Mirror directories (delete extra files in destination)
    ${SCRIPT_NAME} --delete /source/ /destination/

    # Resume previous transfer
    ${SCRIPT_NAME} --resume

    # Exclude patterns
    ${SCRIPT_NAME} --exclude "*.log" --exclude "node_modules" /source/ /dest/

    # Archive many small files before transfer
    ${SCRIPT_NAME} --archive /project/ user@server.com:/backup/

${GREEN}REMOTE PATHS:${NC}
    Network transfers are automatically detected by the format: user@host:/path
    Compression is automatically enabled for network transfers.

${GREEN}LOGS:${NC}
    Transfer logs: ${LOG_FILE}
    State files:   ${STATE_DIR}/

${GREEN}RESUME CAPABILITY:${NC}
    The script saves transfer state automatically. Use --resume to continue
    an interrupted transfer, or re-run with the same source and destination.

EOF
}

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------
setup_logging() {
    mkdir -p "${LOG_DIR}" "${STATE_DIR}"
    
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}"
    fi
    
    log_info "=== Session started: $(date '+%Y-%m-%d %H:%M:%S') ==="
}

log_info() {
    local message="$1"
    echo -e "${CYAN}[INFO]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${message}" >> "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] ${message}" >> "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] ${message}" >> "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${message}" >> "${LOG_FILE}"
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------
validate_source() {
    local source="$1"
    
    # Check if it's a remote path
    if [[ "${source}" =~ ^[^@]+@[^:]+:.+ ]]; then
        log_info "Source is remote: ${source}"
        return 0
    fi
    
    # Local path validation
    if [[ ! -d "${source}" ]]; then
        log_error "Source directory does not exist: ${source}"
        return 1
    fi
    
    if [[ ! -r "${source}" ]]; then
        log_error "Source directory is not readable: ${source}"
        return 1
    fi
    
    log_success "Source directory validated: ${source}"
    return 0
}

validate_destination() {
    local destination="$1"
    
    # Check if it's a remote path
    if [[ "${destination}" =~ ^[^@]+@[^:]+:.+ ]]; then
        log_info "Destination is remote: ${destination}"
        # Extract host for connectivity check
        local host=$(echo "${destination}" | sed 's/^[^@]*@\([^:]*\):.*$/\1/')
        check_remote_connectivity "${host}"
        return $?
    fi
    
    # Local path validation
    local dest_parent=$(dirname "${destination}")
    
    if [[ ! -d "${dest_parent}" ]]; then
        log_warning "Destination parent directory does not exist: ${dest_parent}"
        read -p "Create parent directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "${dest_parent}" || {
                log_error "Failed to create destination directory"
                return 1
            }
            log_success "Created destination directory: ${dest_parent}"
        else
            return 1
        fi
    fi
    
    log_success "Destination validated: ${destination}"
    return 0
}

check_remote_connectivity() {
    local host="$1"
    
    log_info "Checking connectivity to ${host}..."
    
    if ! ping -c 1 -W 2 "${host}" &> /dev/null; then
        log_warning "Cannot ping ${host}, but SSH might still work"
    fi
    
    # Try SSH connection
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${host}" true 2>/dev/null; then
        log_success "SSH connection to ${host} successful"
        return 0
    else
        log_warning "SSH connection test failed. Transfer may fail without proper SSH keys."
        return 0  # Don't fail, as password auth might work
    fi
}

is_network_transfer() {
    local source="$1"
    local destination="$2"
    
    if [[ "${source}" =~ ^[^@]+@[^:]+:.+ ]] || [[ "${destination}" =~ ^[^@]+@[^:]+:.+ ]]; then
        return 0  # True
    fi
    return 1  # False
}

#------------------------------------------------------------------------------
# State Management for Resume Capability
#------------------------------------------------------------------------------
save_transfer_state() {
    local source="$1"
    local destination="$2"
    local state_file="${STATE_DIR}/last_transfer"
    
    cat > "${state_file}" << EOF
SOURCE=${source}
DESTINATION=${destination}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    log_info "Transfer state saved"
}

load_transfer_state() {
    local state_file="${STATE_DIR}/last_transfer"
    
    if [[ ! -f "${state_file}" ]]; then
        log_error "No previous transfer state found"
        return 1
    fi
    
    source "${state_file}"
    
    if [[ -z "${SOURCE:-}" ]] || [[ -z "${DESTINATION:-}" ]]; then
        log_error "Invalid state file"
        return 1
    fi
    
    log_info "Loaded previous transfer:"
    log_info "  Source:      ${SOURCE}"
    log_info "  Destination: ${DESTINATION}"
    log_info "  Last run:    ${TIMESTAMP}"
    
    return 0
}

#------------------------------------------------------------------------------
# Size Calculation and Analysis
#------------------------------------------------------------------------------
calculate_directory_size() {
    local path="$1"
    
    if [[ "${path}" =~ ^[^@]+@[^:]+:.+ ]]; then
        # Remote path - use ssh to calculate
        local user_host=$(echo "${path}" | sed 's/:.*$//')
        local remote_path=$(echo "${path}" | sed 's/^[^:]*://')
        
        ssh "${user_host}" "du -sb '${remote_path}' 2>/dev/null | cut -f1" || echo "0"
    else
        # Local path
        du -sb "${path}" 2>/dev/null | cut -f1 || echo "0"
    fi
}

count_files() {
    local path="$1"
    
    if [[ "${path}" =~ ^[^@]+@[^:]+:.+ ]]; then
        # Remote path
        local user_host=$(echo "${path}" | sed 's/:.*$//')
        local remote_path=$(echo "${path}" | sed 's/^[^:]*://')
        
        ssh "${user_host}" "find '${remote_path}' -type f 2>/dev/null | wc -l" || echo "0"
    else
        # Local path
        find "${path}" -type f 2>/dev/null | wc -l || echo "0"
    fi
}

format_bytes() {
    local bytes="$1"
    
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        echo "$(( bytes / 1024 )) KB"
    elif (( bytes < 1073741824 )); then
        echo "$(( bytes / 1048576 )) MB"
    else
        echo "$(( bytes / 1073741824 )) GB"
    fi
}

#------------------------------------------------------------------------------
# Archive Creation (for many small files)
#------------------------------------------------------------------------------
should_create_archive() {
    local file_count="$1"
    local total_size="$2"
    
    # If more than 1000 files and average file size < 100KB
    if (( file_count > 1000 )); then
        local avg_size=$(( total_size / file_count ))
        if (( avg_size < 102400 )); then  # 100KB
            return 0  # True - should archive
        fi
    fi
    
    return 1  # False
}

create_archive() {
    local source="$1"
    local archive_name="rsync-archive-$(date +%Y%m%d-%H%M%S).tar.gz"
    local archive_path="${LOG_DIR}/${archive_name}"
    
    log_info "Creating archive: ${archive_name}"
    log_info "This may take a while for large directories..."
    
    tar -czf "${archive_path}" -C "$(dirname "${source}")" "$(basename "${source}")" 2>&1 | \
        tee -a "${LOG_FILE}" || {
        log_error "Archive creation failed"
        return 1
    }
    
    log_success "Archive created: ${archive_path}"
    echo "${archive_path}"
}

#------------------------------------------------------------------------------
# Dry Run and Summary
#------------------------------------------------------------------------------
perform_dry_run() {
    local source="$1"
    local destination="$2"
    local rsync_opts="$3"
    
    log_info "Performing dry-run analysis..."
    echo ""
    
    # Add dry-run and stats flags
    local dry_run_opts="${rsync_opts} --dry-run --stats"
    
    # Capture dry-run output
    local dry_run_output
    dry_run_output=$(rsync ${dry_run_opts} "${source}" "${destination}" 2>&1)
    
    # Parse statistics
    local files_transferred=$(echo "${dry_run_output}" | grep -E "Number of.*files transferred" | awk '{print $NF}' || echo "0")
    local total_size=$(echo "${dry_run_output}" | grep -E "Total file size" | awk '{print $4}' || echo "0")
    
    # Display summary
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                    ${CYAN}TRANSFER SUMMARY${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC} %-25s ${GREEN}%-30s${NC} ${BLUE}║${NC}\n" "Source:" "${source}"
    printf "${BLUE}║${NC} %-25s ${GREEN}%-30s${NC} ${BLUE}║${NC}\n" "Destination:" "${destination}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC} %-25s ${YELLOW}%-30s${NC} ${BLUE}║${NC}\n" "Files to transfer:" "${files_transferred}"
    printf "${BLUE}║${NC} %-25s ${YELLOW}%-30s${NC} ${BLUE}║${NC}\n" "Total size:" "$(format_bytes ${total_size})"
    
    if is_network_transfer "${source}" "${destination}"; then
        printf "${BLUE}║${NC} %-25s ${CYAN}%-30s${NC} ${BLUE}║${NC}\n" "Transfer type:" "Network (compressed)"
    else
        printf "${BLUE}║${NC} %-25s ${CYAN}%-30s${NC} ${BLUE}║${NC}\n" "Transfer type:" "Local (uncompressed)"
    fi
    
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC} %-56s ${BLUE}║${NC}\n" "rsync options: ${rsync_opts}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show detailed file list if requested
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        echo -e "${CYAN}Files to be transferred:${NC}"
        echo "${dry_run_output}" | grep -E "^\w" | head -20
        echo ""
    fi
}

confirm_transfer() {
    if [[ "${DRY_RUN_ONLY:-0}" == "1" ]]; then
        log_info "Dry-run only mode - exiting without transfer"
        return 1
    fi
    
    echo -e "${YELLOW}Proceed with transfer?${NC} (y/N): "
    read -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Transfer cancelled by user"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Main Transfer Function
#------------------------------------------------------------------------------
execute_transfer() {
    local source="$1"
    local destination="$2"
    local rsync_opts="$3"
    
    log_info "Starting transfer..."
    echo ""
    
    local start_time=$(date +%s)
    
    # Execute rsync with options
    if rsync ${rsync_opts} "${source}" "${destination}" 2>&1 | tee -a "${LOG_FILE}"; then
        local end_time=$(date +%s)
        local duration=$(( end_time - start_time ))
        
        echo ""
        log_success "Transfer completed successfully"
        log_info "Duration: ${duration} seconds"
        
        # Save state for resume capability
        save_transfer_state "${source}" "${destination}"
        
        return 0
    else
        local exit_code=$?
        log_error "Transfer failed with exit code: ${exit_code}"
        return ${exit_code}
    fi
}

#------------------------------------------------------------------------------
# Build rsync Options
#------------------------------------------------------------------------------
build_rsync_options() {
    local source="$1"
    local destination="$2"
    local opts=""
    
    # Base options depend on transfer type
    if is_network_transfer "${source}" "${destination}"; then
        if [[ "${NO_COMPRESS:-0}" == "1" ]]; then
            opts="${DEFAULT_LOCAL_OPTS}"
            log_info "Network transfer with compression disabled"
        else
            opts="${DEFAULT_NETWORK_OPTS}"
            log_info "Network transfer with compression enabled"
        fi
    else
        opts="${DEFAULT_LOCAL_OPTS}"
        log_info "Local transfer detected"
    fi
    
    # Add delete flag if requested
    if [[ "${DELETE_MODE:-0}" == "1" ]]; then
        opts="${opts} --delete"
        log_warning "Delete mode enabled - files in destination not in source will be removed"
    fi
    
    # Add bandwidth limit if specified
    if [[ -n "${BANDWIDTH_LIMIT:-}" ]]; then
        opts="${opts} --bwlimit=${BANDWIDTH_LIMIT}"
        log_info "Bandwidth limited to ${BANDWIDTH_LIMIT} KB/s"
    fi
    
    # Add exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]:-}"; do
        opts="${opts} --exclude='${pattern}'"
        log_info "Excluding pattern: ${pattern}"
    done
    
    # Add stats if requested
    if [[ "${SHOW_STATS:-0}" == "1" ]]; then
        opts="${opts} --stats"
    fi
    
    echo "${opts}"
}

#------------------------------------------------------------------------------
# Interactive Prompts
#------------------------------------------------------------------------------
prompt_for_paths() {
    local default_source="${PWD}"
    
    echo -e "${CYAN}Enter source directory${NC} (default: ${default_source}): "
    read -r source_input
    SOURCE="${source_input:-${default_source}}"
    
    # Ensure trailing slash for directory sync
    if [[ ! "${SOURCE}" =~ /$ ]] && [[ ! "${SOURCE}" =~ ^[^@]+@[^:]+:.+ ]]; then
        SOURCE="${SOURCE}/"
    fi
    
    echo -e "${CYAN}Enter destination directory or remote path${NC} (user@host:/path): "
    read -r DESTINATION
    
    if [[ -z "${DESTINATION}" ]]; then
        log_error "Destination cannot be empty"
        return 1
    fi
    
    # Ensure trailing slash
    if [[ ! "${DESTINATION}" =~ /$ ]]; then
        DESTINATION="${DESTINATION}/"
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Main Function
#------------------------------------------------------------------------------
main() {
    setup_logging
    
    # Parse command-line arguments
    VERBOSE=0
    DRY_RUN_ONLY=0
    DELETE_MODE=0
    SHOW_STATS=0
    RESUME_MODE=0
    CREATE_ARCHIVE=0
    NO_COMPRESS=0
    BANDWIDTH_LIMIT=""
    declare -a EXCLUDE_PATTERNS=()
    SOURCE=""
    DESTINATION=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN_ONLY=1
                shift
                ;;
            -d|--delete)
                DELETE_MODE=1
                shift
                ;;
            -b|--bandwidth)
                BANDWIDTH_LIMIT="$2"
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            -r|--resume)
                RESUME_MODE=1
                shift
                ;;
            --stats)
                SHOW_STATS=1
                shift
                ;;
            --archive)
                CREATE_ARCHIVE=1
                shift
                ;;
            --no-compress)
                NO_COMPRESS=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "${SOURCE}" ]]; then
                    SOURCE="$1"
                elif [[ -z "${DESTINATION}" ]]; then
                    DESTINATION="$1"
                else
                    log_error "Too many arguments"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Handle resume mode
    if [[ "${RESUME_MODE}" == "1" ]]; then
        if ! load_transfer_state; then
            exit 1
        fi
    fi
    
    # Interactive mode if no arguments provided
    if [[ -z "${SOURCE}" ]] || [[ -z "${DESTINATION}" ]]; then
        if ! prompt_for_paths; then
            exit 1
        fi
    fi
    
    # Validate paths
    if ! validate_source "${SOURCE}"; then
        exit 1
    fi
    
    if ! validate_destination "${DESTINATION}"; then
        exit 1
    fi
    
    # Analyse source for archive decision
    if [[ "${CREATE_ARCHIVE}" == "1" ]]; then
        log_info "Analysing source for archiving..."
        local file_count=$(count_files "${SOURCE}")
        local dir_size=$(calculate_directory_size "${SOURCE}")
        
        log_info "Found ${file_count} files, total size: $(format_bytes ${dir_size})"
        
        if should_create_archive "${file_count}" "${dir_size}"; then
            log_info "Many small files detected - creating archive for efficient transfer"
            local archive_path=$(create_archive "${SOURCE}")
            if [[ -n "${archive_path}" ]]; then
                SOURCE="${archive_path}"
                log_info "Source updated to: ${SOURCE}"
            fi
        else
            log_info "Archive not beneficial for this transfer - proceeding normally"
        fi
    fi
    
    # Build rsync options
    local rsync_opts=$(build_rsync_options "${SOURCE}" "${DESTINATION}")
    
    # Perform dry-run and show summary
    perform_dry_run "${SOURCE}" "${DESTINATION}" "${rsync_opts}"
    
    # Confirm and execute
    if confirm_transfer; then
        execute_transfer "${SOURCE}" "${DESTINATION}" "${rsync_opts}"
        exit $?
    else
        exit 0
    fi
}

# Execute main function
main "$@"
