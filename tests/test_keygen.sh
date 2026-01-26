#!/bin/bash
################################################################################
# Test: Key Generation
# Tests the keygen utility and key derivation
#
# License: AGPL-3.0
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

KEYGEN="${SCRIPT_DIR}/../tools/keygen"

################################################################################
# Tests
################################################################################

test_keygen_exists() {
    assert_file_exists "${KEYGEN}" "keygen binary should exist"
}

test_keygen_executable() {
    [[ -x "${KEYGEN}" ]] || {
        echo "keygen is not executable"
        return 1
    }
}

test_ipfs_key_generation() {
    local key=$("${KEYGEN}" -t ipfs "test_salt" "test_pepper" 2>/dev/null)
    assert_not_empty "${key}" "IPFS key should be generated"
    
    # IPFS keys start with 12D3Koo or similar
    [[ "${key}" =~ ^12D3 ]] || [[ "${key}" =~ ^Qm ]] || {
        echo "Invalid IPFS key format: ${key}"
        return 1
    }
}

test_duniter_key_generation() {
    local key=$("${KEYGEN}" -t duniter "test_salt" "test_pepper" 2>/dev/null)
    assert_not_empty "${key}" "Duniter key should be generated"
}

test_nostr_key_generation() {
    local npub=$("${KEYGEN}" -t nostr "test_salt" "test_pepper" 2>/dev/null)
    assert_not_empty "${npub}" "Nostr npub should be generated"
    
    # Nostr npub starts with npub1
    [[ "${npub}" =~ ^npub1 ]] || {
        echo "Invalid Nostr npub format: ${npub}"
        return 1
    }
}

test_nostr_nsec_generation() {
    local nsec=$("${KEYGEN}" -t nostr -s "test_salt" "test_pepper" 2>/dev/null)
    assert_not_empty "${nsec}" "Nostr nsec should be generated"
    
    # Nostr nsec starts with nsec1
    [[ "${nsec}" =~ ^nsec1 ]] || {
        echo "Invalid Nostr nsec format: ${nsec}"
        return 1
    }
}

test_key_determinism() {
    # Same seed should produce same keys
    local key1=$("${KEYGEN}" -t ipfs "determinism_salt" "determinism_pepper" 2>/dev/null)
    local key2=$("${KEYGEN}" -t ipfs "determinism_salt" "determinism_pepper" 2>/dev/null)
    
    assert_eq "${key1}" "${key2}" "Same seed should produce same key"
}

test_key_uniqueness() {
    # Different seeds should produce different keys
    local key1=$("${KEYGEN}" -t ipfs "salt_a" "pepper_a" 2>/dev/null)
    local key2=$("${KEYGEN}" -t ipfs "salt_b" "pepper_b" 2>/dev/null)
    
    assert_ne "${key1}" "${key2}" "Different seeds should produce different keys"
}

test_key_file_output() {
    setup_test_env
    
    local output_file="${TEST_DIR}/test.key"
    "${KEYGEN}" -t duniter -o "${output_file}" "file_salt" "file_pepper" 2>/dev/null
    
    assert_file_exists "${output_file}" "Key file should be created"
    
    local content=$(cat "${output_file}")
    assert_not_empty "${content}" "Key file should have content"
    
    teardown_test_env
}

################################################################################
# Main
################################################################################
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ISBP Test Suite: Key Generation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if keygen exists first
    if [[ ! -x "${KEYGEN}" ]]; then
        skip_test "all keygen tests" "keygen binary not found or not executable"
        print_test_summary "Key Generation"
        return 1
    fi
    
    run_test "keygen exists" test_keygen_exists
    run_test "keygen executable" test_keygen_executable
    run_test "IPFS key generation" test_ipfs_key_generation
    run_test "Duniter key generation" test_duniter_key_generation
    run_test "Nostr npub generation" test_nostr_key_generation
    run_test "Nostr nsec generation" test_nostr_nsec_generation
    run_test "key determinism" test_key_determinism
    run_test "key uniqueness" test_key_uniqueness
    run_test "key file output" test_key_file_output
    
    print_test_summary "Key Generation"
}

main "$@"
