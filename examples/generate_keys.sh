#!/bin/bash
################################################################################
# Generate twin cryptographic keys from a single seed
#
# Demonstrates the key derivation that makes ISBP identities portable
# across multiple protocols (IPFS, Duniter, SSH, Nostr, Bitcoin).
#
# Usage: ./generate_keys.sh [salt] [pepper]
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYGEN="${SCRIPT_DIR}/tools/keygen"

if [[ ! -x "${KEYGEN}" ]]; then
    echo "ERROR: keygen not found at ${KEYGEN}" >&2
    exit 1
fi

# Get seed
if [[ -n "$1" && -n "$2" ]]; then
    SALT="$1"
    PEPPER="$2"
else
    echo "═══════════════════════════════════════════════════════════"
    echo "  ISBP Twin Key Generator"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Enter your seed (this will generate all your keys):"
    echo ""
    read -p "SALT (secret 1): " SALT
    read -p "PEPPER (secret 2): " PEPPER
    echo ""
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Generating Twin Keys"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Generate each key type
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ IPFS PeerID                                             │"
echo "├─────────────────────────────────────────────────────────┤"
IPFS_KEY=$("${KEYGEN}" -t ipfs "${SALT}" "${PEPPER}")
echo "│ ${IPFS_KEY}"
echo "└─────────────────────────────────────────────────────────┘"
echo ""

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Duniter G1 Wallet                                       │"
echo "├─────────────────────────────────────────────────────────┤"
G1_KEY=$("${KEYGEN}" -t duniter "${SALT}" "${PEPPER}")
echo "│ ${G1_KEY}"
echo "└─────────────────────────────────────────────────────────┘"
echo ""

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ SSH Public Key                                          │"
echo "├─────────────────────────────────────────────────────────┤"
SSH_KEY=$("${KEYGEN}" -t ssh "${SALT}" "${PEPPER}" 2>/dev/null | grep "ssh-ed25519")
echo "│ ${SSH_KEY:0:70}..."
echo "└─────────────────────────────────────────────────────────┘"
echo ""

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Nostr npub                                              │"
echo "├─────────────────────────────────────────────────────────┤"
NOSTR_KEY=$("${KEYGEN}" -t nostr "${SALT}" "${PEPPER}" 2>/dev/null | head -1)
echo "│ ${NOSTR_KEY}"
echo "└─────────────────────────────────────────────────────────┘"
echo ""

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Bitcoin Address                                         │"
echo "├─────────────────────────────────────────────────────────┤"
BTC_KEY=$("${KEYGEN}" -t bitcoin "${SALT}" "${PEPPER}" 2>/dev/null | grep -E "^[13]" | head -1)
echo "│ ${BTC_KEY}"
echo "└─────────────────────────────────────────────────────────┘"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "  Key Binding Verification"
echo "═══════════════════════════════════════════════════════════"

# Verify IPFS ↔ G1 binding
DERIVED_G1=$(python3 "${SCRIPT_DIR}/tools/ipfs_to_g1.py" "${IPFS_KEY}" 2>/dev/null)
DERIVED_IPFS=$(python3 "${SCRIPT_DIR}/tools/g1_to_ipfs.py" "${G1_KEY}" 2>/dev/null)

if [[ "${DERIVED_G1}" == "${G1_KEY}" ]]; then
    echo "  IPFS → G1: ✓ ${IPFS_KEY:0:20}... → ${G1_KEY:0:20}..."
else
    echo "  IPFS → G1: ✗ Mismatch"
fi

if [[ "${DERIVED_IPFS}" == "${IPFS_KEY}" ]]; then
    echo "  G1 → IPFS: ✓ ${G1_KEY:0:20}... → ${IPFS_KEY:0:20}..."
else
    echo "  G1 → IPFS: ✗ Mismatch"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  All keys derived from single seed - portable identity!"
echo "═══════════════════════════════════════════════════════════"
