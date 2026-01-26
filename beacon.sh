#!/bin/bash
################################################################################
# ISBP - IPFS Station Beacon Protocol
# Simplified beacon server for node discovery
#
# Usage: ./beacon.sh [port]
# Default port: 12345
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
PORT=${1:-12345}

# Configuration
BEACON_DIR="${HOME}/.isbp"
SWARM_DIR="${BEACON_DIR}/swarm"
BOOTSTRAP_FILE="${MY_PATH}/bootstrap.txt"

mkdir -p "${BEACON_DIR}" "${SWARM_DIR}"

################################################################################
# IPFS Node Identity
################################################################################
get_ipfs_identity() {
    IPFSNODEID=$(ipfs id -f='<id>' 2>/dev/null)
    if [[ -z "${IPFSNODEID}" ]]; then
        echo "ERROR: IPFS daemon not running" >&2
        exit 1
    fi
    echo "${IPFSNODEID}"
}

################################################################################
# MySwarm IPNS Key - Derived key for publishing swarm view
# Each node publishes its known swarm members to this IPNS address
################################################################################
init_myswarm_key() {
    local IPFSNODEID="$1"
    local KEYNAME="MySwarm_${IPFSNODEID}"
    
    # Check if key already exists
    SWARM_IPNS=$(ipfs key list -l 2>/dev/null | grep -w "${KEYNAME}" | cut -d ' ' -f 1)
    
    if [[ -z "${SWARM_IPNS}" || ! -f "${SECRETS_DIR}/myswarm.ipns" ]]; then
        echo "Creating MySwarm IPNS key..." >&2
        
        # Derive secret from machine identity + IPFSNODEID
        # This ensures the swarm key is unique but reproducible per node
        if [[ -f /proc/cpuinfo ]]; then
            SECRET1=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
        else
            SECRET1=$(hostname | sha512sum | cut -d ' ' -f 1)
        fi
        SECRET2="${IPFSNODEID}"
        
        # Store derivation secrets
        echo "SALT=${SECRET1}" > "${SECRETS_DIR}/myswarm.june"
        echo "PEPPER=${SECRET2}" >> "${SECRETS_DIR}/myswarm.june"
        chmod 600 "${SECRETS_DIR}/myswarm.june"
        
        # Generate IPNS key using keygen
        if [[ -x "${MY_PATH}/tools/keygen" ]]; then
            "${MY_PATH}/tools/keygen" -t ipfs -o "${SECRETS_DIR}/myswarm.ipns" "${SECRET1}" "${SECRET2}"
            chmod 600 "${SECRETS_DIR}/myswarm.ipns"
            
            # Remove old key if exists
            ipfs key rm "${KEYNAME}" 2>/dev/null
            
            # Import key into IPFS
            ipfs key import "${KEYNAME}" -f pem-pkcs8-cleartext "${SECRETS_DIR}/myswarm.ipns" 2>/dev/null
        else
            # Fallback: generate key directly via IPFS
            ipfs key gen "${KEYNAME}" 2>/dev/null
        fi
        
        SWARM_IPNS=$(ipfs key list -l 2>/dev/null | grep -w "${KEYNAME}" | cut -d ' ' -f 1)
        echo "MySwarm IPNS: ${SWARM_IPNS}" >&2
    fi
    
    echo "${SWARM_IPNS}"
}

################################################################################
# Publish swarm view to IPNS
# The swarm directory contains data from all known nodes
################################################################################
publish_swarm() {
    local IPFSNODEID="$1"
    local KEYNAME="MySwarm_${IPFSNODEID}"
    
    # Check if swarm data has changed
    local SWARM_SIZE=$(du -sb "${SWARM_DIR}" 2>/dev/null | cut -f1)
    local CACHED_SIZE=$(cat "${SWARM_DIR}/.size" 2>/dev/null)
    
    if [[ "${SWARM_SIZE}" != "${CACHED_SIZE}" || -z "${CACHED_SIZE}" ]]; then
        echo "Publishing swarm view (${SWARM_SIZE} bytes)..." >&2
        
        # Add swarm directory to IPFS
        local SWARM_HASH=$(ipfs --timeout 180s add -rwq "${SWARM_DIR}"/* 2>/dev/null | tail -n 1)
        
        if [[ -n "${SWARM_HASH}" ]]; then
            # Publish to IPNS
            ipfs --timeout 180s name publish --key "${KEYNAME}" "/ipfs/${SWARM_HASH}" >&2
            echo "${SWARM_SIZE}" > "${SWARM_DIR}/.size"
            echo "Swarm published: /ipns/${SWARM_IPNS}" >&2
        fi
    fi
}

################################################################################
# Publish self beacon to node's IPNS
################################################################################
publish_self_beacon() {
    local BEACON_FILE="${BEACON_DIR}/beacon.json"
    
    if [[ -f "${BEACON_FILE}" ]]; then
        # Check if beacon has changed
        local BEACON_HASH=$(sha256sum "${BEACON_FILE}" | cut -d ' ' -f1)
        local CACHED_HASH=$(cat "${BEACON_DIR}/.beacon_hash" 2>/dev/null)
        
        if [[ "${BEACON_HASH}" != "${CACHED_HASH}" ]]; then
            echo "Publishing self beacon to IPNS..." >&2
            
            # Add beacon directory to IPFS
            local DIR_HASH=$(ipfs --timeout 180s add -rwq "${BEACON_DIR}"/* 2>/dev/null | tail -n 1)
            
            if [[ -n "${DIR_HASH}" ]]; then
                # Publish to node's default IPNS (self key)
                ipfs --timeout 180s name publish "/ipfs/${DIR_HASH}" >&2
                echo "${BEACON_HASH}" > "${BEACON_DIR}/.beacon_hash"
                echo "Self beacon published: /ipns/${IPFSNODEID}" >&2
            fi
        fi
    fi
}

################################################################################
# Convert IPFS PeerID to G1 Public Key
################################################################################
ipfs_to_g1() {
    local PEERID="$1"
    python3 -c "
import sys, base58
ID = '${PEERID}'
hexFmt = base58.b58decode(ID)
noTag = hexFmt[6:]
b58Key = base58.b58encode(noTag).decode()
print(b58Key)
" 2>/dev/null
}

################################################################################
# Convert G1 Public Key to IPFS PeerID
################################################################################
g1_to_ipfs() {
    local G1PUB="$1"
    python3 -c "
import sys, base58
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization
decoded = base58.b58decode('${G1PUB}')
pubkey = ed25519.Ed25519PublicKey.from_public_bytes(decoded)
raw = pubkey.public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)
ipfs_pid = base58.b58encode(b'\x00\$\x08\x01\x12 ' + raw)
print(ipfs_pid.decode('ascii'))
" 2>/dev/null
}

################################################################################
# Get public IP
################################################################################
get_public_ip() {
    curl -s -4 https://ipinfo.io/ip 2>/dev/null || \
    curl -s -4 https://api.ipify.org 2>/dev/null || \
    hostname -I | awk '{print $1}'
}

################################################################################
# Generate beacon JSON
################################################################################
generate_beacon() {
    local IPFSNODEID="$1"
    local G1PUB="$2"
    local MY_IP="$3"
    local SWARM_IPNS="$4"
    local MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    local HOSTNAME=$(hostname)
    local IPFS_PEERS=$(ipfs swarm peers 2>/dev/null | wc -l)
    local SWARM_MEMBERS=$(ls -d "${SWARM_DIR}"/*/ 2>/dev/null | wc -l)
    
    cat <<EOF
{
    "version": "1.0",
    "protocol": "ISBP",
    "created": "${MOATS}",
    "date": "$(date -u)",
    "hostname": "${HOSTNAME}",
    "myIP": "${MY_IP}",
    "ipfsnodeid": "${IPFSNODEID}",
    "g1pub": "${G1PUB}",
    "g1station": "/ipns/${IPFSNODEID}",
    "g1swarm": "/ipns/${SWARM_IPNS}",
    "swarm_members": ${SWARM_MEMBERS},
    "services": {
        "ipfs": {
            "active": true,
            "peers": ${IPFS_PEERS}
        },
        "beacon": {
            "active": true,
            "port": ${PORT}
        }
    }
}
EOF
}

################################################################################
# Handle UPSYNC request (add node to local swarm)
################################################################################
handle_upsync() {
    local G1PUB="$1"
    local CLAIMED_IPFSID="$2"
    
    # Validate: G1PUB must derive to IPFSNODEID
    local DERIVED_IPFSID=$(g1_to_ipfs "${G1PUB}")
    
    if [[ "${DERIVED_IPFSID}" == "${CLAIMED_IPFSID}" && -n "${DERIVED_IPFSID}" ]]; then
        echo "VALID UPSYNC: ${G1PUB} → ${CLAIMED_IPFSID}" >&2
        
        # Fetch node's IPNS data in background
        (
            mkdir -p "${SWARM_DIR}/${CLAIMED_IPFSID}"
            ipfs --timeout 120s get --progress=false \
                -o "${SWARM_DIR}/${CLAIMED_IPFSID}/" \
                "/ipns/${CLAIMED_IPFSID}/" 2>/dev/null
            echo "UPSYNC COMPLETE: ${CLAIMED_IPFSID}" >&2
        ) &
        
        return 0
    else
        echo "INVALID UPSYNC: ${G1PUB} ≠ ${CLAIMED_IPFSID}" >&2
        return 1
    fi
}

################################################################################
# Sync with bootstrap nodes
# Downloads bootstrap's IPNS data and discovers swarm members transitively
################################################################################
sync_bootstraps() {
    [[ ! -f "${BOOTSTRAP_FILE}" ]] && return
    
    echo "Syncing with bootstrap nodes..." >&2
    
    while read -r bootnode; do
        # Skip comments and empty lines
        [[ "${bootnode}" =~ ^# ]] && continue
        [[ -z "${bootnode}" ]] && continue
        [[ "${bootnode}" =~ ^[[:space:]]*$ ]] && continue
        
        local ipfsnodeid="${bootnode##*/}"
        local nodeip=$(echo "${bootnode}" | cut -d '/' -f 3)
        local iptype=$(echo "${bootnode}" | cut -d '/' -f 2)
        
        [[ "${ipfsnodeid}" == "${IPFSNODEID}" ]] && continue
        [[ -z "${ipfsnodeid}" ]] && continue
        
        echo "Bootstrap: ${ipfsnodeid:0:20}..." >&2
        
        # 1. Connect via IPFS swarm
        ipfs --timeout 20s swarm connect "${bootnode}" 2>/dev/null
        
        # 2. Download bootstrap's IPNS data (its beacon + cached data)
        mkdir -p "${SWARM_DIR}/${ipfsnodeid}"
        ipfs --timeout 120s get --progress=false \
            -o "${SWARM_DIR}/${ipfsnodeid}/" \
            "/ipns/${ipfsnodeid}/" 2>/dev/null
        
        # 3. Send UPSYNC request (register ourselves with bootstrap)
        local BEACON_URL
        if [[ "${iptype}" == "dnsaddr" ]]; then
            BEACON_URL="https://${nodeip}/12345/?${NODEG1PUB}=${IPFSNODEID}"
        else
            BEACON_URL="http://${nodeip}:${PORT}/?${NODEG1PUB}=${IPFSNODEID}"
        fi
        
        local RESPONSE=$(curl -s -m 10 "${BEACON_URL}")
        if [[ -n "${RESPONSE}" ]]; then
            echo "${RESPONSE}" > "${SWARM_DIR}/${ipfsnodeid}/beacon.json"
            
            # 4. Transitive discovery: get swarm members from bootstrap's g1swarm
            local BOOTSTRAP_SWARM=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('g1swarm',''))" 2>/dev/null | rev | cut -d '/' -f 1 | rev)
            
            if [[ -n "${BOOTSTRAP_SWARM}" ]]; then
                echo "  Discovering swarm from: /ipns/${BOOTSTRAP_SWARM}" >&2
                
                # List members in bootstrap's swarm
                local MEMBERS=$(ipfs --timeout 60s ls "/ipns/${BOOTSTRAP_SWARM}" 2>/dev/null | awk '{print $NF}')
                
                for member in ${MEMBERS}; do
                    [[ "${member}" == "${IPFSNODEID}" ]] && continue
                    [[ -z "${member}" ]] && continue
                    
                    # Download member's data
                    mkdir -p "${SWARM_DIR}/${member}"
                    ipfs --timeout 60s get --progress=false \
                        -o "${SWARM_DIR}/${member}/" \
                        "/ipns/${member}/" 2>/dev/null
                        
                    echo "    + ${member:0:20}..." >&2
                done
            fi
        fi
        
    done < "${BOOTSTRAP_FILE}"
    
    echo "Sync complete. Known nodes: $(ls -d "${SWARM_DIR}"/*/ 2>/dev/null | wc -l)" >&2
}

################################################################################
# Main beacon loop
################################################################################
main() {
    # Kill any existing beacon on this port
    pkill -f "nc -l -p ${PORT}" 2>/dev/null
    
    # Create secrets directory
    SECRETS_DIR="${BEACON_DIR}/secrets"
    mkdir -p "${SECRETS_DIR}"
    chmod 700 "${SECRETS_DIR}"
    
    # Get node identity
    IPFSNODEID=$(get_ipfs_identity)
    NODEG1PUB=$(ipfs_to_g1 "${IPFSNODEID}")
    MY_IP=$(get_public_ip)
    
    # Initialize MySwarm IPNS key (derived from node identity)
    SWARM_IPNS=$(init_myswarm_key "${IPFSNODEID}")
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  ISBP Beacon Server"
    echo "═══════════════════════════════════════════════════════════"
    echo "  IPFS Node ID: ${IPFSNODEID}"
    echo "  G1 Public Key: ${NODEG1PUB}"
    echo "  Public IP: ${MY_IP}"
    echo "  Port: ${PORT}"
    echo "───────────────────────────────────────────────────────────"
    echo "  Self Beacon: /ipns/${IPFSNODEID}"
    echo "  Swarm View:  /ipns/${SWARM_IPNS}"
    echo "═══════════════════════════════════════════════════════════"
    
    # Initial bootstrap sync (background)
    sync_bootstraps &
    
    # Timestamp for refresh control
    LAST_SYNC=0
    SYNC_INTERVAL=3600  # 1 hour
    
    while true; do
        MOATS=$(date +%s)
        
        # Periodic bootstrap sync and IPNS publishing
        if (( MOATS - LAST_SYNC > SYNC_INTERVAL )); then
            echo "Hourly sync triggered..." >&2
            
            # Sync with bootstraps (background subprocess)
            (
                sync_bootstraps
                
                # After sync, publish updated swarm view
                publish_swarm "${IPFSNODEID}"
                
                # Publish self beacon
                publish_self_beacon
            ) &
            
            LAST_SYNC=${MOATS}
        fi
        
        # Generate beacon JSON (includes g1swarm reference)
        BEACON_JSON=$(generate_beacon "${IPFSNODEID}" "${NODEG1PUB}" "${MY_IP}" "${SWARM_IPNS}")
        
        # Save beacon to file for IPNS publishing
        echo "${BEACON_JSON}" > "${BEACON_DIR}/beacon.json"
        
        # HTTP Response
        HTTP_RESPONSE="HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET
Server: ISBP/1.0
Content-Type: application/json; charset=UTF-8

${BEACON_JSON}"
        
        echo "(◕‿‿◕) Beacon ready on port ${PORT}" >&2
        
        # Wait for connection (blocking)
        REQ=$(echo "${HTTP_RESPONSE}" | nc -l -p ${PORT} -q 1 2>/dev/null)
        
        # Parse request
        URL=$(echo "${REQ}" | grep '^GET' | cut -d ' ' -f2 | cut -d '?' -f2)
        
        if [[ -n "${URL}" && "${URL}" != "/" ]]; then
            # Parse UPSYNC: ?G1PUB=IPFSNODEID
            IFS='=' read -r G1PUB REMOTE_IPFSID <<< "${URL}"
            
            if [[ -n "${G1PUB}" && -n "${REMOTE_IPFSID}" ]]; then
                handle_upsync "${G1PUB}" "${REMOTE_IPFSID}"
            fi
        fi
        
        echo "(^‿^) Request processed" >&2
    done
}

# Auto-wake timer (optional)
setup_autowake() {
    local WAKE_DELAY=$((3600 - RANDOM % 600))  # ~1 hour ± 10 min
    (
        sleep ${WAKE_DELAY}
        curl -s "http://127.0.0.1:${PORT}/" > /dev/null
    ) &
}

################################################################################
# Entry point
################################################################################
setup_autowake
main
