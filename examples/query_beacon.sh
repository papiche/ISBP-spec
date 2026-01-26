#!/bin/bash
################################################################################
# Query an ISBP beacon
#
# Usage: ./query_beacon.sh <host> [port]
#
# Examples:
#   ./query_beacon.sh 192.168.1.100
#   ./query_beacon.sh node.example.com 12345
#   ./query_beacon.sh node.example.com 443 /12345/  # HTTPS via reverse proxy
################################################################################

HOST="${1:-127.0.0.1}"
PORT="${2:-12345}"
PATH_PREFIX="${3:-/}"

if [[ "${PORT}" == "443" ]]; then
    URL="https://${HOST}${PATH_PREFIX}"
else
    URL="http://${HOST}:${PORT}${PATH_PREFIX}"
fi

echo "Querying beacon at ${URL}..."
echo ""

RESPONSE=$(curl -s -m 10 "${URL}")

if [[ -z "${RESPONSE}" ]]; then
    echo "ERROR: No response from ${URL}" >&2
    exit 1
fi

# Pretty print JSON
if command -v jq &>/dev/null; then
    echo "${RESPONSE}" | jq .
else
    echo "${RESPONSE}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

# Extract key info
if command -v jq &>/dev/null; then
    IPFSID=$(echo "${RESPONSE}" | jq -r '.ipfsnodeid // .ipfs_node_id // empty')
    G1PUB=$(echo "${RESPONSE}" | jq -r '.g1pub // .NODEG1PUB // empty')
    VERSION=$(echo "${RESPONSE}" | jq -r '.version // empty')
    
    [[ -n "${VERSION}" ]] && echo "  Protocol Version: ${VERSION}"
    [[ -n "${IPFSID}" ]] && echo "  IPFS Node ID: ${IPFSID}"
    [[ -n "${G1PUB}" ]] && echo "  G1 Public Key: ${G1PUB}"
    
    # Verify key binding
    if [[ -n "${IPFSID}" && -n "${G1PUB}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
        if [[ -x "${SCRIPT_DIR}/tools/g1_to_ipfs.py" ]]; then
            DERIVED=$(python3 "${SCRIPT_DIR}/tools/g1_to_ipfs.py" "${G1PUB}" 2>/dev/null)
            if [[ "${DERIVED}" == "${IPFSID}" ]]; then
                echo "  Key Binding: ✓ VALID"
            else
                echo "  Key Binding: ✗ INVALID (derived: ${DERIVED})"
            fi
        fi
    fi
fi

echo "═══════════════════════════════════════════════════════════"
