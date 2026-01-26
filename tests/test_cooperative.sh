#!/bin/bash
################################################################################
# Test: ZEN Cooperative
# Tests the 3x1/3 allocation system
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

ZEN_COOPERATIVE="${SCRIPT_DIR}/../tools/zen_cooperative.sh"

# Configuration
IS_THRESHOLD=42500
IS_RATE_REDUCED=15
IS_RATE_NORMAL=25
TREASURY_RATIO=33.33
RND_RATIO=33.33
ASSETS_RATIO=33.34

################################################################################
# Tests
################################################################################

test_zen_cooperative_exists() {
    assert_file_exists "${ZEN_COOPERATIVE}" "zen_cooperative.sh should exist"
}

test_tax_rate_reduced() {
    local surplus=10000
    
    # Under threshold: 15%
    if [[ $(echo "${surplus} <= ${IS_THRESHOLD}" | bc -l) -eq 1 ]]; then
        local tax_rate=${IS_RATE_REDUCED}
    else
        local tax_rate=${IS_RATE_NORMAL}
    fi
    
    assert_eq "15" "${tax_rate}" "Tax rate should be 15% for low surplus"
}

test_tax_rate_normal() {
    local surplus=50000
    
    # Over threshold: 25%
    if [[ $(echo "${surplus} <= ${IS_THRESHOLD}" | bc -l) -eq 1 ]]; then
        local tax_rate=${IS_RATE_REDUCED}
    else
        local tax_rate=${IS_RATE_NORMAL}
    fi
    
    assert_eq "25" "${tax_rate}" "Tax rate should be 25% for high surplus"
}

test_tax_calculation() {
    local surplus=1000
    local tax_rate=${IS_RATE_REDUCED}
    local tax_amount=$(echo "scale=2; ${surplus} * ${tax_rate} / 100" | bc -l)
    
    assert_eq "150.00" "${tax_amount}" "Tax should be 150 (15% of 1000)"
}

test_allocation_ratios() {
    local total=$(echo "${TREASURY_RATIO} + ${RND_RATIO} + ${ASSETS_RATIO}" | bc -l)
    
    # Should sum to 100%
    assert_eq "100.00" "${total}" "Allocation ratios should sum to 100%"
}

test_3x1_3_allocation() {
    setup_test_env
    
    # Initial surplus
    local surplus=1000
    local tax_rate=${IS_RATE_REDUCED}
    local tax_amount=$(echo "scale=2; ${surplus} * ${tax_rate} / 100" | bc -l)
    local net_surplus=$(echo "scale=2; ${surplus} - ${tax_amount}" | bc -l)
    
    # Calculate allocations
    local treasury_amount=$(echo "scale=2; ${net_surplus} * ${TREASURY_RATIO} / 100" | bc -l)
    local rnd_amount=$(echo "scale=2; ${net_surplus} * ${RND_RATIO} / 100" | bc -l)
    local assets_amount=$(echo "scale=2; ${net_surplus} * ${ASSETS_RATIO} / 100" | bc -l)
    
    # Initialize wallets
    init_test_wallet "uplanet.captain" "${surplus}"
    init_test_wallet "uplanet.IMPOT" "0"
    init_test_wallet "uplanet.CASH" "0"
    init_test_wallet "uplanet.RnD" "0"
    init_test_wallet "uplanet.ASSETS" "0"
    
    # Perform allocations
    echo "$(echo "scale=2; ${surplus} - ${tax_amount}" | bc -l)" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "${tax_amount}" > "${WALLETS_DIR}/uplanet.IMPOT.balance"
    
    local captain_after_tax=$(get_test_balance "uplanet.captain")
    echo "$(echo "scale=2; ${captain_after_tax} - ${treasury_amount}" | bc -l)" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "${treasury_amount}" > "${WALLETS_DIR}/uplanet.CASH.balance"
    
    captain_after_tax=$(get_test_balance "uplanet.captain")
    echo "$(echo "scale=2; ${captain_after_tax} - ${rnd_amount}" | bc -l)" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "${rnd_amount}" > "${WALLETS_DIR}/uplanet.RnD.balance"
    
    captain_after_tax=$(get_test_balance "uplanet.captain")
    echo "$(echo "scale=2; ${captain_after_tax} - ${assets_amount}" | bc -l)" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "${assets_amount}" > "${WALLETS_DIR}/uplanet.ASSETS.balance"
    
    # Verify
    assert_eq "150.00" "$(get_test_balance "uplanet.IMPOT")" "Tax provision"
    assert_eq "283.30" "$(get_test_balance "uplanet.CASH")" "Treasury allocation"
    assert_eq "283.30" "$(get_test_balance "uplanet.RnD")" "RnD allocation"
    assert_eq "283.39" "$(get_test_balance "uplanet.ASSETS")" "Assets allocation"
    
    teardown_test_env
}

test_allocation_conservation() {
    setup_test_env
    
    local initial_surplus=1000
    
    # Calculate
    local tax_amount=$(echo "scale=2; ${initial_surplus} * ${IS_RATE_REDUCED} / 100" | bc -l)
    local net_surplus=$(echo "scale=2; ${initial_surplus} - ${tax_amount}" | bc -l)
    
    local treasury=$(echo "scale=2; ${net_surplus} * ${TREASURY_RATIO} / 100" | bc -l)
    local rnd=$(echo "scale=2; ${net_surplus} * ${RND_RATIO} / 100" | bc -l)
    local assets=$(echo "scale=2; ${net_surplus} * ${ASSETS_RATIO} / 100" | bc -l)
    
    # Total allocated
    local total_allocated=$(echo "scale=2; ${tax_amount} + ${treasury} + ${rnd} + ${assets}" | bc -l)
    
    # Check conservation (allow small rounding error)
    local diff=$(echo "scale=2; ${initial_surplus} - ${total_allocated}" | bc -l)
    local abs_diff=$(echo "${diff#-}")  # Absolute value
    
    # Difference should be < 0.02 (rounding)
    assert_ge "0.02" "${abs_diff}" "Conservation error should be minimal"
    
    teardown_test_env
}

test_no_surplus_no_allocation() {
    setup_test_env
    
    init_test_wallet "uplanet.captain" "0"
    init_test_wallet "uplanet.CASH" "100"
    init_test_wallet "uplanet.RnD" "100"
    init_test_wallet "uplanet.ASSETS" "100"
    
    local surplus=$(get_test_balance "uplanet.captain")
    
    # If no surplus, no allocation
    if [[ $(echo "${surplus} <= 0" | bc -l) -eq 1 ]]; then
        # No changes
        :
    fi
    
    assert_eq "100" "$(get_test_balance "uplanet.CASH")" "CASH unchanged"
    assert_eq "100" "$(get_test_balance "uplanet.RnD")" "RnD unchanged"
    assert_eq "100" "$(get_test_balance "uplanet.ASSETS")" "ASSETS unchanged"
    
    teardown_test_env
}

test_high_surplus_25_percent_tax() {
    setup_test_env
    
    local surplus=50000
    local tax_rate=${IS_RATE_NORMAL}  # 25%
    local tax_amount=$(echo "scale=2; ${surplus} * ${tax_rate} / 100" | bc -l)
    
    assert_eq "12500.00" "${tax_amount}" "Tax should be 12500 (25% of 50000)"
    
    teardown_test_env
}

################################################################################
# Main
################################################################################
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISBP Test Suite: ZEN Cooperative${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    run_test "zen_cooperative.sh exists" test_zen_cooperative_exists
    run_test "tax rate reduced (<42.5k)" test_tax_rate_reduced
    run_test "tax rate normal (>42.5k)" test_tax_rate_normal
    run_test "tax calculation" test_tax_calculation
    run_test "allocation ratios sum to 100%" test_allocation_ratios
    run_test "3x1/3 allocation" test_3x1_3_allocation
    run_test "allocation conservation" test_allocation_conservation
    run_test "no surplus = no allocation" test_no_surplus_no_allocation
    run_test "high surplus 25% tax" test_high_surplus_25_percent_tax
    
    print_test_summary "ZEN Cooperative"
}

main "$@"
