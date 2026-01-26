# HOWTO: Using ISBP Demonstration Code

This guide explains how to use the ISBP-spec demonstration scripts to understand the protocol.

## Two Operating Modes

ISBP-spec supports two distinct operating modes:

### ORIGIN Mode (Public - Development)

**ORIGIN** is the public development mode for learning and testing. When no `swarm.key` is present, `uplanet_init.sh` automatically uses `ORIGIN` as the UPLANETNAME.

- Open to all developers and learners
- Shared public namespace
- Ideal for testing and experimentation
- No authentication required

### ẐEN Mode (Private - Production)

**ẐEN mode** is reserved for **Captains** who have completed the DRAGON training program and passed the certification tests.

**Required Training:**
- [GIT Formation](https://pad.p2p.legal/GIT) - Version control fundamentals
- [SHELL/BASH Formation](https://pad.p2p.legal/SHELL) - Script programming
- [Docker Formation](https://pad.p2p.legal/Docker#) - Container orchestration

**Infrastructure Skills:**
- [NextCloud Setup](https://pad.p2p.legal/NextCloud#) - Cloud storage deployment

Captains receive a private `swarm.key` that generates unique cooperative wallets for their constellation.

## Prerequisites

### System Requirements

- **Linux** (tested on Debian/Ubuntu)
- **IPFS Kubo** (v0.18+ recommended)
- **Python 3.8+** with pip
- **netcat-traditional** (nc) for beacon server
- **curl** for HTTP requests
- **jq** (optional, for JSON formatting)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/papiche/ISBP-spec.git
cd ISBP-spec

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Initialize IPFS with appropriate profile
# For LAN/low-power devices:
ipfs init -p lowpower

# For public servers:
ipfs init -p server

# 4. Start IPFS daemon with optimized settings
# CPU-limited daemon (recommended for shared systems):
ipfs daemon --migrate --enable-pubsub-experiment --enable-namesys-pubsub --routing=dhtclient &

# Or create a systemd service with CPU limits (production):
# See "Production IPFS Setup" section below

# 5. Make scripts executable
chmod +x beacon.sh examples/*.sh tools/*.sh
```

### Production IPFS Setup

For production deployments, configure IPFS as a systemd service with resource limits:

```bash
# Create systemd service file
sudo tee /etc/systemd/system/ipfs.service << 'EOF'
[Unit]
Description=IPFS daemon
After=network.target
Requires=network.target

[Service]
Type=simple
User=YOUR_USERNAME
RestartSec=1
Restart=always
Environment=IPFS_FD_MAX=8192
ExecStart=/usr/local/bin/ipfs daemon --migrate --enable-pubsub-experiment --enable-namesys-pubsub --routing=dhtclient
CPUAccounting=true
CPUQuota=60%
CPUAffinity=0-1

[Install]
WantedBy=multi-user.target
EOF

# Replace username and enable service
sudo sed -i "s/YOUR_USERNAME/$USER/g" /etc/systemd/system/ipfs.service
sudo systemctl daemon-reload
sudo systemctl enable ipfs
sudo systemctl start ipfs

# Increase file descriptor limits
echo "$USER soft nofile 100000" | sudo tee -a /etc/security/limits.conf
echo "$USER hard nofile 100000" | sudo tee -a /etc/security/limits.conf
```

**Key daemon options:**
- `--migrate` - Auto-migrate datastore on version updates
- `--enable-pubsub-experiment` - Enable PubSub for real-time messaging
- `--enable-namesys-pubsub` - Enable PubSub for IPNS resolution
- `--routing=dhtclient` - DHT client mode (LAN only, reduces CPU)

**Service limits:**
- `CPUQuota=60%` - Limit IPFS to 60% CPU
- `CPUAffinity=0-1` - Bind to specific CPU cores
- `IPFS_FD_MAX=8192` - Maximum file descriptors

## Quick Demo

### Step 1: Generate Twin Keys

Generate cryptographic keys for all supported protocols from a single seed:

```bash
./examples/generate_keys.sh
```

Interactive mode will prompt for SALT and PEPPER secrets:

```
═══════════════════════════════════════════════════════════
  ISBP Twin Key Generator
═══════════════════════════════════════════════════════════

Enter your seed (this will generate all your keys):

SALT (secret 1): mysecret123
PEPPER (secret 2): mypassword456
```

Or pass them as arguments:

```bash
./examples/generate_keys.sh "mysecret123" "mypassword456"
```

**Output:**
- IPFS PeerID (12D3KooW...)
- Duniter G1 Wallet (DsEx1pS...)
- SSH Public Key (ssh-ed25519...)
- Nostr npub (npub1...)
- Bitcoin Address (1... or 3...)

The script also verifies the **key binding** between IPFS PeerID and G1 wallet.

### Step 2: Start the Beacon Server

```bash
./beacon.sh
```

The beacon server will:
1. Get your IPFS node identity
2. Derive a MySwarm IPNS key
3. Start listening on port 12345
4. Sync with bootstrap nodes (background)
5. Publish beacon data to IPNS

**Console output:**
```
═══════════════════════════════════════════════════════════
  ISBP Beacon Server
═══════════════════════════════════════════════════════════
  IPFS Node ID: 12D3KooWxxxxxx...
  G1 Public Key: DsEx1pSxxxxxx...
  Public IP: 1.2.3.4
  Port: 12345
───────────────────────────────────────────────────────────
  Self Beacon: /ipns/12D3KooWxxxxxx...
  Swarm View:  /ipns/QmSwarmKey...
═══════════════════════════════════════════════════════════
```

### Step 3: Query a Beacon

From another terminal (or machine):

```bash
# Query local beacon
./examples/query_beacon.sh 127.0.0.1

# Query remote beacon
./examples/query_beacon.sh 192.168.1.100

# Query via HTTPS (reverse proxy)
./examples/query_beacon.sh node.example.com 443 /12345/
```

**Sample output:**
```json
{
    "version": "1.0",
    "protocol": "ISBP",
    "created": "20260126123456",
    "hostname": "my-station",
    "myIP": "1.2.3.4",
    "ipfsnodeid": "12D3KooWxxxxxx...",
    "g1pub": "DsEx1pSxxxxxx...",
    "g1station": "/ipns/12D3KooWxxxxxx...",
    "g1swarm": "/ipns/QmSwarmKey...",
    "swarm_members": 5,
    "services": {
        "ipfs": { "active": true, "peers": 42 },
        "beacon": { "active": true, "port": 12345 }
    }
}
```

### Step 4: Join a Swarm

Connect to bootstrap nodes and register your node:

```bash
./examples/join_swarm.sh
```

This script:
1. Reads bootstrap nodes from `bootstrap.txt`
2. Connects via IPFS swarm connect
3. Sends UPSYNC request (registers your G1PUB + IPFSNODEID)
4. Downloads swarm data from each bootstrap
5. Discovers other swarm members transitively

## Tools Reference

### keygen

Multi-format key generator from SALT/PEPPER seed:

```bash
# IPFS PeerID
./tools/keygen -t ipfs "SALT" "PEPPER"

# Duniter G1 Wallet
./tools/keygen -t duniter "SALT" "PEPPER"

# SSH keypair
./tools/keygen -t ssh "SALT" "PEPPER"

# Nostr npub (public)
./tools/keygen -t nostr "SALT" "PEPPER"

# Nostr nsec (secret)
./tools/keygen -t nostr -s "SALT" "PEPPER"

# Bitcoin address
./tools/keygen -t bitcoin "SALT" "PEPPER"

# Save to file
./tools/keygen -t ipfs -o mykey.pem "SALT" "PEPPER"
```

See `tools/keygen.readme.md` for full documentation.

### Key Converters

```bash
# IPFS PeerID → G1 Public Key
python3 tools/ipfs_to_g1.py 12D3KooWxxxxxx

# G1 Public Key → IPFS PeerID
python3 tools/g1_to_ipfs.py DsEx1pSxxxxxx
```

### Y-Level Activation

Unify SSH and IPFS identities (twin key entanglement):

```bash
./tools/ylevel.sh
```

This creates:
- `~/.isbp/secrets/ssh.key` - SSH private key
- `~/.isbp/secrets/ipfs.key` - IPFS private key
- `~/.isbp/secrets/duniter.key` - Duniter credentials
- `~/.isbp/secrets/nostr.key` - Nostr npub/nsec

## UPlanet ẐEN Economy (Optional)

If you want to explore the economic layer:

### Initialize Cooperative Wallets

```bash
./tools/uplanet_init.sh
```

Creates all cooperative wallets derived from `~/.ipfs/swarm.key`.

### Create User Tokens

```bash
# Create MULTIPASS (10 Go uDRIVE, 1 Ẑen/week)
./tools/multipass_create.sh user@example.com

# Create ZEN Card Satellite (128 Go, 50 Ẑen/year)
./tools/zencard_create.sh sponsor@example.com satellite

# Create ZEN Card Constellation (1/24 GPU, 540 Ẑen/3years)
./tools/zencard_create.sh vip@example.com constellation
```

### Weekly Automation

```bash
# Daily: uDRIVE refresh + fee collection
./tools/nostrcard_refresh.sh

# Weekly: PAF payment (CASH → NODE + CAPTAIN)
./tools/zen_economy.sh

# Weekly: 3x1/3 surplus allocation
./tools/zen_cooperative.sh
```

## Data Locations

| Directory | Content |
|-----------|---------|
| `~/.isbp/` | Main ISBP data directory |
| `~/.isbp/beacon.json` | Self beacon (published to IPNS) |
| `~/.isbp/secrets/` | Private keys and derivation secrets |
| `~/.isbp/swarm/` | Known swarm members (published to IPNS) |

## Troubleshooting

### IPFS daemon not running

```
ERROR: IPFS daemon not running
```

**Solution:** Start IPFS daemon first:
```bash
ipfs daemon &
```

### keygen not found

```
ERROR: keygen not found
```

**Solution:** Ensure keygen is executable:
```bash
chmod +x tools/keygen
```

### Python dependencies missing

```
ModuleNotFoundError: No module named 'base58'
```

**Solution:** Install requirements:
```bash
pip install -r requirements.txt
```

### Port already in use

```
nc: Address already in use
```

**Solution:** Kill existing beacon or use different port:
```bash
pkill -f "nc -l -p 12345"
# or
./beacon.sh 12346
```

### Bootstrap connection timeout

```
Connection timed out
```

**Causes:**
- Bootstrap node offline
- Firewall blocking port 4001 (IPFS) or 12345 (beacon)
- Network issues

**Solution:** Try other bootstrap nodes or check firewall rules.

## Next Steps

### Learning Path

1. **Study the protocol**: Read [README.md](../README.md) for full specification
2. **Explore the economy**: Read [ZEN_ECONOMY.md](ZEN_ECONOMY.md) for UPlanet ẐEN
3. **Full implementation**: Clone [Astroport.ONE](https://github.com/papiche/Astroport.ONE)
4. **Join UPlanet ORIGIN**: Visit [qo-op.com](https://qo-op.com)

### Captain Training (DRAGON Program)

To become a Captain and operate a ẐEN constellation, complete these formations:

| Formation | Topic | Link |
|-----------|-------|------|
| **GIT** | Version control | [pad.p2p.legal/GIT](https://pad.p2p.legal/GIT) |
| **SHELL** | Bash scripting | [pad.p2p.legal/SHELL](https://pad.p2p.legal/SHELL) |
| **Docker** | Container orchestration | [pad.p2p.legal/Docker](https://pad.p2p.legal/Docker#) |
| **NextCloud** | Cloud storage | [pad.p2p.legal/NextCloud](https://pad.p2p.legal/NextCloud#) |

### Developer Resources

**Extend Smart Contracts:**
Learn how to extend Astroport smart contracts and build decentralized applications:
- [Developer Platform](https://u.copylaradio.com/dev) - Interactive API documentation and examples

**Join TheSTI Team:**
Contribute to UPlanet development and join the technical infrastructure team:
- [TheSTI](https://pad.p2p.legal/TheSTI#) - Solutions Techniques & Infrastructures

### Community

- **GitHub**: [Astroport.ONE](https://github.com/papiche/Astroport.ONE)
- **UPlanet ORIGIN**: [qo-op.com](https://qo-op.com)
- **Ğ1 Community**: [duniter.org](https://duniter.org)

## License

AGPL-3.0 - See LICENSE file
