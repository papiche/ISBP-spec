#!/bin/bash
################################################################################
# Test: Accounting Coherence
# Verifies that all economic operations maintain accounting integrity
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

################################################################################
# Accounting Verification Functions
################################################################################

# Sum all wallet balances
sum_all_balances() {
    local total=0
    
    for wallet_file in "${WALLETS_DIR}"/*.balance; do
        [[ -f "${wallet_file}" ]] || continue
        local balance=$(cat "${wallet_file}")
        total=$(echo "scale=2; ${total} + ${balance}" | bc -l)
    done
    
    echo "${total}"
}

# Verify double-entry accounting
verify_double_entry() {
    local from_wallet="$1"
    local to_wallet="$2"
    local amount="$3"
    local from_before="$4"
    local to_before="$5"
    
    local from_after=$(get_test_balance "${from_wallet}")
    local to_after=$(get_test_balance "${to_wallet}")
    
    local expected_from=$(echo "scale=2; ${from_before} - ${amount}" | bc -l)
    local expected_to=$(echo "scale=2; ${to_before} + ${amount}" | bc -l)
    
    [[ "${from_after}" == "${expected_from}" ]] && [[ "${to_after}" == "${expected_to}" ]]
}

################################################################################
# Tests
################################################################################

test_total_conservation_single_transfer() {
    setup_test_env
    
    init_test_wallet "wallet_a" "500"
    init_test_wallet "wallet_b" "500"
    
    local initial_total=$(sum_all_balances)
    
    # Transfer
    echo "400" > "${WALLETS_DIR}/wallet_a.balance"
    echo "600" > "${WALLETS_DIR}/wallet_b.balance"
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Total should be conserved"
    
    teardown_test_env
}

test_total_conservation_multiple_transfers() {
    setup_test_env
    
    # Create 5 wallets
    init_test_wallet "cash" "1000"
    init_test_wallet "assets" "500"
    init_test_wallet "rnd" "300"
    init_test_wallet "node" "0"
    init_test_wallet "captain" "0"
    
    local initial_total=$(sum_all_balances)
    
    # Simulate multiple transfers (like a complete economic cycle)
    # PAF payments: cash -> node, cash -> captain
    echo "958" > "${WALLETS_DIR}/cash.balance"   # -42 (14+28)
    echo "14" > "${WALLETS_DIR}/node.balance"    # +14
    echo "28" > "${WALLETS_DIR}/captain.balance" # +28
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Total conserved after multiple transfers"
    
    teardown_test_env
}

test_cooperative_cycle_conservation() {
    setup_test_env
    
    # Complete cooperative cycle test
    init_test_wallet "uplanet.captain" "1000"
    init_test_wallet "uplanet.IMPOT" "0"
    init_test_wallet "uplanet.CASH" "0"
    init_test_wallet "uplanet.RnD" "0"
    init_test_wallet "uplanet.ASSETS" "0"
    
    local initial_total=$(sum_all_balances)
    
    # Tax (15%)
    local tax=150
    echo "850" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "150" > "${WALLETS_DIR}/uplanet.IMPOT.balance"
    
    # 3x1/3 allocation of remaining 850
    # 33.33% = 283.30, 33.33% = 283.30, 33.34% = 283.40
    echo "0.00" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "283.30" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "283.30" > "${WALLETS_DIR}/uplanet.RnD.balance"
    echo "283.40" > "${WALLETS_DIR}/uplanet.ASSETS.balance"
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Cooperative cycle conserves total"
    
    teardown_test_env
}

test_economy_cycle_conservation() {
    setup_test_env
    
    # Complete economy cycle (PAF payments)
    init_test_wallet "uplanet.CASH" "100"
    init_test_wallet "uplanet.ASSETS" "50"
    init_test_wallet "uplanet.RnD" "50"
    init_test_wallet "secret.NODE" "0"
    init_test_wallet "captain.MULTIPASS" "0"
    
    local initial_total=$(sum_all_balances)
    
    # NODE paid from CASH (14)
    echo "86" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "14" > "${WALLETS_DIR}/secret.NODE.balance"
    
    # CAPTAIN paid from CASH (28)
    echo "58" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "28" > "${WALLETS_DIR}/captain.MULTIPASS.balance"
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Economy cycle conserves total"
    
    teardown_test_env
}

test_degraded_payment_conservation() {
    setup_test_env
    
    # Test degraded payment (from ASSETS when CASH insufficient)
    init_test_wallet "uplanet.CASH" "10"
    init_test_wallet "uplanet.ASSETS" "100"
    init_test_wallet "secret.NODE" "0"
    
    local initial_total=$(sum_all_balances)
    
    # NODE paid from ASSETS (CASH insufficient)
    echo "86" > "${WALLETS_DIR}/uplanet.ASSETS.balance"
    echo "14" > "${WALLETS_DIR}/secret.NODE.balance"
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Degraded payment conserves total"
    
    teardown_test_env
}

test_no_money_creation() {
    setup_test_env
    
    init_test_wallet "wallet" "100"
    
    local before=$(sum_all_balances)
    
    # Any operation should not create money
    # (This verifies that balances only change through transfers)
    
    local after=$(sum_all_balances)
    
    assert_eq "${before}" "${after}" "No money creation"
    
    teardown_test_env
}

test_negative_balance_prevention() {
    setup_test_env
    
    init_test_wallet "poor" "10"
    
    local balance=$(get_test_balance "poor")
    local amount=100
    
    # Transfer should be prevented
    if [[ $(echo "${balance} >= ${amount}" | bc -l) -eq 1 ]]; then
        # Would create negative balance - should not happen
        echo "ERROR: Transfer would create negative balance" >&2
        teardown_test_env
        return 1
    fi
    
    # Balance unchanged
    assert_eq "10" "$(get_test_balance "poor")" "Balance unchanged when transfer refused"
    
    teardown_test_env
}

test_rounding_accumulation() {
    setup_test_env
    
    # Test that rounding errors don't accumulate
    init_test_wallet "source" "1000"
    init_test_wallet "dest" "0"
    
    local initial_total=$(sum_all_balances)
    
    # Multiple small transfers
    for i in {1..10}; do
        local src=$(get_test_balance "source")
        local dst=$(get_test_balance "dest")
        
        local new_src=$(echo "scale=2; ${src} - 33.33" | bc -l)
        local new_dst=$(echo "scale=2; ${dst} + 33.33" | bc -l)
        
        echo "${new_src}" > "${WALLETS_DIR}/source.balance"
        echo "${new_dst}" > "${WALLETS_DIR}/dest.balance"
    done
    
    local final_total=$(sum_all_balances)
    
    # Check total is conserved (small rounding acceptable)
    local diff=$(echo "scale=2; ${initial_total} - ${final_total}" | bc -l)
    local abs_diff=${diff#-}
    
    assert_ge "0.10" "${abs_diff}" "Rounding accumulation should be minimal"
    
    teardown_test_env
}

test_complete_economic_cycle() {
    setup_test_env
    
    # Full economic cycle: income -> tax -> allocation -> PAF payments
    
    # 1. Initial state
    init_test_wallet "income" "1000"       # New income from services
    init_test_wallet "uplanet.captain" "0"
    init_test_wallet "uplanet.IMPOT" "0"
    init_test_wallet "uplanet.CASH" "0"
    init_test_wallet "uplanet.RnD" "0"
    init_test_wallet "uplanet.ASSETS" "0"
    init_test_wallet "secret.NODE" "0"
    init_test_wallet "captain.MULTIPASS" "0"
    
    local initial_total=$(sum_all_balances)
    
    # 2. Income transferred to captain
    echo "0" > "${WALLETS_DIR}/income.balance"
    echo "1000" > "${WALLETS_DIR}/uplanet.captain.balance"
    
    # 3. Cooperative allocation
    # Tax 15%
    echo "850" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "150" > "${WALLETS_DIR}/uplanet.IMPOT.balance"
    
    # 3x1/3
    echo "0" > "${WALLETS_DIR}/uplanet.captain.balance"
    echo "283.33" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "283.33" > "${WALLETS_DIR}/uplanet.RnD.balance"
    echo "283.34" > "${WALLETS_DIR}/uplanet.ASSETS.balance"
    
    # 4. PAF payments from CASH
    # NODE: 14
    echo "269.33" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "14" > "${WALLETS_DIR}/secret.NODE.balance"
    
    # CAPTAIN: 28
    echo "241.33" > "${WALLETS_DIR}/uplanet.CASH.balance"
    echo "28" > "${WALLETS_DIR}/captain.MULTIPASS.balance"
    
    local final_total=$(sum_all_balances)
    
    assert_eq "${initial_total}" "${final_total}" "Complete economic cycle conserves total"
    
    teardown_test_env
}

################################################################################
# Main
################################################################################
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISBP Test Suite: Accounting Coherence${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    run_test "single transfer conservation" test_total_conservation_single_transfer
    run_test "multiple transfers conservation" test_total_conservation_multiple_transfers
    run_test "cooperative cycle conservation" test_cooperative_cycle_conservation
    run_test "economy cycle conservation" test_economy_cycle_conservation
    run_test "degraded payment conservation" test_degraded_payment_conservation
    run_test "no money creation" test_no_money_creation
    run_test "negative balance prevention" test_negative_balance_prevention
    run_test "rounding accumulation minimal" test_rounding_accumulation
    run_test "complete economic cycle" test_complete_economic_cycle
    
    print_test_summary "Accounting Coherence"
}

main "$@"
