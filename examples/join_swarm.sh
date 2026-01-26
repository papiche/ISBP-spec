#!/bin/bash
################################################################################
# Join an ISBP swarm via bootstrap nodes
#
# This script:
# 1. Reads bootstrap nodes from bootstrap.txt
# 2. Connects to each via IPFS swarm
# 3. Sends UPSYNC request to register in the swarm
# 4. Downloads swarm data from bootstrap
#
# Usage: ./join_swarm.sh [bootstrap_file]
################################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BOOTSTRAP_FILE="${1:-${SCRIPT_DIR}/bootstrap.txt}"
ISBP_DIR="${HOME}/.isbp"
SWARM_DIR="${ISBP_DIR}/swarm"

mkdir -p "${SWARM_DIR}"

################################################################################
# Get local node identity
################################################################################
get_identity() {
    IPFSNODEID=$(ipfs id -f='<id>' 2>/dev/null)
    if [[ -z "${IPFSNODEID}" ]]; then
        echo "ERROR: IPFS daemon not running" >&2
        exit 1
    fi
    
    # Convert to G1 public key
    NODEG1PUB=$(python3 "${SCRIPT_DIR}/tools/ipfs_to_g1.py" "${IPFSNODEID}" 2>/dev/null)
    
    echo "Local Identity:"
    echo "  IPFS Node ID: ${IPFSNODEID}"
    echo "  G1 Public Key: ${NODEG1PUB}"
    echo ""
}

################################################################################
# Connect to bootstrap and send UPSYNC
################################################################################
connect_bootstrap() {
    local BOOTNODE="$1"
    local IPFSID="${BOOTNODE##*/}"
    local NODEIP=$(echo "${BOOTNODE}" | cut -d '/' -f 3)
    local IPTYPE=$(echo "${BOOTNODE}" | cut -d '/' -f 2)
    
    echo "───────────────────────────────────────────────────────────"
    echo "Bootstrap: ${IPFSID:0:20}..."
    echo "  Address: ${NODEIP}"
    
    # Connect via IPFS swarm
    echo "  [1/4] Connecting to IPFS swarm..."
    if ipfs --timeout 20s swarm connect "${BOOTNODE}" 2>/dev/null; then
        echo "        ✓ Connected"
    else
        echo "        ✗ Connection failed"
        return 1
    fi
    
    # Send UPSYNC request
    echo "  [2/4] Sending UPSYNC registration..."
    local BEACON_URL
    if [[ "${IPTYPE}" == "dnsaddr" ]]; then
        BEACON_URL="https://${NODEIP}/12345/?${NODEG1PUB}=${IPFSNODEID}"
    else
        BEACON_URL="http://${NODEIP}:12345/?${NODEG1PUB}=${IPFSNODEID}"
    fi
    
    local RESPONSE=$(curl -s -m 10 "${BEACON_URL}")
    if [[ -n "${RESPONSE}" ]]; then
        echo "        ✓ Registered"
        echo "${RESPONSE}" > "${SWARM_DIR}/${IPFSID}/beacon.json"
    else
        echo "        ✗ No response"
    fi
    
    # Download bootstrap's IPNS data
    echo "  [3/4] Downloading bootstrap data..."
    mkdir -p "${SWARM_DIR}/${IPFSID}"
    if ipfs --timeout 120s get --progress=false -o "${SWARM_DIR}/${IPFSID}/" "/ipns/${IPFSID}/" 2>/dev/null; then
        echo "        ✓ Downloaded"
    else
        echo "        ✗ Download failed"
    fi
    
    # Parse swarm members from bootstrap
    echo "  [4/4] Discovering swarm members..."
    if [[ -f "${SWARM_DIR}/${IPFSID}/beacon.json" ]]; then
        local SWARM_IPNS=$(cat "${SWARM_DIR}/${IPFSID}/beacon.json" | jq -r '.g1swarm // empty' | rev | cut -d '/' -f 1 | rev)
        if [[ -n "${SWARM_IPNS}" ]]; then
            local MEMBERS=$(ipfs ls "/ipns/${SWARM_IPNS}" 2>/dev/null | wc -l)
            echo "        Found ${MEMBERS} swarm members"
        fi
    fi
    
    echo ""
}

################################################################################
# Main
################################################################################
main() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  ISBP Swarm Join"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    get_identity
    
    if [[ ! -f "${BOOTSTRAP_FILE}" ]]; then
        echo "ERROR: Bootstrap file not found: ${BOOTSTRAP_FILE}" >&2
        exit 1
    fi
    
    echo "Reading bootstraps from: ${BOOTSTRAP_FILE}"
    echo ""
    
    local COUNT=0
    while read -r bootnode; do
        # Skip comments and empty lines
        [[ "${bootnode}" =~ ^# ]] && continue
        [[ -z "${bootnode}" ]] && continue
        [[ "${bootnode}" =~ ^[[:space:]]*$ ]] && continue
        
        connect_bootstrap "${bootnode}"
        ((COUNT++))
    done < "${BOOTSTRAP_FILE}"
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Processed ${COUNT} bootstrap nodes"
    echo "  Swarm data stored in: ${SWARM_DIR}"
    echo "═══════════════════════════════════════════════════════════"
}

main "$@"
