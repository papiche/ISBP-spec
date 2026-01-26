#!/bin/bash
################################################################################
# ISBP Test Suite - Main Runner
# Runs all tests and generates a summary report
#
# Usage: ./tests/run_all.sh [options]
#
# Options:
#   -v, --verbose    Show detailed output
#   -q, --quiet      Show only summary
#   -f, --fast       Skip slow tests
#   --no-color       Disable color output
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Options
VERBOSE=0
QUIET=0
FAST=0
NO_COLOR=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -f|--fast) FAST=1; shift ;;
        --no-color) NO_COLOR=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Disable colors if requested
if [[ ${NO_COLOR} -eq 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Test files
TEST_FILES=(
    "test_keygen.sh"
    "test_wallet.sh"
    "test_economy.sh"
    "test_cooperative.sh"
    "test_accounting.sh"
)

# Counters
TOTAL_SUITES=0
SUITES_PASSED=0
SUITES_FAILED=0

################################################################################
# Header
################################################################################
print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}║       🧪 ISBP - IPFS Station Beacon Protocol                  ║${NC}"
    echo -e "${BLUE}║                   Test Suite                                  ║${NC}"
    echo -e "${BLUE}║                                                               ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Project: ${CYAN}${PROJECT_DIR}${NC}"
    echo -e "  Date: ${CYAN}$(date)${NC}"
    echo ""
}

################################################################################
# Run a single test suite
################################################################################
run_suite() {
    local test_file="$1"
    local test_path="${SCRIPT_DIR}/${test_file}"
    
    if [[ ! -f "${test_path}" ]]; then
        echo -e "${RED}  ✗ ${test_file} - FILE NOT FOUND${NC}"
        return 1
    fi
    
    if [[ ! -x "${test_path}" ]]; then
        chmod +x "${test_path}"
    fi
    
    ((TOTAL_SUITES++))
    
    if [[ ${QUIET} -eq 1 ]]; then
        # Quiet mode: only show pass/fail
        if "${test_path}" > /dev/null 2>&1; then
            echo -e "${GREEN}  ✓ ${test_file}${NC}"
            ((SUITES_PASSED++))
            return 0
        else
            echo -e "${RED}  ✗ ${test_file}${NC}"
            ((SUITES_FAILED++))
            return 1
        fi
    else
        # Normal mode: show full output
        echo ""
        if "${test_path}"; then
            ((SUITES_PASSED++))
            return 0
        else
            ((SUITES_FAILED++))
            return 1
        fi
    fi
}

################################################################################
# Print summary
################################################################################
print_summary() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    📊 TEST SUMMARY                            ║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  Total test suites:  ${TOTAL_SUITES}                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}Passed:${NC}             ${SUITES_PASSED}                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${RED}Failed:${NC}             ${SUITES_FAILED}                                       ${BLUE}║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [[ ${SUITES_FAILED} -eq 0 ]]; then
        echo -e "${BLUE}║${NC}  ${GREEN}✓ ALL TESTS PASSED${NC}                                        ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║${NC}  ${RED}✗ SOME TESTS FAILED${NC}                                       ${BLUE}║${NC}"
    fi
    
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

################################################################################
# Check dependencies
################################################################################
check_dependencies() {
    local missing=0
    
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # bc (calculator)
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}  ✗ bc not found (required for calculations)${NC}"
        missing=1
    else
        echo -e "${GREEN}  ✓ bc${NC}"
    fi
    
    # python3
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}  ⚠ python3 not found (some tests may skip)${NC}"
    else
        echo -e "${GREEN}  ✓ python3${NC}"
    fi
    
    # keygen
    if [[ ! -x "${PROJECT_DIR}/tools/keygen" ]]; then
        echo -e "${YELLOW}  ⚠ keygen not found (keygen tests will skip)${NC}"
    else
        echo -e "${GREEN}  ✓ keygen${NC}"
    fi
    
    echo ""
    
    if [[ ${missing} -eq 1 ]]; then
        echo -e "${RED}Missing required dependencies. Please install them first.${NC}"
        exit 1
    fi
}

################################################################################
# Main
################################################################################
main() {
    print_header
    check_dependencies
    
    echo -e "${BLUE}Running test suites...${NC}"
    echo ""
    
    for test_file in "${TEST_FILES[@]}"; do
        run_suite "${test_file}"
    done
    
    print_summary
    
    # Exit with failure if any tests failed
    [[ ${SUITES_FAILED} -eq 0 ]]
}

main "$@"
