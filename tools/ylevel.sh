#!/bin/bash
################################################################################
# ISBP Y-Level Activation
# Creates cryptographic entanglement between SSH and IPFS identities
#
# Y-Level means your SSH key and IPFS PeerID share the same cryptographic seed,
# enabling unified identity across protocols.
#
# Levels:
#   0 - Observer:    Read-only, no beacon publishing
#   1 - Participant: Standard beacon, separate keys
#   Y - Entangled:   SSH/IPFS twin keys, full P2P capability
#
# Usage: ./ylevel.sh [auto|manual|mnemonic]
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ISBP_DIR="${HOME}/.isbp"
SECRETS_DIR="${ISBP_DIR}/secrets"

mkdir -p "${SECRETS_DIR}"
chmod 700 "${SECRETS_DIR}"

################################################################################
# Check dependencies
################################################################################
check_deps() {
    local missing=()
    
    command -v ipfs >/dev/null || missing+=("ipfs")
    command -v python3 >/dev/null || missing+=("python3")
    command -v jq >/dev/null || missing+=("jq")
    
    if [[ ! -x "${MY_PATH}/keygen" ]]; then
        missing+=("keygen (run from tools/ directory)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies: ${missing[*]}" >&2
        exit 1
    fi
}

################################################################################
# Get current IPFS identity
################################################################################
get_current_ipfs_id() {
    ipfs id -f='<id>' 2>/dev/null
}

################################################################################
# Convert SSH public key to expected IPFS PeerID
################################################################################
ssh_to_ipfs() {
    local SSH_PUB="$1"
    python3 -c "
import sys, base58, base64
# Parse SSH ed25519 public key
parts = '${SSH_PUB}'.split()
if len(parts) >= 2 and parts[0] == 'ssh-ed25519':
    key_data = base64.b64decode(parts[1])
    # SSH ed25519 format: 4 bytes length + 'ssh-ed25519' + 4 bytes length + 32 bytes key
    raw_key = key_data[-32:]
    # IPFS PeerID format: multihash prefix + raw key
    ipfs_pid = base58.b58encode(b'\x00\$\x08\x01\x12 ' + raw_key)
    print(ipfs_pid.decode('ascii'))
" 2>/dev/null
}

################################################################################
# Check if already at Y-Level
################################################################################
check_ylevel() {
    if [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
        return 1
    fi
    
    local SSH_PUB=$(cat ~/.ssh/id_ed25519.pub)
    local EXPECTED_IPFS=$(ssh_to_ipfs "${SSH_PUB}")
    local CURRENT_IPFS=$(get_current_ipfs_id)
    
    if [[ "${EXPECTED_IPFS}" == "${CURRENT_IPFS}" ]]; then
        return 0  # Already Y-Level
    fi
    return 1
}

################################################################################
# Generate keys from seed (salt + pepper)
################################################################################
generate_keys() {
    local SALT="$1"
    local PEPPER="$2"
    
    echo "Generating twin keys from seed..." >&2
    
    # Generate IPFS key
    "${MY_PATH}/keygen" -t ipfs -o "${SECRETS_DIR}/ipfs.key" "${SALT}" "${PEPPER}"
    
    # Generate Duniter key
    "${MY_PATH}/keygen" -t duniter -o "${SECRETS_DIR}/duniter.key" "${SALT}" "${PEPPER}"
    
    # Generate SSH key
    "${MY_PATH}/keygen" -t ssh -o "${SECRETS_DIR}/ssh.key" "${SALT}" "${PEPPER}"
    
    # Generate Nostr keys (both npub and nsec)
    local NPUB=$("${MY_PATH}/keygen" -t nostr "${SALT}" "${PEPPER}")
    local NSEC=$("${MY_PATH}/keygen" -t nostr -s "${SALT}" "${PEPPER}")
    echo "NPUB=${NPUB}" > "${SECRETS_DIR}/nostr.key"
    echo "NSEC=${NSEC}" >> "${SECRETS_DIR}/nostr.key"
    chmod 600 "${SECRETS_DIR}/nostr.key"
    
    # Store seed securely
    echo "SALT=${SALT}" > "${SECRETS_DIR}/seed.env"
    echo "PEPPER=${PEPPER}" >> "${SECRETS_DIR}/seed.env"
    chmod 600 "${SECRETS_DIR}/seed.env"
    chmod 600 "${SECRETS_DIR}"/*.key
    
    echo "Keys generated in ${SECRETS_DIR}/" >&2
}

################################################################################
# Activate Y-Level (replace IPFS and SSH identities)
################################################################################
activate_ylevel() {
    local SALT="$1"
    local PEPPER="$2"
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  Y-LEVEL ACTIVATION"
    echo "═══════════════════════════════════════════════════════════"
    
    # Generate all keys
    generate_keys "${SALT}" "${PEPPER}"
    
    # Extract IPFS identity
    local NEW_PEERID=$("${MY_PATH}/keygen" -t ipfs "${SALT}" "${PEPPER}")
    local NEW_PRIVKEY=$("${MY_PATH}/keygen" -t ipfs -s "${SALT}" "${PEPPER}")
    
    echo "New IPFS PeerID: ${NEW_PEERID}"
    
    # Backup current IPFS config
    if [[ -f ~/.ipfs/config ]]; then
        cp ~/.ipfs/config ~/.ipfs/config.backup.$(date +%s)
        
        # Stop IPFS if running as service
        systemctl --user stop ipfs 2>/dev/null || true
        sudo systemctl stop ipfs 2>/dev/null || true
        pkill -f "ipfs daemon" 2>/dev/null || true
        sleep 2
        
        # Update IPFS identity
        jq ".Identity.PeerID=\"${NEW_PEERID}\"" ~/.ipfs/config > ~/.ipfs/config.tmp
        jq ".Identity.PrivKey=\"${NEW_PRIVKEY}\"" ~/.ipfs/config.tmp > ~/.ipfs/config
        rm ~/.ipfs/config.tmp
        
        echo "IPFS identity updated"
    fi
    
    # Backup and replace SSH key
    if [[ -f ~/.ssh/id_ed25519 ]]; then
        [[ ! -f ~/.ssh/id_ed25519.backup ]] && \
            cp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup
        [[ ! -f ~/.ssh/id_ed25519.pub.backup ]] && \
            cp ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub.backup
    fi
    
    cp "${SECRETS_DIR}/ssh.key" ~/.ssh/id_ed25519
    cp "${SECRETS_DIR}/ssh.key.pub" ~/.ssh/id_ed25519.pub
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    
    echo "SSH identity updated"
    
    # Restart IPFS
    systemctl --user start ipfs 2>/dev/null || \
    sudo systemctl start ipfs 2>/dev/null || \
    (ipfs daemon &)
    
    sleep 3
    
    # Verify
    local CURRENT_IPFS=$(get_current_ipfs_id)
    if [[ "${CURRENT_IPFS}" == "${NEW_PEERID}" ]]; then
        echo "═══════════════════════════════════════════════════════════"
        echo "  Y-LEVEL ACTIVATED SUCCESSFULLY"
        echo "═══════════════════════════════════════════════════════════"
        echo "  IPFS PeerID: ${NEW_PEERID}"
        echo "  G1 Wallet:   $("${MY_PATH}/keygen" -t duniter "${SALT}" "${PEPPER}")"
        echo "  SSH Key:     $(cat ~/.ssh/id_ed25519.pub | cut -d ' ' -f1-2 | cut -c1-50)..."
        echo "═══════════════════════════════════════════════════════════"
        return 0
    else
        echo "ERROR: Verification failed" >&2
        return 1
    fi
}

################################################################################
# Interactive mode selection
################################################################################
select_mode() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  ISBP Y-Level Activation"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  This will create cryptographic entanglement between your"
    echo "  SSH key and IPFS PeerID, enabling unified identity."
    echo ""
    echo "  Current IPFS ID: $(get_current_ipfs_id)"
    echo ""
    
    PS3="Select key generation method: "
    options=("AUTOMATIC (hash SSH key)" "MANUAL (enter salt/pepper)" "MNEMONIC (12/24 words)" "Cancel")
    
    select opt in "${options[@]}"; do
        case $opt in
            "AUTOMATIC (hash SSH key)")
                if [[ ! -f ~/.ssh/id_ed25519 ]]; then
                    echo "No SSH key found. Generating new one..."
                    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
                fi
                
                # Derive seed from SSH private key
                SSHASH=$(sha512sum ~/.ssh/id_ed25519 | cut -d ' ' -f 1)
                SALT=$(echo "${SSHASH}" | cut -c 1-64)
                PEPPER=$(echo "${SSHASH}" | cut -c 65-128)
                
                activate_ylevel "${SALT}" "${PEPPER}"
                break
                ;;
                
            "MANUAL (enter salt/pepper)")
                echo "Enter SALT (secret phrase 1):"
                read -r SALT
                echo "Enter PEPPER (secret phrase 2):"
                read -r PEPPER
                
                echo "Preview - G1 Public Key:"
                "${MY_PATH}/keygen" -t duniter "${SALT}" "${PEPPER}"
                echo ""
                read -p "Confirm? (y/N) " confirm
                [[ "${confirm}" =~ ^[Yy] ]] && activate_ylevel "${SALT}" "${PEPPER}"
                break
                ;;
                
            "MNEMONIC (12/24 words)")
                echo "Enter mnemonic phrase (12 or 24 words):"
                read -r MNEMONIC
                
                # Use mnemonic as both salt and pepper (keygen handles this)
                SALT="${MNEMONIC}"
                PEPPER="${MNEMONIC}"
                
                echo "Preview - G1 Public Key:"
                "${MY_PATH}/keygen" -m -t duniter "${MNEMONIC}"
                echo ""
                read -p "Confirm? (y/N) " confirm
                [[ "${confirm}" =~ ^[Yy] ]] && activate_ylevel "${SALT}" "${PEPPER}"
                break
                ;;
                
            "Cancel")
                echo "Cancelled."
                exit 0
                ;;
                
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

################################################################################
# Main
################################################################################
main() {
    check_deps
    
    # Check if already at Y-Level
    if check_ylevel; then
        echo "Already at Y-Level!"
        echo "IPFS PeerID: $(get_current_ipfs_id)"
        echo "SSH matches IPFS identity."
        exit 0
    fi
    
    case "${1:-}" in
        auto)
            if [[ ! -f ~/.ssh/id_ed25519 ]]; then
                ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
            fi
            SSHASH=$(sha512sum ~/.ssh/id_ed25519 | cut -d ' ' -f 1)
            activate_ylevel "$(echo "${SSHASH}" | cut -c 1-64)" "$(echo "${SSHASH}" | cut -c 65-128)"
            ;;
        manual)
            echo "Enter SALT:" && read -r SALT
            echo "Enter PEPPER:" && read -r PEPPER
            activate_ylevel "${SALT}" "${PEPPER}"
            ;;
        mnemonic)
            echo "Enter mnemonic:" && read -r MNEMONIC
            activate_ylevel "${MNEMONIC}" "${MNEMONIC}"
            ;;
        *)
            select_mode
            ;;
    esac
}

main "$@"
