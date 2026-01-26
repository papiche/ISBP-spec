#!/bin/bash
################################################################################
# ZEN Card Creation
# Creates a ZEN Card wallet for a sponsor (contribution token)
#
# ZEN Card provides:
# - 128 Go NextCloud storage
# - TiddlyWiki personal wiki
# - Premium services
# - Consultative vote
# - Weekly fee: 4 Ẑen (or 50 Ẑen/year for satellite)
#
# Usage: ./zencard_create.sh <email> [type]
# Types: satellite (50€/year), constellation (540€/3years)
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
ZENCARD_DIR="${ISBP_DIR}/zencards"

mkdir -p "${ZENCARD_DIR}"

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
    local TYPE="${2:-satellite}"
    
    if [[ -z "${EMAIL}" ]]; then
        echo -e "${RED}Usage: $0 <email> [type]${NC}"
        echo -e "Types: satellite (50€/year), constellation (540€/3years)"
        exit 1
    fi
    
    # Validate email format
    if [[ ! "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid email format: ${EMAIL}${NC}"
        exit 1
    fi
    
    # Validate type
    local CONTRIBUTION=0
    local DURATION=""
    case "${TYPE}" in
        satellite)
            CONTRIBUTION=50
            DURATION="1 year"
            ;;
        constellation)
            CONTRIBUTION=540
            DURATION="3 years"
            ;;
        *)
            echo -e "${RED}Invalid type: ${TYPE}${NC}"
            echo -e "Valid types: satellite, constellation"
            exit 1
            ;;
    esac
    
    local USER_DIR="${ZENCARD_DIR}/${EMAIL}"
    
    if [[ -d "${USER_DIR}" ]]; then
        echo -e "${YELLOW}ZEN Card already exists for ${EMAIL}${NC}"
        echo -e "  Directory: ${USER_DIR}"
        exit 0
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Creating ZEN Card (${TYPE}) for: ${EMAIL}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Contribution: ${CONTRIBUTION} Ẑen"
    echo -e "  Duration: ${DURATION}"
    echo ""
    
    mkdir -p "${USER_DIR}"
    
    # Generate unique seed from email + random
    local SEED=$(echo "${EMAIL}ZENCARD$(date +%s)${RANDOM}" | sha256sum | cut -d ' ' -f1)
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
    
    # Store metadata
    local EXPIRY_DATE=""
    if [[ "${TYPE}" == "satellite" ]]; then
        EXPIRY_DATE=$(date -u -d "+1 year" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+1y +%Y-%m-%dT%H:%M:%SZ)
    else
        EXPIRY_DATE=$(date -u -d "+3 years" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+3y +%Y-%m-%dT%H:%M:%SZ)
    fi
    
    cat > "${USER_DIR}/metadata.json" << EOF
{
    "email": "${EMAIL}",
    "type": "ZENCARD_${TYPE^^}",
    "contribution": ${CONTRIBUTION},
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "expires": "${EXPIRY_DATE}",
    "services": {
        "nextcloud": "128Go",
        "tiddlywiki": true,
        "nostr": true,
        "vote": "consultative"
    },
    "status": "active"
}
EOF
    
    # Create U.SOCIETY marker (sponsor status)
    echo "${TYPE}" > "${USER_DIR}/U.SOCIETY"
    echo "$(date -u +%Y%m%d%H%M%S)" > "${USER_DIR}/TODATE"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ZEN Card created successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Email: ${CYAN}${EMAIL}${NC}"
    echo -e "  Type: ${CYAN}${TYPE}${NC}"
    echo -e "  G1 Wallet: ${CYAN}${G1PUB}${NC}"
    echo -e "  NOSTR: ${CYAN}${NPUB}${NC}"
    echo ""
    echo -e "  Services: 128 Go NextCloud + TiddlyWiki + Premium"
    echo -e "  Vote: Consultative"
    echo -e "  Expires: ${EXPIRY_DATE}"
    echo ""
    echo -e "  ${YELLOW}Note: 3x1/3 allocation will distribute contribution to:${NC}"
    echo -e "    - TREASURY: $(echo "scale=2; ${CONTRIBUTION}/3" | bc) Ẑen"
    echo -e "    - R&D: $(echo "scale=2; ${CONTRIBUTION}/3" | bc) Ẑen"
    echo -e "    - ASSETS: $(echo "scale=2; ${CONTRIBUTION}/3" | bc) Ẑen"
    echo ""
    echo -e "  Data stored in: ${USER_DIR}"
}

main "$@"
