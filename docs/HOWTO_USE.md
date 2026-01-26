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

## Testing

ISBP-spec includes a comprehensive test suite to verify all functionality.

### Quick Test

```bash
# Run all tests
make test

# Run tests in quiet mode (summary only)
make test-quick

# Run tests with verbose output
make test-verbose

# Or run directly
./tests/run_all.sh
```

### Test Suites

| Test Suite | Description |
|------------|-------------|
| `test_keygen.sh` | Key generation and determinism |
| `test_wallet.sh` | Wallet balance operations |
| `test_economy.sh` | PAF payments and degradation phases |
| `test_cooperative.sh` | Tax and 3x1/3 allocation |
| `test_accounting.sh` | Double-entry accounting coherence |

### Example Output

```
╔═══════════════════════════════════════════════════════════════╗
║       🧪 ISBP - IPFS Station Beacon Protocol                  ║
║                   Test Suite                                  ║
╚═══════════════════════════════════════════════════════════════╝

  Testing keygen exists... PASS
  Testing key determinism... PASS
  Testing balance conservation... PASS
  ...

╔═══════════════════════════════════════════════════════════════╗
║                    📊 TEST SUMMARY                            ║
╠═══════════════════════════════════════════════════════════════╣
║  Total test suites:  5                                       ║
║  Passed:             5                                       ║
║  Failed:             0                                       ║
╠═══════════════════════════════════════════════════════════════╣
║  ✓ ALL TESTS PASSED                                          ║
╚═══════════════════════════════════════════════════════════════╝
```

## Makefile Commands

The project includes a Makefile for common operations:

```bash
# Show all available commands
make help

# Check dependencies
make check-deps

# Initialize environment
make init

# Run demo sequence
make demo

# Show wallet balances
make show-balances

# Clean temporary files
make clean
```

### All Available Commands

| Category | Command | Description |
|----------|---------|-------------|
| **Setup** | `make check-deps` | Check required dependencies |
| | `make install-deps` | Install dependencies (Debian/Ubuntu) |
| | `make init` | Initialize ISBP environment |
| **Testing** | `make test` | Run all tests |
| | `make test-quick` | Run tests (quiet mode) |
| | `make test-verbose` | Run tests with detailed output |
| **Demo** | `make demo` | Run complete demo sequence |
| | `make keys` | Generate demo keys |
| | `make beacon` | Start beacon server |
| | `make economy` | Run ZEN economy cycle |
| | `make cooperative` | Run cooperative allocation |
| **Simulation** | `make sim` | Run constellation economic simulation |
| | `make sim-small` | Small satellite (100 users, 1 station) |
| | `make sim-medium` | Regional constellation (500 users) |
| | `make sim-large` | Mega constellation (2000 users) |
| | `make sim-json` | Output simulation as JSON |
| | `make sim-html` | Open interactive HTML simulator |
| **Maintenance** | `make clean` | Clean generated files |
| | `make clean-all` | Clean everything (including ~/.isbp) |

### Demo Sequence

Run a complete demonstration of the economic cycle:

```bash
make demo
```

This will:
1. Initialize wallets with demo balances
2. Run cooperative allocation (tax + 3x1/3)
3. Run economy cycle (PAF payments)
4. Show final balances

### Accounting Verification

The demo ensures **accounting coherence**: total Ẑen across all wallets is conserved after every operation.

```bash
# After any economic operation
make show-balances
```

Example output:
```
Current wallet balances (~/.isbp/wallets/):

  uplanet.CASH:             241.33 Ẑen
  uplanet.ASSETS:           283.34 Ẑen
  uplanet.RnD:              283.33 Ẑen
  uplanet.IMPOT:            150.00 Ẑen
  secret.NODE:              14.00 Ẑen
  captain.MULTIPASS:        28.00 Ẑen
  ─────────────────────────────────
  TOTAL:                    1000.00 Ẑen
```

## Economic Simulation

ISBP-spec includes a comprehensive constellation economic simulator to model and validate business viability.

### Quick Simulation

```bash
# Run with default parameters (500 users, 5 stations)
make sim

# Predefined scenarios
make sim-small      # 100 users, 1 station, 1 dev
make sim-medium     # 500 users, 5 stations, 2 devs, 1 CM
make sim-large      # 2000 users, 15 stations, 5 devs, 3 CMs
```

### Custom Simulation

```bash
# Custom parameters
make sim USERS=1000 STATIONS=10 DEVS=3 CMS=2

# Full customization
make sim-custom USERS=1000 STATIONS=10 DEVS=3 CMS=2 PAF=14 MPCT=75

# JSON output (for integration)
make sim-json USERS=500 STATIONS=5

# CSV output
make sim-csv USERS=500 STATIONS=5
```

### Simulation Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `USERS` | Total users (MULTIPASS + ZEN Cards) | 500 |
| `STATIONS` | Number of stations (nodes) | 5 |
| `DEVS` | Number of developers | 2 |
| `CMS` | Number of community managers | 1 |
| `PAF` | Weekly infrastructure fee (Ẑen) | 14 |
| `MPCT` | Percentage of MULTIPASS users | 80 |

### Interactive HTML Simulator

Open the visual simulator in your browser:

```bash
make sim-html
```

Or open directly: `docs/simulator.html`

Features:
- Real-time parameter adjustment with sliders
- Preset scenarios (Small/Medium/Large)
- KPI dashboard (break-even, margin, jobs created)
- Financial projections (per cycle and yearly)
- 3×1/3 cooperative allocation visualization
- Ecological impact (forest acquisition)
- Viability assessment

### Understanding the Output

```
╔═══════════════════════════════════════════════════════════════════╗
║       🏛️ ISBP Constellation Economic Simulator                     ║
╚═══════════════════════════════════════════════════════════════════╝

📊 CONFIGURATION
  Total users:              500
  MULTIPASS:                400 (80%)
  ZEN Cards:                100 (20%)
  Stations:                 5
  Developers:               2
  Community Managers:       1

📈 CAPACITY
  Max MULTIPASS:            1250
  Max ZEN Cards:            120
  Utilization rate:         48.00%

💰 REVENUES (per 4-week cycle)
  MULTIPASS fees:           1600.00 Ẑ
  ZEN Card fees:            384.62 Ẑ
  Total (HT):               1587.69 Ẑ

💸 COSTS (per 4-week cycle)
  Captain wages (3×PAF):    840.00 Ẑ
  Developer salaries:       8680.00 Ẑ
  CM salaries:              1360.00 Ẑ

📊 RESULTS
  Gross margin:             747.69 Ẑ
  Net result:               -9292.31 Ẑ

🌱 3×1/3 ALLOCATION (when positive)
  🏦 Treasury (CASH):       1/3 of net result
  🔬 R&D:                   1/3 of net result
  🌳 Assets:                1/3 of net result → Forest acquisition

🎯 VIABILITY ASSESSMENT
  ✅ VIABLE - Positive net result within capacity
  ⚠️ OPERATIONAL - Reduce R&D or increase users
  ❌ NOT VIABLE - Insufficient revenue
```

### Economic Model

The simulator implements the ZEN Economy principles:

1. **Revenue Sources**:
   - MULTIPASS: Weekly fee × users × 4 weeks
   - ZEN Cards: Annual fee ÷ 13 cycles

2. **Cost Structure**:
   - Captain wages: 3 × PAF × stations × 4 weeks
   - Developer salaries: Monthly rate per dev
   - CM salaries: Monthly rate per CM

3. **Tax Calculation**:
   - 15% if result ≤ 42,500 Ẑ
   - 25% if result > 42,500 Ẑ

4. **Cooperative Allocation** (when profitable):
   - 1/3 → Treasury (CASH) - Operational reserve
   - 1/3 → R&D - Research & Development
   - 1/3 → Assets - Real assets (forest-gardens)

### Capacity Constraints

Each station can support:
- **250 MULTIPASS users** (10 GB uDRIVE each)
- **24 ZEN Card holders** (128 GB NextCloud each)

The simulator warns when capacity is exceeded.

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
