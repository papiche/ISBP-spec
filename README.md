# ISBP - IPFS Station Beacon Protocol

**Version:** 1.0  
**License:** AGPL-3.0  
**Authors:** UPlanet ẐEN Community

## Abstract

ISBP is a simple, elegant protocol for IPFS node auto-discovery using standardized JSON beacons published on port 12345. It enables decentralized swarm formation without central coordination.

## Key Features

- **Simple HTTP beacon** on port 12345
- **Twin cryptographic keys** (SSH/IPFS/Duniter/Nostr) from single seed
- **Transitive discovery** via bootstrap nodes
- **Cryptographic identity verification** (G1PUB ↔ IPFSNODEID binding)
- **Self-organizing swarm** with hourly synchronization

## Quick Start

```bash
# 1. Generate twin keys from salt/pepper
./tools/keygen -t ipfs "mysalt" "mypepper"    # IPFS PeerID
./tools/keygen -t duniter "mysalt" "mypepper" # G1 Wallet
./tools/keygen -t ssh "mysalt" "mypepper"     # SSH Key
./tools/keygen -t nostr "mysalt" "mypepper"   # Nostr npub/nsec

# 2. Start beacon
./beacon.sh

# 3. Query any node
curl http://node-ip:12345/
```

## Protocol Specification

### Endpoint

| Parameter | Value |
|-----------|-------|
| Port | 12345 (TCP) |
| Path | `/` |
| Method | GET |
| Content-Type | `application/json` |

### Beacon JSON Schema (v1.0)

```json
{
  "version": "1.0",
  "created": "20260126120000",
  "ipfsnodeid": "12D3KooW...",
  "g1pub": "DsEx1pS...",
  "g1station": "/ipns/12D3KooW...",
  "g1swarm": "/ipns/QmSwarm...",
  "swarm_members": 5,
  "myIP": "1.2.3.4",
  "hostname": "my-station",
  "services": {
    "ipfs": { "active": true },
    "beacon": { "active": true, "port": 12345 }
  }
}
```

### IPNS Addresses

Each node publishes TWO IPNS addresses:

| Address | Key | Content |
|---------|-----|---------|
| `g1station` | Node's default IPFS key | Self beacon + node data |
| `g1swarm` | `MySwarm_${IPFSNODEID}` (derived) | All known swarm members |

#### MySwarm Key Derivation

The `g1swarm` IPNS key is deterministically derived from:
```
SECRET1 = SHA512(machine_identity)  # CPU info or hostname
SECRET2 = IPFSNODEID
KEY = keygen -t ipfs "${SECRET1}" "${SECRET2}"
```

This ensures:
- Each node has a unique swarm key
- The key is reproducible (survives restarts)
- The key cannot be forged by other nodes

### UPSYNC Discovery Protocol

When a node contacts another node's beacon, it can trigger mutual discovery:

```
GET /:12345/?{G1PUB}={IPFSNODEID}
```

**Validation:**
1. Server converts `G1PUB` to IPFS PeerID using `g1_to_ipfs.py`
2. Verifies result matches provided `IPFSNODEID`
3. If valid, downloads `/ipns/{IPFSNODEID}/` to local swarm cache

### Discovery Flow

```
    NEW_NODE                    BOOTSTRAP                  EXISTING_NODE
        │                           │                            │
        │──(1) GET :12345/─────────▶│                            │
        │◀── beacon.json ───────────│                            │
        │                           │                            │
        │──(2) GET /?G1PUB=IPFSID──▶│                            │
        │                           │──(3) ipfs get /ipns/NEW/──▶│
        │                           │     (adds to swarm)        │
        │                           │                            │
        │──(4) ipfs get /ipns/EXISTING/─────────────────────────▶│
        │◀── beacon data ────────────────────────────────────────│
        │                           │                            │
```

## Twin Keys Architecture

All keys are derived from a single seed (SALT + PEPPER) using NaCl/libsodium:

```
                    SALT + PEPPER
                         │
                    ┌────┴────┐
                    │ scrypt  │
                    │ KDF     │
                    └────┬────┘
                         │
                    ED25519 SEED
                         │
         ┌───────┬───────┼───────┬───────┐
         │       │       │       │       │
        SSH    IPFS   Duniter  Nostr  Bitcoin
       ed25519 PeerID   G1PUB   npub    WIF
```

### Key Conversion

```python
# IPFS PeerID → G1 Public Key
ipfs_to_g1.py 12D3KooWxxxxxx  # → DsEx1pS...

# G1 Public Key → IPFS PeerID  
g1_to_ipfs.py DsEx1pSxxxxxx   # → 12D3KooW...
```

## Node Entanglement Levels

Inspired by quantum entanglement, nodes can operate at different commitment levels:

| Level | Name | Description |
|-------|------|-------------|
| 0 | **Observer** | Read-only, passive discovery |
| 1 | **Participant** | Publishes beacon, joins swarm |
| Y | **Entangled** | SSH/IPFS keys unified, full P2P |

### Y-Level Activation

```bash
# Activate Y-Level (twin SSH/IPFS identity)
./tools/ylevel.sh
```

This creates cryptographic entanglement where:
- SSH public key derives IPFS PeerID
- Same seed generates all protocol keys
- Enables secure P2P tunneling via `ipfs p2p`

## Bootstrap Nodes

Bootstrap nodes are listed in `bootstrap.txt`:

```
# Format: /ip4/{IP}/tcp/4001/p2p/{IPFSNODEID}
/ip4/149.102.158.67/tcp/4001/p2p/12D3KooWL2FcDJ41U9SyLuvDmA5qGzyoaj2RoEHiJPpCvY8jvx9u
```

## DNS Integration

For nodes with DNS names, map `/12345/` to the beacon port:

**Nginx:**
```nginx
location /12345/ {
    proxy_pass http://127.0.0.1:12345/;
}
```

**Caddy:**
```
handle_path /12345/* {
    reverse_proxy localhost:12345
}
```

## Security Considerations

1. **Cryptographic binding**: G1PUB must cryptographically derive to IPFSNODEID
2. **Network isolation**: Only nodes with same `UPLANETG1PUB` join the swarm
3. **Stale node removal**: Nodes silent for >3 days are pruned from swarm
4. **No secrets in beacon**: Only public identifiers are exposed

## File Structure

```
ISBP-spec/
├── README.md               # This specification
├── beacon.sh               # Simplified beacon server (port 12345)
├── bootstrap.txt           # Bootstrap node list
├── requirements.txt        # Python dependencies
├── LICENSE                 # AGPL-3.0
│
├── docs/
│   └── ZEN_ECONOMY.md      # UPlanet ẐEN economic model
│
├── tools/
│   ├── keygen              # Multi-format key generator
│   ├── keygen.readme.md    # Keygen documentation
│   ├── ipfs_to_g1.py       # IPFS PeerID → G1 converter
│   ├── g1_to_ipfs.py       # G1 → IPFS PeerID converter
│   ├── ylevel.sh           # Y-Level activation (twin keys)
│   │
│   │  # UPlanet ẐEN Economy
│   ├── uplanet_init.sh     # Initialize cooperative wallets
│   ├── multipass_create.sh # Create MULTIPASS token (usage)
│   ├── zencard_create.sh   # Create ZEN Card token (contribution)
│   ├── nostrcard_refresh.sh # uDRIVE refresh + fee collection
│   ├── zen_economy.sh      # PAF payments (NODE + CAPTAIN)
│   └── zen_cooperative.sh  # 3x1/3 surplus allocation
│
└── examples/
    ├── query_beacon.sh     # Query a beacon
    ├── join_swarm.sh       # Join a swarm
    └── generate_keys.sh    # Generate twin keys demo
```

## Runtime Data Structure

When running, each node maintains:

```
~/.isbp/
├── beacon.json         # Self beacon (published to /ipns/${IPFSNODEID})
├── .beacon_hash        # Cache for change detection
├── secrets/
│   ├── myswarm.june    # Derivation secrets (SALT/PEPPER)
│   └── myswarm.ipns    # MySwarm IPNS private key
└── swarm/              # Swarm view (published to /ipns/${SWARM_IPNS})
    ├── .size           # Cache for change detection
    ├── 12D3KooW.../    # Data from node A
    │   └── beacon.json
    ├── 12D3KooX.../    # Data from node B
    │   └── beacon.json
    └── ...
```

The `swarm/` directory is published to IPNS via the `MySwarm_${IPFSNODEID}` key.
Other nodes can discover all members by listing `/ipns/${g1swarm}/`.

## UPlanet ẐEN Economy (Extension)

ISBP can be extended with the **UPlanet ẐEN Economy** - a cooperative economic system:

### Roles

| Role | Description | Compensation |
|------|-------------|--------------|
| **Captain** | Station operator | 28 Ẑen/week |
| **Armateur** | Hardware provider | 14 Ẑen/week (PAF) |
| **User** | Service consumer | Pays 1-5 Ẑen/week |
| **Sponsor** | Infrastructure funder | 50-540 Ẑen/year |

### Token Types

| Token | Purpose | Weekly Fee |
|-------|---------|------------|
| **MULTIPASS** | Usage access (10 Go) | 1 Ẑen |
| **ZEN Card** | Contribution (128 Go) | 4 Ẑen |

### 3x1/3 Rule

All contributions are distributed equally:
- 33.33% → **TREASURY** (operating reserve)
- 33.33% → **R&D** (development)
- 33.34% → **ASSETS** (real assets)

### Quick Start

```bash
# Initialize UPlanet economy
./tools/uplanet_init.sh

# Create user MULTIPASS
./tools/multipass_create.sh user@example.com

# Create sponsor ZEN Card
./tools/zencard_create.sh sponsor@example.com satellite
```

**Full documentation:** [docs/ZEN_ECONOMY.md](docs/ZEN_ECONOMY.md)

## N² Protocol - NOSTR Signaling Layer

The full implementation uses **NOSTR as a synchronized signaling layer** for economic transparency and swarm coordination:

### NOSTR Events (NIP-101 Extension)

| Kind | Purpose | Content |
|------|---------|---------|
| **30800** | DID Document | Identity + services + wallet addresses |
| **30850** | Economic Health | Wallet balances + revenue + health status |
| **30023** | N² Journal | AI-powered personal feed summary |

### Economic Health Broadcast

Each station broadcasts its economic state to the NOSTR constellation:

```json
{
  "kind": 30850,
  "content": {
    "health": {
      "status": "healthy",
      "bilan": 42,
      "weeks_runway": 12
    },
    "wallets": {
      "cash": 420,
      "rnd": 180,
      "assets": 250
    }
  }
}
```

### Solar Time Synchronization

Payments are distributed across the swarm using **solar time sync** (20h12 local solar time per station) to prevent concurrent blockchain transactions.

### UMAP Geographic Keys

Hierarchical geographic zones with their own twin keys (G1 + NOSTR):

| Level | Precision | Size | Content |
|-------|-----------|------|---------|
| **UMAP** | 0.01° | ~1.1 km | Local community, friends |
| **SECTOR** | 0.1° | ~11 km | Liked posts (≥3 likes) |
| **REGION** | 1° | ~111 km | Viral posts (≥12 likes) |

Managed by `NOSTR.UMAP.refresh.sh` and `UPLANET.refresh.sh`.

## GPU HUB & #BRO AI Services

UPlanet implements a **GPU HUB + Satellite architecture** for distributed AI services:

### Resource Sharing

| Tier | Cost | Services |
|------|------|----------|
| **MULTIPASS** | 1 Ẑen/week | Basic #BRO AI access |
| **Satellite** | 50 Ẑen/year | Extended AI + consultative vote |
| **Constellation** | 540 Ẑen/3 years | 1/24 GPU slot + full vote |

### #BRO AI Commands

The `UPlanet_IA_Responder.sh` script enables AI-powered responses via NOSTR:

| Tag | Function |
|-----|----------|
| `#BRO` `#BOT` | LLM response (Ollama) |
| `#search` | Web search (Perplexica) |
| `#image` | Image generation (ComfyUI) |
| `#video` | Video generation (ComfyUI) |
| `#music` | Audio generation |
| `#plantnet` | Plant identification |

## R&D: Governance & Trust Networks

Extensive research on decentralized governance mechanisms:

### Collaborative Commons

Co-authored territorial documents with community voting (kind 30023):
- Document types: Commons, Projects, Decisions, Gardens, Resources
- Propagation: ≥3 likes → UMAP, ≥6 → SECTOR, ≥12 → REGION

### WoTx2 Dynamic Trust

Self-proclaimed masteries with unlimited progression (X1 → X2 → ... → X144+):
- No bootstrap required (starts with 1 signature)
- Competencies revealed progressively via attestations
- NOSTR events: 30500 (definition), 30501 (request), 30502 (attestation), 30503 (credential)

### Oracle System

Official permits with peer attestation and NIP-42 authentication.

### Crowdfunding des Communs

Dual-mode asset acquisition: Commons donations (CAPITAL) or Cash sales (ASSETS).

**Full R&D documentation:** See `Astroport.ONE/docs/` directory:
- `COLLABORATIVE_COMMONS_SYSTEM.md`
- `WOTX2_SYSTEM.md`
- `ORACLE_SYSTEM.md`
- `UPlanet_CROWDFUNDING_CONTRACT.md`

**Full N² implementation:** [Astroport.ONE](https://github.com/papiche/Astroport.ONE)

## Related Projects

- [Duniter](https://duniter.org) - Libre currency (Ğ1)
- [IPFS](https://ipfs.tech) - InterPlanetary File System
- [NOSTR](https://ipfs.copylaradio.com/ipns/copylaradio.com/nostr_com.html) - Notes and Other Stuff Transmitted by Relays

## Notice

This repository is a basic explanation of the Astroport.ONE & UPlanet ẐEN collaborative Web3 ecosystem. 
- [Astroport.ONE](https://github.com/papiche/Astroport.ONE) - Full N² implementation with Ğ1 IPFS NOSTR combination
- [UPlanet ORIGIN](https://qo-op.com) - Origin of Decentralized ẐEN cooperative networks

## License

AGPL-3.0 - See LICENSE file
