# UPlanet ẐEN Economy

## Overview

UPlanet ẐEN is a cooperative economic system built on top of ISBP. It adds:
- **Cooperative identity** via shared `swarm.key`
- **Role-based tokens** (MULTIPASS, ZEN Card, UPassport)
- **Automatic revenue distribution** (3x1/3 rule)
- **Captain/Armateur governance**

## Core Concepts

### UPlanet Identity

All nodes in the same UPlanet share the same `swarm.key`:

```bash
# The UPLANETNAME is the shared secret (last line of swarm.key)
UPLANETNAME=$(cat ~/.ipfs/swarm.key | tail -n 1)
```

This secret:
1. **Generates all cooperative wallets** deterministically
2. **Encrypts sensitive config** (AES-256-CBC)
3. **Authenticates swarm membership**

> **SECURITY**: Never share `swarm.key` publicly - it's the master secret.

### Roles

```
┌─────────────────────────────────────────────────────────────────┐
│                        UPlanet ẐEN                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  👨‍✈️ CAPTAIN (Operator)                                          │
│     • Maintains the station                                      │
│     • Receives 2x PAF/week (28 Ẑen)                             │
│     • Has MULTIPASS + ZEN Card                                   │
│                                                                  │
│  🚢 ARMATEUR (Resource Provider)                                 │
│     • Provides hardware (machine)                                │
│     • NODE wallet receives PAF/week (14 Ẑen)                    │
│     • Hardware value → CAPITAL wallet (amortization)            │
│                                                                  │
│  👤 USAGER (User)                                                │
│     • MULTIPASS: 1 Ẑen/week (10 Go uDRIVE)                      │
│     • ZEN Card: 4 Ẑen/week (128 Go NextCloud)                   │
│                                                                  │
│  ⭐ PARRAIN (Sponsor)                                            │
│     • 50 Ẑen/year contribution                                   │
│     • Premium services + consultative vote                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Token Types & Wallet Transfers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     TOKEN TYPES & WALLET FLOWS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ MULTIPASS (Usage - 1 Ẑen/week)                                          ││
│  │ Services: 10 Go uDRIVE + NOSTR identity                                 ││
│  │                                                                         ││
│  │ Wallet Flow:                                                            ││
│  │   UPLANETNAME_G1 → UPLANETNAME → USER_MULTIPASS                        ││
│  │                                                                         ││
│  │ Weekly Fee Collection:                                                  ││
│  │   USER_MULTIPASS → CAPTAIN_DEDICATED (HT)                              ││
│  │                  → UPLANETNAME_IMPOT (TVA 20%)                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ NextCloud Extension (Usage - 4 Ẑen/week)                                ││
│  │ Services: 128 Go NextCloud + TiddlyWiki                                 ││
│  │                                                                         ││
│  │ Wallet Flow:                                                            ││
│  │   UPLANETNAME_G1 → UPLANETNAME_SOCIETY → USER_ZENCARD                  ││
│  │                                                                         ││
│  │ Weekly Fee Collection:                                                  ││
│  │   USER_ZENCARD → CAPTAIN_DEDICATED (HT)                                ││
│  │                → UPLANETNAME_IMPOT (TVA 20%)                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ ZEN Card Satellite (Contribution - 50 Ẑen/year)                         ││
│  │ Services: NextCloud 128Go + Consultative vote                           ││
│  │                                                                         ││
│  │ Wallet Flow (3x1/3 allocation):                                         ││
│  │   UPLANETNAME_G1 → UPLANETNAME_SOCIETY → USER_ZENCARD                  ││
│  │                                                                         ││
│  │   USER_ZENCARD → UPLANETNAME_TREASURY (33.33%)                         ││
│  │                → UPLANETNAME_RND (33.33%)                              ││
│  │                → UPLANETNAME_ASSETS (33.34%)                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ ZEN Card Constellation (Contribution - 540 Ẑen/3years)                  ││
│  │ Services: 1/24 GPU access + Premium IA + Full vote                      ││
│  │                                                                         ││
│  │ Same 3x1/3 allocation as Satellite                                      ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Infrastructure Capital (Machine contribution)                           ││
│  │ Services: Armateur status + PAF income                                  ││
│  │                                                                         ││
│  │ Wallet Flow:                                                            ││
│  │   UPLANETNAME_G1 → USER_ZENCARD → UPLANETNAME_CAPITAL                  ││
│  │                                                                         ││
│  │ Depreciation (weekly over 156 weeks):                                   ││
│  │   UPLANETNAME_CAPITAL → UPLANETNAME_AMORTISSEMENT                      ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Token | Type | Price | Services |
|-------|------|-------|----------|
| **MULTIPASS** | Usage | 1 Ẑen/week | 10 Go uDRIVE, NOSTR identity |
| **NextCloud** | Usage | 4 Ẑen/week | 128 Go NextCloud, TiddlyWiki |
| **ZEN Card Satellite** | Contribution | 50 Ẑen/year | Premium + consultative vote |
| **ZEN Card Constellation** | Contribution | 540 Ẑen/3years | 1/24 GPU + full vote |
| **Infrastructure** | Capital | Variable | Armateur status + PAF |
| **UPassport** | Governance | Via WoT | Voting rights, KYC verified |

### Conversion Rate

```
1 Ğ1 (Duniter) = 10 Ẑen
1 Ẑen = 0.1 Ğ1

Formula: ZEN = (G1 - 1) × 10
(The -1 accounts for the primal 1 Ğ1 transaction)
```

## Cooperative Wallets

All wallets are derived from `UPLANETNAME`:

```
┌─────────────────────────────────────────────────────────────────┐
│                    WALLET ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  UPLANETNAME_G1 (Central Reserve)                               │
│       │                                                          │
│       ├──▶ UPLANETNAME (Services)                               │
│       │       └──▶ MULTIPASS wallets                            │
│       │                                                          │
│       ├──▶ UPLANETNAME_SOCIETY (Sponsors)                       │
│       │       └──▶ ZEN Card wallets                             │
│       │                                                          │
│       ├──▶ UPLANETNAME_TREASURY (CASH) ◀── 1/3 allocation       │
│       ├──▶ UPLANETNAME_RND (R&D) ◀────────── 1/3 allocation     │
│       ├──▶ UPLANETNAME_ASSETS ◀───────────── 1/3 allocation     │
│       │                                                          │
│       ├──▶ UPLANETNAME_IMPOT (Tax provisions)                   │
│       └──▶ UPLANETNAME_CAPITAL (Immobilizations)                │
│                                                                  │
│  PER-NODE WALLETS:                                               │
│  ├── NODE (Armateur revenue - PAF)                              │
│  ├── CAPTAIN_MULTIPASS (Personal wallet)                        │
│  └── CAPTAIN_DEDICATED (Collected fees)                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Economic Flows

### Weekly Cycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    WEEKLY ECONOMIC CYCLE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1️⃣ COLLECT FEES (NOSTRCARD.refresh.sh / PLAYER.refresh.sh)     │
│                                                                  │
│     MULTIPASS (1Ẑ) ──┬──▶ HT → CAPTAIN_DEDICATED                │
│     ZEN Card (4Ẑ)  ──┘   TVA (20%) → IMPOT                      │
│                                                                  │
│  2️⃣ PAY PAF (ZEN.ECONOMY.sh)                                    │
│                                                                  │
│     CASH ──┬──▶ NODE (14 Ẑen) - Armateur                        │
│            └──▶ CAPTAIN MULTIPASS (28 Ẑen) - Salary             │
│                                                                  │
│  3️⃣ 3x1/3 ALLOCATION (ZEN.COOPERATIVE.3x1-3.sh)                 │
│                                                                  │
│     CAPTAIN_DEDICATED (Surplus)                                  │
│            │                                                     │
│            ├──▶ IS provision (15-25%) → IMPOT                   │
│            │                                                     │
│            └──▶ Net Surplus                                      │
│                    ├──▶ 33.33% → TREASURY (CASH)                │
│                    ├──▶ 33.33% → RnD                            │
│                    └──▶ 33.34% → ASSETS                         │
│                                                                  │
│  4️⃣ BURN (Monthly)                                              │
│                                                                  │
│     NODE ──▶ UPLANETNAME_G1 ──▶ OpenCollective (€)              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### PAF (Participation Aux Frais)

```bash
PAF = 14 Ẑen/week  # Per station

Distribution:
- 1x PAF (14 Ẑen) → NODE (Armateur - hardware rent)
- 2x PAF (28 Ẑen) → CAPTAIN MULTIPASS (Operator salary)

Source cascade (if CASH insufficient):
Phase 0: CASH (Treasury) 🟢
Phase 1: ASSETS 🟡
Phase 2: RnD 🟠
Phase 3: FAILURE 🔴
```

## Degradation Phases

The system implements graceful degradation instead of sudden failure:

| Phase | Status | PAF Source | Impact |
|-------|--------|------------|--------|
| 0 | 🟢 Normal | CASH | All systems operational |
| 1 | 🟡 Growth slowdown | ASSETS | No new asset acquisition |
| 2 | 🟠 Innovation slowdown | RnD | R&D projects suspended |
| 3 | 🔴 Critical | None | Services stopped |

## Transaction References

All transactions are tagged for traceability:

```
UPLANET:{UPLANETG1PUB:0:8}:{TYPE}:{DETAILS}:{IPFSNODEID}

Types:
- ZENCOIN  : MULTIPASS credit
- CAPITAL  : Infrastructure contribution
- SOCIETY  : Sponsor contribution
- TREASURY : Treasury allocation
- RnD      : R&D allocation
- ASSETS   : Assets allocation
- ORE      : Environmental reward
- PERMIT   : WoT Dragon reward
```

## Configuration

### Local (.env)

Per-station configuration:
```bash
PAF=14                    # Weekly participation fee
MACHINE_VALUE_ZEN=500     # Hardware value
myRELAY=wss://relay.example.com
myIPFS=https://ipfs.example.com
```

### Cooperative (DID NOSTR)

Shared across all swarm stations (kind 30800):
```json
{
  "TVA_RATE": "20.0",
  "IS_RATE_REDUCED": "15.0",
  "IS_RATE_NORMAL": "25.0",
  "TREASURY_PERCENT": "33.33",
  "RND_PERCENT": "33.33",
  "ASSETS_PERCENT": "33.34",
  "ZENCARD_SATELLITE": "50",
  "ZENCARD_CONSTELLATION": "540"
}
```

## Integration with ISBP

The ZEN Economy extends ISBP with:

1. **Enhanced beacon.json**:
```json
{
  "economy": {
    "multipass_count": 50,
    "zencard_count": 12,
    "captain_zen": 1234.5,
    "treasury_zen": 567.8,
    "risk_level": "GREEN"
  }
}
```

2. **NOSTR events**:
   - kind 30800: Cooperative config (DID)
   - kind 30850: Economic health broadcast

3. **Solar time sync**: Payments staggered by longitude to avoid conflicts

## Quick Start

```bash
# 1. Generate UPlanet identity (same swarm.key on all nodes)
ipfs-swarm-key-gen > ~/.ipfs/swarm.key

# 2. Initialize cooperative wallets
./tools/uplanet_init.sh

# 3. Start beacon with economy
./beacon.sh

# 4. Create MULTIPASS for user
./tools/multipass_create.sh user@example.com

# 5. Create ZEN Card for sponsor
./tools/zencard_create.sh sponsor@example.com satellite
```

## Related Scripts

| Script | Function | Frequency |
|--------|----------|-----------|
| `uplanet_init.sh` | Initialize cooperative wallets | Once |
| `multipass_create.sh` | Create MULTIPASS (10 Go uDRIVE) | On demand |
| `zencard_create.sh` | Create ZEN Card (128 Go) | On demand |
| `nostrcard_refresh.sh` | uDRIVE update + fee collection | Daily |
| `zen_economy.sh` | PAF: CASH → NODE + CAPTAIN | Weekly |
| `zen_cooperative.sh` | 3x1/3 surplus allocation | Weekly |

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    WEEKLY AUTOMATION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DAILY: nostrcard_refresh.sh                                    │
│  ├── Update uDRIVE for each user                                │
│  ├── Publish to IPNS                                            │
│  └── Collect fees (every 7 days per user)                       │
│         USER_MULTIPASS → CAPTAIN_DEDICATED (HT)                 │
│                        → IMPOT (TVA 20%)                        │
│                                                                  │
│  WEEKLY: zen_economy.sh                                          │
│  ├── NODE: CASH → NODE (1x PAF = 14 Ẑen)                        │
│  └── CAPTAIN: CASH → CAPTAIN_MULTIPASS (2x PAF = 28 Ẑen)        │
│      Degradation: CASH → ASSETS → RnD → BANKRUPTCY              │
│                                                                  │
│  WEEKLY: zen_cooperative.sh                                      │
│  ├── Tax: CAPTAIN_DEDICATED → IMPOT (15-25%)                    │
│  └── 3x1/3: CAPTAIN_DEDICATED → TREASURY/RnD/ASSETS             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## NOSTR Economic Signaling (kind 30850)

The complete implementation broadcasts economic health to the **NOSTR constellation** using a custom event type (kind 30850). This enables:

- **Swarm-level visibility**: All stations share their economic state
- **Legal compliance**: Audit-ready reports with TVA/IS provisions
- **Progressive degradation alerts**: Phase 1/2/3 warnings broadcast to users
- **Solar time sync**: Payment execution spread across swarm by longitude

### NIP-101 Economic Health Extension

```json
{
  "kind": 30850,
  "pubkey": "<captain_hex>",
  "content": {
    "report_type": "economic_health",
    "station": {
      "ipfsnodeid": "12D3KooW...",
      "swarm_id": "<UPLANETG1PUB>",
      "geo": { "lat": 43.6, "lon": 1.43 },
      "sync": { "solar_offset": "14:32" }
    },
    "wallets": {
      "cash": { "balance_zen": 420 },
      "rnd": { "balance_zen": 180 },
      "assets": { "balance_zen": 250 }
    },
    "health": {
      "status": "healthy",
      "bilan": 42,
      "weeks_runway": 12,
      "risk_level": "low"
    },
    "capacity": {
      "multipass": { "used": 45, "total": 250 },
      "zencard": { "renters": 8, "owners": 4, "capacity": 24 }
    }
  },
  "tags": [
    ["d", "economic-health"],
    ["t", "uplanet"],
    ["constellation", "<swarm_id>"],
    ["health:status", "healthy"],
    ["balance:cash", "420"],
    ["sync:solar_offset", "14:32"]
  ]
}
```

### Solar Time Synchronization

To prevent concurrent blockchain transactions across the swarm, each station processes payments at **20h12 local solar time**:

```
┌────────────────────────────────────────────────────────────────┐
│             SOLAR TIME SYNC (N² Protocol)                      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Station A (Paris, LON=2.35)    → Runs at 20:12 UTC+0.16       │
│  Station B (Tokyo, LON=139.69) → Runs at 20:12 UTC+9.31        │
│  Station C (NYC, LON=-74.01)   → Runs at 20:12 UTC-4.93        │
│                                                                 │
│  Each station's solar offset is broadcast in kind 30850        │
│  Other stations can verify payment timing via blockchain       │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Health Status Phases

| Phase | Status | Trigger | Impact |
|-------|--------|---------|--------|
| 0 | `healthy` | CASH ≥ 3× PAF | Normal operation |
| 1 | `growth_slowdown` | CASH < 3× PAF, ASSETS > 0 | Using ASSETS |
| 2 | `innovation_slowdown` | ASSETS = 0, RnD > 0 | Using R&D |
| 3 | `bankrupt` | All wallets depleted | GAME OVER |

## UMAP Geographic Key System

The full implementation includes a **hierarchical geographic key system** for geolocalized content aggregation, managed by `NOSTR.UMAP.refresh.sh` and activated by `UPLANET.refresh.sh`.

### Geographic Levels

```
┌─────────────────────────────────────────────────────────────────┐
│                 UMAP GEOGRAPHIC HIERARCHY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  REGION (1° zone)           ~111 km × 111 km                    │
│  ├── Key: keygen "${UPLANETNAME}${REGION}" ...                  │
│  ├── ID: _${RLAT}_${RLON}   (e.g., _43_1)                       │
│  ├── Content: Highly liked messages (≥12 likes)                 │
│  └── 4 cartographic images (Map, zMap, Sat, zSat)               │
│      │                                                           │
│      ├── SECTOR (0.1° zone)    ~11 km × 11 km                   │
│      │   ├── Key: keygen "${UPLANETNAME}${SECTOR}" ...          │
│      │   ├── ID: _${SLAT}_${SLON}   (e.g., _43.6_1.4)          │
│      │   ├── Content: Liked messages (≥3 likes)                 │
│      │   └── 4 cartographic images                              │
│      │       │                                                   │
│      │       └── UMAP (0.01° zone)  ~1.1 km × 1.1 km           │
│      │           ├── Key: keygen "${UPLANETNAME}${LAT}" "..${LON}"│
│      │           ├── ID: _${LAT}_${LON}   (e.g., _43.60_1.43)  │
│      │           ├── NOSTR friends list (kind 3)                │
│      │           ├── AI journal summaries (kind 30023)          │
│      │           └── uMARKET ads (#market tags)                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Generation

Each geographic zone has its own **twin cryptographic keys** (G1 + NOSTR):

```bash
# UMAP key (0.01° precision) - ~1.1 km zone
UMAPG1PUB=$(keygen "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPNPUB=$(keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPNSEC=$(keygen -t nostr -s "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")

# SECTOR key (0.1° precision) - ~11 km zone
SECTOR="_${SLAT}_${SLON}"  # e.g., _43.6_1.4
SECTORG1PUB=$(keygen "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
SECTORHEX=$(nostr2hex.py $(keygen -t nostr "${UPLANETNAME}${SECTOR}" ...))

# REGION key (1° precision) - ~111 km zone
REGION="_${RLAT}_${RLON}"  # e.g., _43_1
REGIONG1PUB=$(keygen "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}")
REGIONHEX=$(nostr2hex.py $(keygen -t nostr "${UPLANETNAME}${REGION}" ...))
```

### Content Aggregation Flow

```
DAILY: UPLANET.refresh.sh
├── ZEN.ECONOMY.sh (PAF payments)
├── ORACLE.refresh.sh (permits)
└── NOSTR.UMAP.refresh.sh
    │
    ├── For each UMAP (_LAT_LON):
    │   ├── Collect friends messages (48h window)
    │   ├── AI summarization (if >10 msgs or >3000 chars)
    │   ├── Process #market tags → uMARKET JSON ads
    │   ├── Publish kind 3 (friends) + kind 30023 (journal)
    │   └── Generate interactive index.html
    │
    ├── For each SECTOR (_SLAT_SLON):
    │   ├── Aggregate liked messages (≥3 likes) from UMAPs
    │   ├── Generate 4 cartographic images
    │   ├── GPS-based manifest ownership (closest captain)
    │   └── Publish to NOSTR + IPFS
    │
    └── For each REGION (_RLAT_RLON):
        ├── Aggregate highly liked messages (≥12 likes)
        ├── Generate 4 cartographic images
        └── GPS-based manifest ownership
```

### GPS-Based Manifest Ownership

Only the **closest captain** (by Haversine distance) can create manifests for a geographic zone:

```bash
# Captain GPS from ~/.zen/game/nostr/${CAPTAINEMAIL}/GPS
LAT=43.60; LON=1.44;

# Haversine distance calculation determines ownership
# Prevents conflicts: one authoritative manifest per zone
# Manifest includes captain GPS for verification by other nodes
```

### Use Cases

| Level | Use Case | Example |
|-------|----------|---------|
| **UMAP** | Local community | Neighborhood events, local ads |
| **SECTOR** | City district | Popular posts from ~10 km² |
| **REGION** | Metropolitan area | Viral content from ~100 km² |

## GPU HUB & Satellite Resource Sharing

UPlanet implements a **hierarchical resource architecture** where GPU HUBs provide AI services to Satellite nodes (NextCloud extensions). This enables sophisticated AI features across the constellation.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  GPU HUB & SATELLITE ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    GPU HUB (Captain)                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │   Ollama    │  │   ComfyUI   │  │   Perplexica    │   │   │
│  │  │  (LLMs)     │  │   (Images)  │  │    (Search)     │   │   │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘   │   │
│  │         │                │                   │            │   │
│  │         └────────────────┼───────────────────┘            │   │
│  │                          │                                │   │
│  │                  ┌───────▼───────┐                        │   │
│  │                  │ #BRO Responder│                        │   │
│  │                  │ UPlanet_IA    │                        │   │
│  │                  │ _Responder.sh │                        │   │
│  │                  └───────────────┘                        │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│                             │ NOSTR relay (kind 1)               │
│  ┌──────────────────────────▼───────────────────────────────┐   │
│  │                   SATELLITES (NextCloud)                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │ Satellite A │  │ Satellite B │  │   Satellite C   │   │   │
│  │  │  128 Go NC  │  │  128 Go NC  │  │    128 Go NC    │   │   │
│  │  │  ZEN Card   │  │  ZEN Card   │  │    ZEN Card     │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  SERVICE TIERS:                                                  │
│  • MULTIPASS (1Ẑ/w): Basic #BRO access                          │
│  • Satellite (50Ẑ/y): Extended AI + consultative vote           │
│  • Constellation (540Ẑ/3y): 1/24 GPU slot + full vote           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### #BRO AI Responder

The `UPlanet_IA_Responder.sh` script provides intelligent responses to NOSTR messages tagged with `#BRO` or `#BOT`:

| Tag | Function | Description |
|-----|----------|-------------|
| `#BRO` `#BOT` | AI Response | Generates LLM response via Ollama |
| `#search` | Web Search | Perplexica-powered research |
| `#image` | Image Gen | ComfyUI image generation |
| `#video` | Video Gen | ComfyUI video generation |
| `#music` | Audio Gen | ComfyUI music generation |
| `#youtube` | Video DL | Download YouTube/Rumble (720p) |
| `#pierre` `#amelie` | TTS | Orpheus voice synthesis |
| `#plantnet` | Plant ID | PlantNet recognition from image |
| `#mem` `#rec` `#reset` | Memory | Conversation memory management |

### GPU Access Model

ZEN Card Constellation holders receive **1/24 GPU time slot** on the HUB:

```bash
# GPU slot assignment (from ZEN Card subscription)
# 24 slots × 540 Ẑen/3y = 12,960 Ẑen GPU capacity

USER_SLOT=$(( USER_INDEX % 24 ))
GPU_TIME_START=$(( USER_SLOT * 60 ))  # 60 min slots in rotation
```

## R&D: Participative Governance & Trust Networks

The UPlanet ecosystem includes extensive R&D on decentralized governance mechanisms.

### Collaborative Commons System

**Reference**: `Astroport.ONE/docs/COLLABORATIVE_COMMONS_SYSTEM.md`

Territorial participative governance through co-authored documents:

```
┌─────────────────────────────────────────────────────────────────┐
│                  COLLABORATIVE DOCUMENT WORKFLOW                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. PROPOSAL (kind 30023 - User signed)                         │
│     │                                                            │
│     ▼                                                            │
│  2. COMMUNITY VOTE (kind 7 - Likes)                             │
│     │                                                            │
│     ├── ≥3 likes  → UMAP official document                      │
│     ├── ≥6 likes  → SECTOR propagation                          │
│     └── ≥12 likes → REGION propagation                          │
│                                                                  │
│  3. ADOPTION (kind 30023 - UMAP signed)                         │
│     └── Document becomes official commons charter                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| Document Type | Icon | Example |
|---------------|------|---------|
| **Commons** | 🤝 | Neighborhood charter |
| **Project** | 🎯 | Shared garden creation |
| **Decision** | 🗳️ | Plaza naming vote |
| **Garden** | 🌱 | ORE planting calendar |
| **Resource** | 📦 | Shared tools inventory |

### WoTx2: Dynamic Trust Networks

**Reference**: `Astroport.ONE/docs/WOTX2_SYSTEM.md`

Self-proclaimed masteries with unlimited automatic progression:

```
┌─────────────────────────────────────────────────────────────────┐
│                     WOTX2 PROGRESSION SYSTEM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Level X1 (1 signature)                                          │
│     └─ 1 attestation → 30503 credential → Creates X2            │
│                                                                  │
│  Level X2 (2 signatures)                                         │
│     └─ 2 attestations → 30503 credential → Creates X3           │
│                                                                  │
│  Level Xn (n signatures)                                         │
│     └─ ... → Unlimited progression                               │
│                                                                  │
│  LABELS:                                                         │
│  • X1-X4:    Niveau Xn                                           │
│  • X5-X10:   Niveau Xn (Expert)                                  │
│  • X11-X50:  Niveau Xn (Maître)                                  │
│  • X51-X100: Niveau Xn (Grand Maître)                            │
│  • X101+:    Niveau Xn (Maître Absolu)                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| NOSTR Kind | Event Type | Purpose |
|------------|------------|---------|
| **30500** | Permit Definition | Mastery template |
| **30501** | Permit Request | Apprentice application |
| **30502** | Attestation | Master certification |
| **30503** | Credential | Verifiable W3C credential |

### Oracle System

**Reference**: `Astroport.ONE/docs/ORACLE_SYSTEM.md`

Official permits with peer attestation and NIP-42 authentication:

- **Official Permits**: Created by UPLANETNAME_G1 (admin)
- **Bootstrap**: N+1 signatures required to start
- **Progression**: Static levels with defined competencies
- **Use Cases**: Driver permits, ORE verifiers, medical certifications

### Crowdfunding des Communs

**Reference**: `Astroport.ONE/docs/UPlanet_CROWDFUNDING_CONTRACT.md`

Dual-mode acquisition protocol for shared assets:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CROWDFUNDING MODES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MODE 1: COMMONS DONATION                                        │
│  Owner → Non-convertible Ẑen → CAPITAL wallet                   │
│  Benefits: UPlanet network access, no € liquidity               │
│                                                                  │
│  MODE 2: CASH SALE                                               │
│  Owner → € equivalent → ASSETS wallet (or crowdfunding)          │
│  Benefits: € liquidity, immediate payment                        │
│                                                                  │
│  VOTE SYSTEM:                                                    │
│  • ASSETS usage requires member approval (kind 7)                │
│  • Threshold: 100 Ẑen total votes                                │
│  • Quorum: 10 distinct voters                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| NOSTR Kind | Event Type | Purpose |
|------------|------------|---------|
| **30023** | Campaign Doc | Markdown description |
| **30904** | Metadata | JSON for crowdfunding.html |
| **7** | Contribution | +Ẑen reaction |
| **7** | Vote | vote-assets approval |

### R&D Integration Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                  R&D MODULES INTEGRATION                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐        │
│  │ Collaborative│     │    WoTx2    │     │   Oracle    │        │
│  │   Commons    │     │   Dynamic   │     │   Static    │        │
│  │  (Documents) │     │   Trust     │     │   Permits   │        │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘        │
│         │                   │                   │                │
│         └───────────────────┼───────────────────┘                │
│                             │                                    │
│                     ┌───────▼───────┐                            │
│                     │  Crowdfunding │                            │
│                     │ des Communs   │                            │
│                     └───────────────┘                            │
│                             │                                    │
│                     ┌───────▼───────┐                            │
│                     │  GPU HUB #BRO │                            │
│                     │   AI Services │                            │
│                     └───────────────┘                            │
│                             │                                    │
│         ┌───────────────────┼───────────────────┐                │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐        │
│  │   NOSTR     │     │    IPFS     │     │     Ğ1      │        │
│  │  Signaling  │     │   Storage   │     │ Blockchain  │        │
│  └─────────────┘     └─────────────┘     └─────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Full Implementation - Astroport.ONE

The complete production implementation with **N² protocol** (NOSTR + IPFS + Ğ1) is available in **Astroport.ONE**:

```bash
git clone https://github.com/papiche/Astroport.ONE
```

### Core Scripts

| Script | Function |
|--------|----------|
| `RUNTIME/NOSTRCARD.refresh.sh` | Full uDRIVE + fee collection |
| `RUNTIME/ZEN.ECONOMY.sh` | PAF with progressive degradation |
| `RUNTIME/ZEN.COOPERATIVE.3x1-3.sh` | 3x1/3 + tax compliance |
| `RUNTIME/ECONOMY.broadcast.sh` | Kind 30850 NOSTR broadcast |
| `UPLANET.official.sh` | Official transfers (MULTIPASS, ORE, etc.) |

### N² Protocol Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 N² = NOSTR × NETWORK                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │    NOSTR     │    │    IPFS      │    │     Ğ1       │       │
│  │   Signaling  │ ⟷ │   Storage    │ ⟷ │  Blockchain  │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌─────────────────────────────────────────────────────┐        │
│  │              ISBP Beacon (port 12345)                │        │
│  │   JSON: swarm discovery + economic health + GPS      │        │
│  └─────────────────────────────────────────────────────┘        │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  NOSTR Events                             │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │ kind 30800  │ DID Document (identity + services)         │   │
│  │ kind 30850  │ Economic Health (wallets + revenue)        │   │
│  │ kind 30023  │ N² Journal (personal feed summary)         │   │
│  │ kind 1      │ Social posts (reactions = ẐEN income)      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 IPNS Publications                         │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │ /ipns/beacon_key  │ Self beacon + swarm view              │   │
│  │ /ipns/myswarm_key │ Discovered peers (transitive)         │   │
│  │ /ipns/user_key    │ uDRIVE content (10-128 Go)           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Astroport.ONE?

| Feature | ISBP-spec (demo) | Astroport.ONE |
|---------|------------------|---------------|
| Beacon | ✅ Basic | ✅ Full + IPNS |
| Twin Keys | ✅ Demo | ✅ Y-Level entanglement |
| PAF Payment | ✅ Simplified | ✅ + Degradation + Email |
| 3x1/3 | ✅ Simplified | ✅ + Tax + Email reports |
| uDRIVE | ❌ | ✅ IPFS + IPNS |
| NOSTR Signaling | ❌ | ✅ kind 30800/30850 |
| N² Journal | ❌ | ✅ AI-powered summaries |
| Solar Time Sync | ❌ | ✅ Distributed timing |
| Email Notifications | ❌ | ✅ Mailjet integration |
| Bankruptcy Alerts | ✅ Log only | ✅ Email + NOSTR |

### Getting Started with Astroport.ONE

```bash
# Install on Debian/Ubuntu
curl -s https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh | bash

# Initialize UPlanet with your swarm.key
./tools/UPLANET.install.sh

# Start the station
./12345.sh &
```

### Community

- **GitHub**: https://github.com/papiche/Astroport.ONE
- **Documentation**: https://astroport.one/docs
- **UPlanet**: https://qo-op.com
- **Ğ1 Community**: https://duniter.org

## License

AGPL-3.0 - Part of the UPlanet ẐEN ecosystem
