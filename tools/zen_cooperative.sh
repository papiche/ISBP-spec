#!/bin/bash
################################################################################
# ZEN.COOPERATIVE.sh - Simplified 3x1/3 allocation for ISBP
#
# This script handles cooperative surplus allocation:
# 1. Tax provision (IS 15%/25% depending on amount)
# 2. 1/3 → TREASURY (CASH) - Operational reserve
# 3. 1/3 → RnD - Research & Development
# 4. 1/3 → ASSETS - Real assets (forest-gardens)
#
# Source: CAPTAIN_DEDICATED (collected fees from MULTIPASS/ZEN Card)
#
# Full implementation: Astroport.ONE/RUNTIME/ZEN.COOPERATIVE.3x1-3.sh
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
WALLETS_DIR="${ISBP_DIR}/wallets"
LOG_FILE="${ISBP_DIR}/logs/zen_cooperative.log"

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
TODATE=$(date +%Y-%m-%d)

# Tax rates (French corporate tax)
IS_THRESHOLD="${IS_THRESHOLD:-42500}"     # Threshold in euros
IS_RATE_REDUCED="${IS_RATE_REDUCED:-15}"  # 15% up to €42,500
IS_RATE_NORMAL="${IS_RATE_NORMAL:-25}"    # 25% above €42,500

# Allocation ratios
TREASURY_RATIO="${TREASURY_RATIO:-33.33}"
RND_RATIO="${RND_RATIO:-33.33}"
ASSETS_RATIO="${ASSETS_RATIO:-33.34}"

ALLOCATION_MARKER="${ISBP_DIR}/.cooperative_allocation.done"

################################################################################
# Check if allocation already done this week
################################################################################
check_allocation_done() {
    if [[ -f "${ALLOCATION_MARKER}" ]]; then
        local last_date=$(cat "${ALLOCATION_MARKER}")
        local days_since=$(echo "($(date -d "${TODATE}" +%s) - $(date -d "${last_date}" +%s)) / 86400" | bc)
        
        if [[ ${days_since} -lt 7 ]]; then
            log "INFO" "Weekly allocation already done (last: ${last_date})"
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
# Main allocation process
################################################################################
main() {
    log "INFO" "═══════════════════════════════════════════════════════════"
    log "INFO" "  ZEN COOPERATIVE - 3x1/3 Allocation (${TODATE})"
    log "INFO" "═══════════════════════════════════════════════════════════"
    
    # Check if already done
    if check_allocation_done; then
        exit 0
    fi
    
    # Get surplus from CAPTAIN_DEDICATED (collected fees)
    local surplus=$(get_balance "uplanet.captain")
    
    log "INFO" "CAPTAIN_DEDICATED surplus: ${surplus} Ẑen"
    
    if [[ $(echo "${surplus} <= 0" | bc -l) -eq 1 ]]; then
        log "INFO" "No surplus for allocation"
        exit 0
    fi
    
    # ═══════════════════════════════════════════════════════════
    # TAX PROVISION (IS - Impôt sur les Sociétés)
    # ═══════════════════════════════════════════════════════════
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "🏛️  Tax Provision (IS)"
    
    # Convert to euros for threshold comparison (1 Ẑen ≈ 1 €)
    local surplus_eur="${surplus}"
    local tax_rate
    
    if [[ $(echo "${surplus_eur} <= ${IS_THRESHOLD}" | bc -l) -eq 1 ]]; then
        tax_rate="${IS_RATE_REDUCED}"
        log "INFO" "Using reduced rate: ${tax_rate}% (surplus ≤ €${IS_THRESHOLD})"
    else
        tax_rate="${IS_RATE_NORMAL}"
        log "INFO" "Using normal rate: ${tax_rate}% (surplus > €${IS_THRESHOLD})"
    fi
    
    local tax_amount=$(echo "scale=2; ${surplus} * ${tax_rate} / 100" | bc -l)
    
    local tax_success=1
    if transfer "uplanet.captain" "uplanet.IMPOT" "${tax_amount}" "TAX:${TODATE}:IS_${tax_rate}pct"; then
        log "INFO" "✅ Tax provision: ${tax_amount} Ẑen (${tax_rate}%)"
        tax_success=0
    else
        log "ERROR" "❌ Tax provision failed"
    fi
    
    # Calculate net surplus
    local net_surplus=$(echo "scale=2; ${surplus} - ${tax_amount}" | bc -l)
    log "INFO" "Net surplus after tax: ${net_surplus} Ẑen"
    
    if [[ $(echo "${net_surplus} <= 0" | bc -l) -eq 1 ]]; then
        log "INFO" "No net surplus for cooperative allocation"
        exit 0
    fi
    
    # ═══════════════════════════════════════════════════════════
    # 3x1/3 ALLOCATION
    # ═══════════════════════════════════════════════════════════
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "📊 3x1/3 Cooperative Allocation"
    
    # Calculate amounts
    local treasury_amount=$(echo "scale=2; ${net_surplus} * ${TREASURY_RATIO} / 100" | bc -l)
    local rnd_amount=$(echo "scale=2; ${net_surplus} * ${RND_RATIO} / 100" | bc -l)
    local assets_amount=$(echo "scale=2; ${net_surplus} * ${ASSETS_RATIO} / 100" | bc -l)
    
    log "INFO" "Allocation amounts:"
    log "INFO" "  TREASURY (${TREASURY_RATIO}%): ${treasury_amount} Ẑen"
    log "INFO" "  RnD (${RND_RATIO}%): ${rnd_amount} Ẑen"
    log "INFO" "  ASSETS (${ASSETS_RATIO}%): ${assets_amount} Ẑen"
    
    # Execute allocations
    local treasury_success=1
    local rnd_success=1
    local assets_success=1
    
    # 1/3 TREASURY
    if transfer "uplanet.captain" "uplanet.CASH" "${treasury_amount}" "COOP:${TODATE}:1/3_CASH"; then
        log "INFO" "✅ Treasury (CASH): ${treasury_amount} Ẑen"
        treasury_success=0
    else
        log "ERROR" "❌ Treasury allocation failed"
    fi
    
    # 1/3 RnD
    if transfer "uplanet.captain" "uplanet.RnD" "${rnd_amount}" "COOP:${TODATE}:1/3_RnD"; then
        log "INFO" "✅ R&D: ${rnd_amount} Ẑen"
        rnd_success=0
    else
        log "ERROR" "❌ R&D allocation failed"
    fi
    
    # 1/3 ASSETS
    if transfer "uplanet.captain" "uplanet.ASSETS" "${assets_amount}" "COOP:${TODATE}:1/3_ASSETS"; then
        log "INFO" "✅ Assets: ${assets_amount} Ẑen"
        assets_success=0
    else
        log "ERROR" "❌ Assets allocation failed"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # SUMMARY
    # ═══════════════════════════════════════════════════════════
    log "INFO" ""
    log "INFO" "╔══════════════════════════════════════════════════════════╗"
    log "INFO" "║       📊 COOPERATIVE ALLOCATION SUMMARY                   ║"
    log "INFO" "╠══════════════════════════════════════════════════════════╣"
    log "INFO" "║ Date: ${TODATE}                                          ║"
    log "INFO" "║ Initial surplus: ${surplus} Ẑen                          ║"
    log "INFO" "╠══════════════════════════════════════════════════════════╣"
    log "INFO" "║ Tax provision (${tax_rate}%): ${tax_amount} Ẑen          ║"
    log "INFO" "║ Net surplus: ${net_surplus} Ẑen                          ║"
    log "INFO" "╠══════════════════════════════════════════════════════════╣"
    log "INFO" "║ ALLOCATIONS:                                             ║"
    log "INFO" "║   🏦 Treasury: ${treasury_amount} Ẑen                    ║"
    log "INFO" "║   🔬 R&D: ${rnd_amount} Ẑen                              ║"
    log "INFO" "║   🌱 Assets: ${assets_amount} Ẑen                        ║"
    log "INFO" "╚══════════════════════════════════════════════════════════╝"
    
    # Check for failures
    local failures=$((tax_success + treasury_success + rnd_success + assets_success))
    if [[ ${failures} -gt 0 ]]; then
        log "WARN" "⚠️  Some allocations failed (${failures}/4 failures)"
    else
        log "INFO" "✅ All allocations completed successfully"
    fi
    
    # Mark as done
    echo "${TODATE}" > "${ALLOCATION_MARKER}"
    
    # Display updated balances
    log "INFO" ""
    log "INFO" "Updated wallet balances:"
    log "INFO" "  CAPTAIN_DEDICATED: $(get_balance uplanet.captain) Ẑen"
    log "INFO" "  TREASURY (CASH): $(get_balance uplanet.CASH) Ẑen"
    log "INFO" "  RnD: $(get_balance uplanet.RnD) Ẑen"
    log "INFO" "  ASSETS: $(get_balance uplanet.ASSETS) Ẑen"
    log "INFO" "  IMPOT: $(get_balance uplanet.IMPOT) Ẑen"
    
    exit ${failures}
}

main "$@"
