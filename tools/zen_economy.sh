#!/bin/bash
################################################################################
# ZEN.ECONOMY.sh - Simplified PAF payment system for ISBP
#
# This script handles weekly operational payments:
# - 1x PAF → NODE (Armateur - hardware rent)
# - 2x PAF → CAPTAIN MULTIPASS (Operator salary)
#
# Progressive degradation: CASH → ASSETS → RND → BANKRUPTCY
#
# Full implementation: Astroport.ONE/RUNTIME/ZEN.ECONOMY.sh
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
WALLETS_DIR="${ISBP_DIR}/wallets"
LOG_FILE="${ISBP_DIR}/logs/zen_economy.log"

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
PAF="${PAF:-14}"  # Weekly participation fee (14 Ẑen)
CURRENT_WEEK=$(date +%V)
CURRENT_YEAR=$(date +%Y)
WEEK_KEY="${CURRENT_YEAR}-W${CURRENT_WEEK}"

PAYMENT_MARKER="${ISBP_DIR}/.weekly_payment.done"

################################################################################
# Check if payment already done this week
################################################################################
check_payment_done() {
    if [[ -f "${PAYMENT_MARKER}" ]]; then
        local last_week=$(cat "${PAYMENT_MARKER}" | cut -d':' -f1)
        if [[ "${last_week}" == "${WEEK_KEY}" ]]; then
            log "INFO" "Weekly payment already completed for ${WEEK_KEY}"
            return 0
        fi
    fi
    return 1
}

################################################################################
# Get wallet balance (simplified - returns Ẑen)
################################################################################
get_balance() {
    local wallet_name="$1"
    local wallet_file="${WALLETS_DIR}/${wallet_name}.balance"
    
    if [[ -f "${wallet_file}" ]]; then
        cat "${wallet_file}"
    else
        echo "0"
    fi
}

################################################################################
# Set wallet balance (simplified demo)
################################################################################
set_balance() {
    local wallet_name="$1"
    local amount="$2"
    
    echo "${amount}" > "${WALLETS_DIR}/${wallet_name}.balance"
}

################################################################################
# Transfer between wallets (simplified demo)
################################################################################
transfer() {
    local from_wallet="$1"
    local to_wallet="$2"
    local amount="$3"
    local reference="$4"
    
    local from_balance=$(get_balance "${from_wallet}")
    local to_balance=$(get_balance "${to_wallet}")
    
    # Check sufficient balance
    if [[ $(echo "${from_balance} >= ${amount}" | bc -l) -eq 1 ]]; then
        local new_from=$(echo "scale=2; ${from_balance} - ${amount}" | bc -l)
        local new_to=$(echo "scale=2; ${to_balance} + ${amount}" | bc -l)
        
        set_balance "${from_wallet}" "${new_from}"
        set_balance "${to_wallet}" "${new_to}"
        
        log "INFO" "Transfer: ${amount} Ẑen ${from_wallet} → ${to_wallet} (${reference})"
        return 0
    else
        log "ERROR" "Insufficient balance: ${from_wallet} has ${from_balance} Ẑen, need ${amount}"
        return 1
    fi
}

################################################################################
# Main payment process
################################################################################
main() {
    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "  ZEN ECONOMY - Weekly PAF Payment (${WEEK_KEY})"
    log "INFO" "═══════════════════════════════════════════════════════════"
    
    # Check if already done
    if check_payment_done; then
        exit 0
    fi
    
    # Calculate amounts
    local node_paf="${PAF}"
    local captain_paf=$(echo "scale=2; ${PAF} * 2" | bc -l)
    local total_paf=$(echo "scale=2; ${PAF} * 3" | bc -l)
    
    log "INFO" "PAF Configuration:"
    log "INFO" "  NODE (1x PAF): ${node_paf} Ẑen"
    log "INFO" "  CAPTAIN (2x PAF): ${captain_paf} Ẑen"
    log "INFO" "  TOTAL: ${total_paf} Ẑen"
    
    # Get wallet balances
    local cash_balance=$(get_balance "uplanet.CASH")
    local assets_balance=$(get_balance "uplanet.ASSETS")
    local rnd_balance=$(get_balance "uplanet.RnD")
    
    log "INFO" "Wallet Balances:"
    log "INFO" "  CASH: ${cash_balance} Ẑen"
    log "INFO" "  ASSETS: ${assets_balance} Ẑen"
    log "INFO" "  RnD: ${rnd_balance} Ẑen"
    
    # Progressive degradation
    local phase=0
    local node_paid=0
    local captain_paid=0
    local node_source=""
    local captain_source=""
    
    # ═══════════════════════════════════════════════════════════
    # PRIORITY 1: Pay NODE (infrastructure is critical)
    # ═══════════════════════════════════════════════════════════
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "📦 NODE Payment (${node_paf} Ẑen)"
    
    # Try CASH first (Phase 0)
    if [[ $(echo "${cash_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
        if transfer "uplanet.CASH" "secret.NODE" "${node_paf}" "PAF:W${CURRENT_WEEK}:NODE"; then
            node_paid=1
            node_source="CASH"
            cash_balance=$(echo "scale=2; ${cash_balance} - ${node_paf}" | bc -l)
            log "INFO" "✅ NODE paid from CASH"
        fi
    fi
    
    # Try ASSETS (Phase 1)
    if [[ ${node_paid} -eq 0 ]]; then
        phase=1
        log "WARN" "⚠️  PHASE 1: Paying NODE from ASSETS"
        if [[ $(echo "${assets_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
            if transfer "uplanet.ASSETS" "secret.NODE" "${node_paf}" "PAF:W${CURRENT_WEEK}:NODE:PHASE1"; then
                node_paid=1
                node_source="ASSETS"
                assets_balance=$(echo "scale=2; ${assets_balance} - ${node_paf}" | bc -l)
                log "INFO" "✅ NODE paid from ASSETS (growth slowing)"
            fi
        fi
    fi
    
    # Try RnD (Phase 2)
    if [[ ${node_paid} -eq 0 ]]; then
        phase=2
        log "WARN" "⚠️  PHASE 2: Paying NODE from RnD"
        if [[ $(echo "${rnd_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
            if transfer "uplanet.RnD" "secret.NODE" "${node_paf}" "PAF:W${CURRENT_WEEK}:NODE:PHASE2"; then
                node_paid=1
                node_source="RnD"
                rnd_balance=$(echo "scale=2; ${rnd_balance} - ${node_paf}" | bc -l)
                log "INFO" "✅ NODE paid from RnD (innovation slowing)"
            fi
        fi
    fi
    
    # Bankruptcy (Phase 3)
    if [[ ${node_paid} -eq 0 ]]; then
        phase=3
        log "ERROR" "💀 PHASE 3: BANKRUPTCY - Cannot pay NODE!"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PRIORITY 2: Pay CAPTAIN (only if NODE was paid)
    # ═══════════════════════════════════════════════════════════
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "👨‍✈️ CAPTAIN Payment (${captain_paf} Ẑen)"
    
    if [[ ${node_paid} -eq 1 ]]; then
        # Refresh balances
        cash_balance=$(get_balance "uplanet.CASH")
        
        # Try CASH first
        if [[ $(echo "${cash_balance} >= ${captain_paf}" | bc -l) -eq 1 ]]; then
            if transfer "uplanet.CASH" "captain.MULTIPASS" "${captain_paf}" "SALARY:W${CURRENT_WEEK}:CAPTAIN"; then
                captain_paid=1
                captain_source="CASH"
                log "INFO" "✅ CAPTAIN paid from CASH"
            fi
        fi
        
        # Try ASSETS
        if [[ ${captain_paid} -eq 0 ]]; then
            [[ ${phase} -lt 1 ]] && phase=1
            assets_balance=$(get_balance "uplanet.ASSETS")
            if [[ $(echo "${assets_balance} >= ${captain_paf}" | bc -l) -eq 1 ]]; then
                if transfer "uplanet.ASSETS" "captain.MULTIPASS" "${captain_paf}" "SALARY:W${CURRENT_WEEK}:CAPTAIN:PHASE1"; then
                    captain_paid=1
                    captain_source="ASSETS"
                    log "INFO" "✅ CAPTAIN paid from ASSETS"
                fi
            fi
        fi
        
        # Try RnD
        if [[ ${captain_paid} -eq 0 ]]; then
            [[ ${phase} -lt 2 ]] && phase=2
            rnd_balance=$(get_balance "uplanet.RnD")
            if [[ $(echo "${rnd_balance} >= ${captain_paf}" | bc -l) -eq 1 ]]; then
                if transfer "uplanet.RnD" "captain.MULTIPASS" "${captain_paf}" "SALARY:W${CURRENT_WEEK}:CAPTAIN:PHASE2"; then
                    captain_paid=1
                    captain_source="RnD"
                    log "INFO" "✅ CAPTAIN paid from RnD"
                fi
            fi
        fi
        
        if [[ ${captain_paid} -eq 0 ]]; then
            log "WARN" "⚠️  CAPTAIN NOT PAID - insufficient funds"
        fi
    else
        log "INFO" "⏭️  CAPTAIN payment skipped (NODE not paid)"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # SUMMARY
    # ═══════════════════════════════════════════════════════════
    log "INFO" ""
    log "INFO" "╔══════════════════════════════════════════════════════════╗"
    log "INFO" "║          📊 WEEKLY PAYMENT SUMMARY - ${WEEK_KEY}         ║"
    log "INFO" "╠══════════════════════════════════════════════════════════╣"
    log "INFO" "║ DEGRADATION PHASE: ${phase}                              ║"
    
    case ${phase} in
        0) log "INFO" "║ STATUS: ✅ NORMAL OPERATION                              ║" ;;
        1) log "INFO" "║ STATUS: ⚠️  GROWTH SLOWDOWN (ASSETS depleting)           ║" ;;
        2) log "INFO" "║ STATUS: ⚠️  INNOVATION SLOWDOWN (RnD depleting)          ║" ;;
        3) log "INFO" "║ STATUS: 💀 BANKRUPTCY                                    ║" ;;
    esac
    
    log "INFO" "╠══════════════════════════════════════════════════════════╣"
    log "INFO" "║ PAYMENTS:                                                ║"
    
    if [[ ${node_paid} -eq 1 ]]; then
        log "INFO" "║   NODE:    ✅ ${node_paf} Ẑen from ${node_source}    ║"
    else
        log "INFO" "║   NODE:    ❌ NOT PAID                                   ║"
    fi
    
    if [[ ${captain_paid} -eq 1 ]]; then
        log "INFO" "║   CAPTAIN: ✅ ${captain_paf} Ẑen from ${captain_source}  ║"
    else
        log "INFO" "║   CAPTAIN: ❌ NOT PAID                                   ║"
    fi
    
    log "INFO" "╚══════════════════════════════════════════════════════════╝"
    
    # Mark as done
    echo "${WEEK_KEY}:PHASE${phase}:NODE${node_paid}:CPT${captain_paid}" > "${PAYMENT_MARKER}"
    
    exit ${phase}
}

main "$@"
