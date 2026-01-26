#!/bin/bash
################################################################################
# UPlanet ẐEN Initialization
# Creates all cooperative wallets from the shared UPLANETNAME secret
#
# The UPLANETNAME is extracted from ~/.ipfs/swarm.key and serves as the
# cryptographic seed for generating all cooperative wallets deterministically.
#
# Usage: ./uplanet_init.sh [UPLANETNAME]
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
WALLETS_DIR="${ISBP_DIR}/wallets"

mkdir -p "${WALLETS_DIR}"
chmod 700 "${WALLETS_DIR}"

################################################################################
# Colors
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Get UPLANETNAME from swarm.key or parameter
################################################################################
get_uplanetname() {
    local provided_name="$1"
    
    if [[ -n "${provided_name}" ]]; then
        echo "${provided_name}"
        return 0
    fi
    
    # Try to extract from swarm.key
    if [[ -f "${HOME}/.ipfs/swarm.key" ]]; then
        local name=$(cat "${HOME}/.ipfs/swarm.key" | tail -n 1)
        if [[ -n "${name}" ]]; then
            echo "${name}"
            return 0
        fi
    fi
    
    # ORIGIN - developpment area -
    echo -e "${YELLOW}No swarm.key found. ORIGIN UPLANETNAME...${NC}" >&2
    local new_name="ORIGIN"
    echo "${new_name}"
}

################################################################################
# Generate wallet from seed
################################################################################
generate_wallet() {
    local wallet_name="$1"
    local salt="$2"
    local pepper="$3"
    local output_file="${WALLETS_DIR}/${wallet_name}.dunikey"
    
    if [[ -f "${output_file}" ]]; then
        echo -e "${YELLOW}  Wallet ${wallet_name} already exists${NC}"
        local pubkey=$(cat "${output_file}" | grep "pub:" | cut -d ' ' -f 2)
        echo "  ${pubkey:0:16}..."
        return 0
    fi
    
    echo -e "${CYAN}  Creating wallet: ${wallet_name}${NC}"
    
    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t duniter -o "${output_file}" "${salt}" "${pepper}"
        chmod 600 "${output_file}"
        
        local pubkey=$(cat "${output_file}" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}  ✓ ${wallet_name}: ${pubkey:0:16}...${NC}"
        
        # Save public key for easy reference
        echo "${pubkey}" > "${WALLETS_DIR}/${wallet_name}.pub"
    else
        echo -e "${RED}  ✗ keygen not found${NC}"
        return 1
    fi
}

################################################################################
# Main initialization
################################################################################
main() {
    local UPLANETNAME=$(get_uplanetname "$1")
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  UPlanet ẐEN Initialization${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  UPLANETNAME: ${CYAN}${UPLANETNAME:0:16}...${NC}"
    echo -e "  Wallets dir: ${WALLETS_DIR}"
    echo ""
    
    # Store UPLANETNAME (encrypted would be better in production)
    echo "${UPLANETNAME}" > "${ISBP_DIR}/.uplanetname"
    chmod 600 "${ISBP_DIR}/.uplanetname"
    
    echo -e "${YELLOW}Creating cooperative wallets...${NC}"
    echo ""
    
    # Central Reserve (G1)
    echo -e "${BLUE}🏛️  Central Reserve${NC}"
    generate_wallet "uplanet.G1" "${UPLANETNAME}.G1" "${UPLANETNAME}.G1"
    UPLANETG1PUB=$(cat "${WALLETS_DIR}/uplanet.G1.pub" 2>/dev/null)
    echo ""
    
    # Services wallet
    echo -e "${BLUE}⚙️  Services${NC}"
    generate_wallet "uplanet" "${UPLANETNAME}" "${UPLANETNAME}"
    echo ""
    
    # Society (Sponsors)
    echo -e "${BLUE}⭐ Society (Sponsors)${NC}"
    generate_wallet "uplanet.SOCIETY" "${UPLANETNAME}.SOCIETY" "${UPLANETNAME}.SOCIETY"
    echo ""
    
    # Treasury (CASH)
    echo -e "${BLUE}💰 Treasury (CASH)${NC}"
    generate_wallet "uplanet.CASH" "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
    echo ""
    
    # R&D
    echo -e "${BLUE}🔬 R&D${NC}"
    generate_wallet "uplanet.RnD" "${UPLANETNAME}.RND" "${UPLANETNAME}.RND"
    echo ""
    
    # Assets
    echo -e "${BLUE}🌳 Assets${NC}"
    generate_wallet "uplanet.ASSETS" "${UPLANETNAME}.ASSETS" "${UPLANETNAME}.ASSETS"
    echo ""
    
    # Tax provisions (IMPOT)
    echo -e "${BLUE}🏛️  Tax Provisions${NC}"
    generate_wallet "uplanet.IMPOT" "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
    echo ""
    
    # Capital (Immobilizations)
    echo -e "${BLUE}🏗️  Capital (Immobilizations)${NC}"
    generate_wallet "uplanet.CAPITAL" "${UPLANETNAME}.CAPITAL" "${UPLANETNAME}.CAPITAL"
    echo ""
    
    # Amortization
    echo -e "${BLUE}📉 Amortization${NC}"
    generate_wallet "uplanet.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT"
    echo ""
    
    # Get IPFS node ID for NODE wallet
    local IPFSNODEID=$(ipfs id -f='<id>' 2>/dev/null)
    if [[ -n "${IPFSNODEID}" ]]; then
        echo -e "${BLUE}🖥️  NODE (per-station)${NC}"
        generate_wallet "secret.NODE" "${UPLANETNAME}.NODE.${IPFSNODEID}" "${UPLANETNAME}.NODE.${IPFSNODEID}"
        echo ""
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  UPlanet ẐEN initialized successfully!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Central Reserve (G1): ${CYAN}${UPLANETG1PUB:0:24}...${NC}"
    echo ""
    echo -e "  ${YELLOW}Next steps:${NC}"
    echo -e "  1. Start beacon: ./beacon.sh"
    echo -e "  2. Create MULTIPASS: ./tools/multipass_create.sh user@example.com"
    echo -e "  3. Create ZEN Card: ./tools/zencard_create.sh sponsor@example.com"
    echo ""
    
    # Create summary file
    cat > "${ISBP_DIR}/uplanet_summary.json" << EOF
{
    "uplanetname": "${UPLANETNAME:0:16}...",
    "wallets": {
        "G1": "$(cat "${WALLETS_DIR}/uplanet.G1.pub" 2>/dev/null)",
        "services": "$(cat "${WALLETS_DIR}/uplanet.pub" 2>/dev/null)",
        "society": "$(cat "${WALLETS_DIR}/uplanet.SOCIETY.pub" 2>/dev/null)",
        "treasury": "$(cat "${WALLETS_DIR}/uplanet.CASH.pub" 2>/dev/null)",
        "rnd": "$(cat "${WALLETS_DIR}/uplanet.RnD.pub" 2>/dev/null)",
        "assets": "$(cat "${WALLETS_DIR}/uplanet.ASSETS.pub" 2>/dev/null)",
        "impot": "$(cat "${WALLETS_DIR}/uplanet.IMPOT.pub" 2>/dev/null)",
        "capital": "$(cat "${WALLETS_DIR}/uplanet.CAPITAL.pub" 2>/dev/null)"
    },
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo -e "  Summary saved to: ${ISBP_DIR}/uplanet_summary.json"
}

main "$@"
