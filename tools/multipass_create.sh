#!/bin/bash
################################################################################
# MULTIPASS Creation
# Creates a MULTIPASS wallet for a user (usage token)
#
# MULTIPASS provides:
# - 10 Go uDRIVE storage
# - NOSTR identity
# - Access to network services
# - Weekly fee: 1 Ẑen
#
# Usage: ./multipass_create.sh <email>
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
MULTIPASS_DIR="${ISBP_DIR}/multipass"

mkdir -p "${MULTIPASS_DIR}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Main
################################################################################
main() {
    local EMAIL="$1"
    
    if [[ -z "${EMAIL}" ]]; then
        echo -e "${RED}Usage: $0 <email>${NC}"
        exit 1
    fi
    
    # Validate email format
    if [[ ! "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid email format: ${EMAIL}${NC}"
        exit 1
    fi
    
    local USER_DIR="${MULTIPASS_DIR}/${EMAIL}"
    
    if [[ -d "${USER_DIR}" ]]; then
        echo -e "${YELLOW}MULTIPASS already exists for ${EMAIL}${NC}"
        echo -e "  Directory: ${USER_DIR}"
        exit 0
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Creating MULTIPASS for: ${EMAIL}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    mkdir -p "${USER_DIR}"
    
    # Generate unique seed from email + random
    local SEED=$(echo "${EMAIL}$(date +%s)${RANDOM}" | sha256sum | cut -d ' ' -f1)
    local SALT=$(echo "${SEED}" | cut -c1-32)
    local PEPPER=$(echo "${SEED}" | cut -c33-64)
    
    # Store seed securely
    echo "SALT=${SALT}" > "${USER_DIR}/.seed"
    echo "PEPPER=${PEPPER}" >> "${USER_DIR}/.seed"
    chmod 600 "${USER_DIR}/.seed"
    
    # Generate Duniter/G1 wallet
    echo -e "${CYAN}Generating G1 wallet...${NC}"
    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t duniter -o "${USER_DIR}/secret.dunikey" "${SALT}" "${PEPPER}"
        chmod 600 "${USER_DIR}/secret.dunikey"
        
        local G1PUB=$(cat "${USER_DIR}/secret.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo "${G1PUB}" > "${USER_DIR}/G1PUB"
        echo -e "${GREEN}  ✓ G1 Wallet: ${G1PUB:0:16}...${NC}"
    fi
    
    # Generate NOSTR keys
    echo -e "${CYAN}Generating NOSTR identity...${NC}"
    if [[ -x "${MY_PATH}/keygen" ]]; then
        local NPUB=$("${MY_PATH}/keygen" -t nostr "${SALT}" "${PEPPER}" 2>/dev/null)
        local NSEC=$("${MY_PATH}/keygen" -t nostr -s "${SALT}" "${PEPPER}" 2>/dev/null)
        
        echo "NPUB=${NPUB}" > "${USER_DIR}/nostr.key"
        echo "NSEC=${NSEC}" >> "${USER_DIR}/nostr.key"
        chmod 600 "${USER_DIR}/nostr.key"
        
        echo -e "${GREEN}  ✓ NOSTR npub: ${NPUB:0:20}...${NC}"
    fi
    
    # Generate IPFS key for user's IPNS (uDRIVE)
    echo -e "${CYAN}Generating IPFS identity...${NC}"
    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t ipfs -o "${USER_DIR}/ipfs.key" "${SALT}" "${PEPPER}"
        chmod 600 "${USER_DIR}/ipfs.key"
        
        local IPFSID=$("${MY_PATH}/keygen" -t ipfs "${SALT}" "${PEPPER}" 2>/dev/null)
        echo "${IPFSID}" > "${USER_DIR}/IPFSID"
        echo -e "${GREEN}  ✓ IPFS ID: ${IPFSID:0:20}...${NC}"
    fi
    
    # Store metadata
    cat > "${USER_DIR}/metadata.json" << EOF
{
    "email": "${EMAIL}",
    "type": "MULTIPASS",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "services": {
        "uDRIVE": "10Go",
        "nostr": true
    },
    "weekly_fee": 1,
    "status": "active"
}
EOF
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  MULTIPASS created successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Email: ${CYAN}${EMAIL}${NC}"
    echo -e "  G1 Wallet: ${CYAN}${G1PUB}${NC}"
    echo -e "  NOSTR: ${CYAN}${NPUB}${NC}"
    echo -e "  IPFS ID: ${CYAN}${IPFSID}${NC}"
    echo ""
    echo -e "  Services: 10 Go uDRIVE + NOSTR identity"
    echo -e "  Weekly fee: 1 Ẑen"
    echo ""
    echo -e "  Data stored in: ${USER_DIR}"
}

main "$@"
