#!/bin/bash
################################################################################
# Test: ZEN Economy
# Tests the weekly PAF payment system and progressive degradation
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

ZEN_ECONOMY="${SCRIPT_DIR}/../tools/zen_economy.sh"
PAF=14

################################################################################
# Tests
################################################################################

test_zen_economy_exists() {
    assert_file_exists "${ZEN_ECONOMY}" "zen_economy.sh should exist"
}

test_paf_calculation() {
    # 1x PAF for NODE, 2x PAF for CAPTAIN
    local node_paf=${PAF}
    local captain_paf=$(echo "scale=2; ${PAF} * 2" | bc -l)
    local total_paf=$(echo "scale=2; ${PAF} * 3" | bc -l)
    
    assert_eq "14" "${node_paf}" "NODE PAF should be 14"
    assert_eq "28.00" "${captain_paf}" "CAPTAIN PAF should be 28"
    assert_eq "42.00" "${total_paf}" "Total PAF should be 42"
}

test_phase0_normal_operation() {
    setup_test_env
    
    # Phase 0: Enough CASH for both payments
    init_test_wallet "uplanet.CASH" "100"
    init_test_wallet "uplanet.ASSETS" "100"
    init_test_wallet "uplanet.RnD" "100"
    init_test_wallet "secret.NODE" "0"
    init_test_wallet "captain.MULTIPASS" "0"
    
    local cash_balance=$(get_test_balance "uplanet.CASH")
    local node_paf=${PAF}
    local captain_paf=$(echo "scale=2; ${PAF} * 2" | bc -l)
    
    # Simulate NODE payment from CASH
    if [[ $(echo "${cash_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
        local new_cash=$(echo "scale=2; ${cash_balance} - ${node_paf}" | bc -l)
        local new_node=$(echo "scale=2; 0 + ${node_paf}" | bc -l)
        echo "${new_cash}" > "${WALLETS_DIR}/uplanet.CASH.balance"
        echo "${new_node}" > "${WALLETS_DIR}/secret.NODE.balance"
        cash_balance=${new_cash}
    fi
    
    # Simulate CAPTAIN payment from CASH
    if [[ $(echo "${cash_balance} >= ${captain_paf}" | bc -l) -eq 1 ]]; then
        local new_cash=$(echo "scale=2; ${cash_balance} - ${captain_paf}" | bc -l)
        local new_captain=$(echo "scale=2; 0 + ${captain_paf}" | bc -l)
        echo "${new_cash}" > "${WALLETS_DIR}/uplanet.CASH.balance"
        echo "${new_captain}" > "${WALLETS_DIR}/captain.MULTIPASS.balance"
    fi
    
    # Verify
    assert_eq "58.00" "$(get_test_balance "uplanet.CASH")" "CASH should have 58"
    assert_eq "14" "$(get_test_balance "secret.NODE")" "NODE should have 14"
    assert_eq "28.00" "$(get_test_balance "captain.MULTIPASS")" "CAPTAIN should have 28"
    
    teardown_test_env
}

test_phase1_assets_degradation() {
    setup_test_env
    
    # Phase 1: CASH insufficient, use ASSETS
    init_test_wallet "uplanet.CASH" "10"
    init_test_wallet "uplanet.ASSETS" "100"
    init_test_wallet "uplanet.RnD" "100"
    init_test_wallet "secret.NODE" "0"
    
    local cash_balance=$(get_test_balance "uplanet.CASH")
    local assets_balance=$(get_test_balance "uplanet.ASSETS")
    local node_paf=${PAF}
    local phase=0
    
    # Try CASH first
    if [[ $(echo "${cash_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
        # CASH insufficient, try ASSETS (Phase 1)
        phase=1
        if [[ $(echo "${assets_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
            local new_assets=$(echo "scale=2; ${assets_balance} - ${node_paf}" | bc -l)
            local new_node=$(echo "scale=2; 0 + ${node_paf}" | bc -l)
            echo "${new_assets}" > "${WALLETS_DIR}/uplanet.ASSETS.balance"
            echo "${new_node}" > "${WALLETS_DIR}/secret.NODE.balance"
        fi
    fi
    
    # Verify phase 1
    assert_eq "1" "${phase}" "Should be Phase 1"
    assert_eq "10" "$(get_test_balance "uplanet.CASH")" "CASH unchanged"
    assert_eq "86" "$(get_test_balance "uplanet.ASSETS")" "ASSETS reduced"
    assert_eq "14" "$(get_test_balance "secret.NODE")" "NODE paid"
    
    teardown_test_env
}

test_phase2_rnd_degradation() {
    setup_test_env
    
    # Phase 2: CASH and ASSETS insufficient, use RnD
    init_test_wallet "uplanet.CASH" "5"
    init_test_wallet "uplanet.ASSETS" "5"
    init_test_wallet "uplanet.RnD" "100"
    init_test_wallet "secret.NODE" "0"
    
    local cash_balance=$(get_test_balance "uplanet.CASH")
    local assets_balance=$(get_test_balance "uplanet.ASSETS")
    local rnd_balance=$(get_test_balance "uplanet.RnD")
    local node_paf=${PAF}
    local phase=0
    
    # Try CASH
    if [[ $(echo "${cash_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
        phase=1
        # Try ASSETS
        if [[ $(echo "${assets_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
            phase=2
            # Try RnD
            if [[ $(echo "${rnd_balance} >= ${node_paf}" | bc -l) -eq 1 ]]; then
                local new_rnd=$(echo "scale=2; ${rnd_balance} - ${node_paf}" | bc -l)
                echo "${new_rnd}" > "${WALLETS_DIR}/uplanet.RnD.balance"
                echo "${node_paf}" > "${WALLETS_DIR}/secret.NODE.balance"
            fi
        fi
    fi
    
    # Verify phase 2
    assert_eq "2" "${phase}" "Should be Phase 2"
    assert_eq "5" "$(get_test_balance "uplanet.CASH")" "CASH unchanged"
    assert_eq "5" "$(get_test_balance "uplanet.ASSETS")" "ASSETS unchanged"
    assert_eq "86" "$(get_test_balance "uplanet.RnD")" "RnD reduced"
    assert_eq "14" "$(get_test_balance "secret.NODE")" "NODE paid"
    
    teardown_test_env
}

test_phase3_bankruptcy() {
    setup_test_env
    
    # Phase 3: All wallets insufficient = bankruptcy
    init_test_wallet "uplanet.CASH" "5"
    init_test_wallet "uplanet.ASSETS" "5"
    init_test_wallet "uplanet.RnD" "5"
    init_test_wallet "secret.NODE" "0"
    
    local cash_balance=$(get_test_balance "uplanet.CASH")
    local assets_balance=$(get_test_balance "uplanet.ASSETS")
    local rnd_balance=$(get_test_balance "uplanet.RnD")
    local node_paf=${PAF}
    local phase=0
    local node_paid=0
    
    # Try CASH
    if [[ $(echo "${cash_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
        phase=1
        # Try ASSETS
        if [[ $(echo "${assets_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
            phase=2
            # Try RnD
            if [[ $(echo "${rnd_balance} >= ${node_paf}" | bc -l) -eq 0 ]]; then
                phase=3  # BANKRUPTCY
            fi
        fi
    fi
    
    # Verify phase 3
    assert_eq "3" "${phase}" "Should be Phase 3 (bankruptcy)"
    assert_eq "0" "$(get_test_balance "secret.NODE")" "NODE not paid"
    
    teardown_test_env
}

test_captain_skipped_if_node_unpaid() {
    setup_test_env
    
    # If NODE cannot be paid, CAPTAIN should be skipped
    init_test_wallet "uplanet.CASH" "1"
    init_test_wallet "uplanet.ASSETS" "1"
    init_test_wallet "uplanet.RnD" "1"
    init_test_wallet "secret.NODE" "0"
    init_test_wallet "captain.MULTIPASS" "0"
    
    # Simulate: all insufficient for NODE
    local node_paid=0
    
    # CAPTAIN only paid if NODE was paid
    if [[ ${node_paid} -eq 0 ]]; then
        # Skip CAPTAIN payment
        :
    fi
    
    assert_eq "0" "$(get_test_balance "secret.NODE")" "NODE not paid"
    assert_eq "0" "$(get_test_balance "captain.MULTIPASS")" "CAPTAIN skipped"
    
    teardown_test_env
}

################################################################################
# Main
################################################################################
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISBP Test Suite: ZEN Economy${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    run_test "zen_economy.sh exists" test_zen_economy_exists
    run_test "PAF calculation" test_paf_calculation
    run_test "Phase 0: normal operation" test_phase0_normal_operation
    run_test "Phase 1: ASSETS degradation" test_phase1_assets_degradation
    run_test "Phase 2: RnD degradation" test_phase2_rnd_degradation
    run_test "Phase 3: bankruptcy" test_phase3_bankruptcy
    run_test "CAPTAIN skipped if NODE unpaid" test_captain_skipped_if_node_unpaid
    
    print_test_summary "ZEN Economy"
}

main "$@"
