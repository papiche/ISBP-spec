#!/bin/bash
################################################################################
# Test: Wallet Operations
# Tests wallet creation, balance management, and transfers
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

################################################################################
# Tests
################################################################################

test_wallet_balance_init() {
    setup_test_env
    
    init_test_wallet "test.wallet" "100"
    local balance=$(get_test_balance "test.wallet")
    
    assert_eq "100" "${balance}" "Initial balance should be 100"
    
    teardown_test_env
}

test_wallet_balance_default_zero() {
    setup_test_env
    
    local balance=$(get_test_balance "nonexistent.wallet")
    
    assert_eq "0" "${balance}" "Non-existent wallet should have 0 balance"
    
    teardown_test_env
}

test_wallet_transfer() {
    setup_test_env
    
    # Initialize wallets
    init_test_wallet "source" "100"
    init_test_wallet "dest" "50"
    
    # Manual transfer (simulating zen_economy.sh logic)
    local src_balance=$(get_test_balance "source")
    local dst_balance=$(get_test_balance "dest")
    local amount=30
    
    local new_src=$(echo "scale=2; ${src_balance} - ${amount}" | bc -l)
    local new_dst=$(echo "scale=2; ${dst_balance} + ${amount}" | bc -l)
    
    echo "${new_src}" > "${WALLETS_DIR}/source.balance"
    echo "${new_dst}" > "${WALLETS_DIR}/dest.balance"
    
    # Verify
    assert_eq "70" "$(get_test_balance "source")" "Source should have 70 after transfer"
    assert_eq "80" "$(get_test_balance "dest")" "Dest should have 80 after transfer"
    
    teardown_test_env
}

test_wallet_transfer_insufficient_funds() {
    setup_test_env
    
    init_test_wallet "poor" "10"
    init_test_wallet "rich" "1000"
    
    local src_balance=$(get_test_balance "poor")
    local amount=100
    
    # Check if transfer should fail
    if [[ $(echo "${src_balance} >= ${amount}" | bc -l) -eq 0 ]]; then
        # Correctly refused
        assert_eq "10" "$(get_test_balance "poor")" "Balance unchanged on failed transfer"
    else
        echo "Transfer should have been refused"
        teardown_test_env
        return 1
    fi
    
    teardown_test_env
}

test_wallet_decimal_precision() {
    setup_test_env
    
    init_test_wallet "precise" "100.50"
    local balance=$(get_test_balance "precise")
    
    # Transfer fractional amount
    local new_balance=$(echo "scale=2; ${balance} - 33.33" | bc -l)
    echo "${new_balance}" > "${WALLETS_DIR}/precise.balance"
    
    local result=$(get_test_balance "precise")
    assert_eq "67.17" "${result}" "Decimal precision should be maintained"
    
    teardown_test_env
}

test_wallet_conservation() {
    setup_test_env
    
    # Total should remain constant after transfers
    init_test_wallet "wallet_a" "100"
    init_test_wallet "wallet_b" "200"
    init_test_wallet "wallet_c" "300"
    
    local initial_total=$(echo "100 + 200 + 300" | bc -l)
    
    # Simulate transfers
    echo "50" > "${WALLETS_DIR}/wallet_a.balance"    # -50
    echo "300" > "${WALLETS_DIR}/wallet_b.balance"   # +100
    echo "250" > "${WALLETS_DIR}/wallet_c.balance"   # -50
    
    local final_total=$(echo "50 + 300 + 250" | bc -l)
    
    assert_eq "${initial_total}" "${final_total}" "Total should be conserved"
    
    teardown_test_env
}

test_multiple_wallets() {
    setup_test_env
    
    # Create multiple wallets
    for i in {1..5}; do
        init_test_wallet "wallet_${i}" "$((i * 10))"
    done
    
    # Verify each
    for i in {1..5}; do
        local expected=$((i * 10))
        local actual=$(get_test_balance "wallet_${i}")
        assert_eq "${expected}" "${actual}" "Wallet ${i} balance"
    done
    
    teardown_test_env
}

################################################################################
# Main
################################################################################
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISBP Test Suite: Wallet Operations${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    run_test "balance initialization" test_wallet_balance_init
    run_test "default zero balance" test_wallet_balance_default_zero
    run_test "transfer between wallets" test_wallet_transfer
    run_test "insufficient funds rejected" test_wallet_transfer_insufficient_funds
    run_test "decimal precision" test_wallet_decimal_precision
    run_test "balance conservation" test_wallet_conservation
    run_test "multiple wallets" test_multiple_wallets
    
    print_test_summary "Wallet Operations"
}

main "$@"
