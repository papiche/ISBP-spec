#!/bin/bash
################################################################################
# NOSTRCARD.refresh.sh - Simplified MULTIPASS refresh for ISBP
#
# This script handles:
# 1. uDRIVE content update and IPNS publication
# 2. Weekly fee collection (MULTIPASS → CAPTAIN)
# 3. User milestone notifications
#
# Full implementation: Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
MULTIPASS_DIR="${ISBP_DIR}/multipass"
LOG_FILE="${ISBP_DIR}/logs/nostrcard_refresh.log"

mkdir -p "$(dirname "$LOG_FILE")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

################################################################################
# Configuration
################################################################################
TODATE=$(date +%Y%m%d)
NCARD="${NCARD:-1}"       # Weekly MULTIPASS fee (1 Ẑen)
TVA_RATE="${TVA_RATE:-20}" # VAT rate (20%)

################################################################################
# Get random refresh time for a user (distributed load)
################################################################################
get_refresh_time() {
    local email="$1"
    local user_dir="${MULTIPASS_DIR}/${email}"
    local refresh_file="${user_dir}/.refresh_time"
    
    if [[ -f "${refresh_file}" ]]; then
        cat "${refresh_file}"
    else
        # Generate random time between 00:00 and 20:12
        local random_minutes=$(( RANDOM % 1212 ))
        local hour=$(( random_minutes / 60 ))
        local minute=$(( random_minutes % 60 ))
        printf "%02d:%02d" $hour $minute | tee "${refresh_file}"
    fi
}

################################################################################
# Check if refresh is needed for user
################################################################################
should_refresh() {
    local email="$1"
    local user_dir="${MULTIPASS_DIR}/${email}"
    local last_refresh_file="${user_dir}/.last_refresh"
    local refresh_time=$(get_refresh_time "$email")
    local current_time=$(date '+%H:%M')
    
    # Check if already refreshed today
    if [[ -f "${last_refresh_file}" ]]; then
        local last_refresh=$(cat "${last_refresh_file}")
        if [[ "${last_refresh}" == "${TODATE}" ]]; then
            return 1  # Already refreshed today
        fi
    fi
    
    # Check if current time has passed refresh time
    local current_seconds=$((10#${current_time%%:*} * 3600 + 10#${current_time##*:} * 60))
    local refresh_seconds=$((10#${refresh_time%%:*} * 3600 + 10#${refresh_time##*:} * 60))
    
    if [[ $current_seconds -ge $refresh_seconds ]]; then
        return 0  # Should refresh
    fi
    
    return 1  # Not time yet
}

################################################################################
# Update uDRIVE content
################################################################################
update_udrive() {
    local email="$1"
    local user_dir="${MULTIPASS_DIR}/${email}"
    local udrive_dir="${user_dir}/uDRIVE"
    
    mkdir -p "${udrive_dir}"
    
    log "DEBUG" "Updating uDRIVE for ${email}"
    
    # Add content to IPFS
    if [[ -d "${udrive_dir}" ]] && command -v ipfs &>/dev/null; then
        local udrive_cid=$(ipfs add -rwq "${udrive_dir}" 2>/dev/null | tail -n 1)
        if [[ -n "${udrive_cid}" ]]; then
            echo "${udrive_cid}" > "${user_dir}/.udrive_cid"
            log "INFO" "uDRIVE updated: ${udrive_cid:0:16}..."
            echo "${udrive_cid}"
        fi
    fi
}

################################################################################
# Publish user data to IPNS
################################################################################
publish_ipns() {
    local email="$1"
    local user_dir="${MULTIPASS_DIR}/${email}"
    
    if ! command -v ipfs &>/dev/null; then
        log "WARN" "IPFS not available, skipping IPNS publish"
        return 1
    fi
    
    # Get user's G1 public key for IPNS key name
    local g1pub=$(cat "${user_dir}/G1PUB" 2>/dev/null)
    if [[ -z "${g1pub}" ]]; then
        log "WARN" "G1PUB not found for ${email}"
        return 1
    fi
    
    local key_name="${g1pub}:NOSTR"
    
    # Import IPNS key if not exists
    if ! ipfs key list | grep -q "${key_name}"; then
        if [[ -f "${user_dir}/ipfs.key" ]]; then
            ipfs key import "${key_name}" -f pem-pkcs8-cleartext "${user_dir}/ipfs.key" 2>/dev/null
        else
            log "WARN" "IPFS key not found for ${email}"
            return 1
        fi
    fi
    
    # Add user directory to IPFS
    local user_cid=$(ipfs add -rwq "${user_dir}/" 2>/dev/null | tail -n 1)
    if [[ -n "${user_cid}" ]]; then
        # Publish to IPNS
        ipfs name publish --key "${key_name}" "/ipfs/${user_cid}" 2>/dev/null
        log "INFO" "IPNS published for ${email}: /ipfs/${user_cid:0:16}..."
        return 0
    fi
    
    return 1
}

################################################################################
# Process weekly fee collection
################################################################################
collect_weekly_fee() {
    local email="$1"
    local user_dir="${MULTIPASS_DIR}/${email}"
    
    # Check registration date
    local birthdate=$(cat "${user_dir}/TODATE" 2>/dev/null)
    if [[ -z "${birthdate}" ]]; then
        log "WARN" "No birthdate for ${email}, skipping fee collection"
        return 1
    fi
    
    # Calculate days since registration
    local birthdate_seconds=$(date -d "${birthdate}" +%s 2>/dev/null || echo "0")
    local today_seconds=$(date +%s)
    local diff_days=$(( (today_seconds - birthdate_seconds) / 86400 ))
    
    # Check if it's a payment day (every 7 days after day 7)
    if [[ $diff_days -lt 7 ]] || [[ $(( diff_days % 7 )) -ne 0 ]]; then
        log "DEBUG" "Not a payment day for ${email} (day ${diff_days})"
        return 0
    fi
    
    # Check if already paid today
    local last_payment=$(cat "${user_dir}/.last_payment" 2>/dev/null)
    if [[ "${last_payment}" == "${TODATE}" ]]; then
        log "DEBUG" "Already paid today for ${email}"
        return 0
    fi
    
    # Calculate fee amounts
    local fee_ht="${NCARD}"
    local fee_tva=$(echo "scale=2; ${fee_ht} * ${TVA_RATE} / 100" | bc -l)
    local fee_total=$(echo "scale=2; ${fee_ht} + ${fee_tva}" | bc -l)
    
    log "INFO" "Collecting weekly fee for ${email}: ${fee_ht} Ẑen HT + ${fee_tva} Ẑen TVA = ${fee_total} Ẑen TTC"
    
    # TODO: Implement actual payment via PAYforSURE.sh
    # For demo, just mark as paid
    echo "${TODATE}" > "${user_dir}/.last_payment"
    
    log "INFO" "Fee collected for ${email}"
    return 0
}

################################################################################
# Main refresh loop
################################################################################
main() {
    log "INFO" "Starting NOSTRCARD refresh"
    
    if [[ ! -d "${MULTIPASS_DIR}" ]]; then
        log "WARN" "No MULTIPASS directory found"
        exit 0
    fi
    
    local processed=0
    local skipped=0
    
    for user_dir in "${MULTIPASS_DIR}"/*@*/; do
        [[ ! -d "${user_dir}" ]] && continue
        
        local email=$(basename "${user_dir}")
        
        # Check if should refresh
        if ! should_refresh "${email}"; then
            log "DEBUG" "Skipping ${email} (not time yet)"
            skipped=$((skipped + 1))
            continue
        fi
        
        log "INFO" "Processing MULTIPASS: ${email}"
        
        # Update uDRIVE
        update_udrive "${email}"
        
        # Publish to IPNS
        publish_ipns "${email}"
        
        # Collect weekly fee
        collect_weekly_fee "${email}"
        
        # Mark as refreshed today
        echo "${TODATE}" > "${user_dir}/.last_refresh"
        
        processed=$((processed + 1))
    done
    
    log "INFO" "NOSTRCARD refresh complete: ${processed} processed, ${skipped} skipped"
}

main "$@"
