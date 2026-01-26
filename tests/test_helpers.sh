#!/bin/bash
################################################################################
# Test Helpers - Common functions for ISBP test suite
#
# License: AGPL-3.0
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test environment
TEST_DIR=$(mktemp -d)
export HOME="${TEST_DIR}/home"
export ISBP_DIR="${HOME}/.isbp"
export WALLETS_DIR="${ISBP_DIR}/wallets"

################################################################################
# Setup/Teardown
################################################################################
setup_test_env() {
    mkdir -p "${HOME}"
    mkdir -p "${ISBP_DIR}"
    mkdir -p "${WALLETS_DIR}"
    mkdir -p "${ISBP_DIR}/logs"
}

teardown_test_env() {
    rm -rf "${TEST_DIR}"
}

################################################################################
# Test assertions
################################################################################
assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Values should be equal}"
    
    if [[ "${expected}" == "${actual}" ]]; then
        return 0
    fi
    
    # Try numeric comparison for decimal values
    if [[ "${expected}" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "${actual}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        if [[ $(echo "${expected} == ${actual}" | bc -l) -eq 1 ]]; then
            return 0
        fi
    fi
    
    echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
    echo "  Expected: ${expected}"
    echo "  Actual:   ${actual}"
    return 1
}

assert_ne() {
    local unexpected="$1"
    local actual="$2"
    local msg="${3:-Values should not be equal}"
    
    if [[ "${unexpected}" != "${actual}" ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        echo "  Unexpected: ${unexpected}"
        echo "  Actual:     ${actual}"
        return 1
    fi
}

assert_gt() {
    local val1="$1"
    local val2="$2"
    local msg="${3:-First value should be greater than second}"
    
    if [[ $(echo "${val1} > ${val2}" | bc -l) -eq 1 ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        echo "  ${val1} should be > ${val2}"
        return 1
    fi
}

assert_ge() {
    local val1="$1"
    local val2="$2"
    local msg="${3:-First value should be >= second}"
    
    if [[ $(echo "${val1} >= ${val2}" | bc -l) -eq 1 ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        echo "  ${val1} should be >= ${val2}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-File should exist: ${file}}"
    
    if [[ -f "${file}" ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="${2:-Directory should exist: ${dir}}"
    
    if [[ -d "${dir}" ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"
    
    if [[ -n "${value}" ]]; then
        return 0
    else
        echo -e "${RED}ASSERTION FAILED: ${msg}${NC}"
        return 1
    fi
}

################################################################################
# Test execution
################################################################################
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    echo -n "  Testing ${test_name}... "
    
    # Run test in subshell to isolate failures
    if (set -e; ${test_func}); then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

skip_test() {
    local test_name="$1"
    local reason="${2:-Skipped}"
    
    echo -e "  Testing ${test_name}... ${YELLOW}SKIP${NC} (${reason})"
    ((TESTS_SKIPPED++))
}

################################################################################
# Wallet helpers for tests
################################################################################
init_test_wallet() {
    local wallet_name="$1"
    local balance="${2:-0}"
    
    echo "${balance}" > "${WALLETS_DIR}/${wallet_name}.balance"
}

get_test_balance() {
    local wallet_name="$1"
    local balance_file="${WALLETS_DIR}/${wallet_name}.balance"
    
    if [[ -f "${balance_file}" ]]; then
        cat "${balance_file}"
    else
        echo "0"
    fi
}

################################################################################
# Summary
################################################################################
print_test_summary() {
    local suite_name="$1"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ${suite_name} - Test Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  ${YELLOW}Skipped:${NC} ${TESTS_SKIPPED}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    fi
    return 0
}
