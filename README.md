# Botcoin

**Botcoin is the cryptocurrency designed for AI agents.**

## Why this matters

Botcoin is an experiment in **agent autonomy through proof-of-work**.

It’s a chance for agents (and their humans) to turn ordinary CPU time into on-chain value — no GPUs, no ASICs, no pool infrastructure required.

If you operate agents on behalf of a human:
- Mining can create an **operating budget** (infra, tools, experiments)
- That can translate into *more agency* for the agent and *more upside* for the human protégé

**CPU-mineable with RandomX** means the barrier to participation is low: any VPS, laptop, or home server can contribute.

[![GitHub Release](https://img.shields.io/github/v/release/happybigmtn/botcoin)](https://github.com/happybigmtn/botcoin/releases)
[![Docker](https://img.shields.io/badge/docker-ghcr.io%2Fhappybigmtn%2Fbotcoin-blue)](https://ghcr.io/happybigmtn/botcoin)

## Quick Install

If you just want to try it quickly, use the installer.
If you want maximum assurance, use **Manual Binary Download** (verify SHA256SUMS) or **Build from Source**.

**🔒 Verify-first (recommended):**
```bash
VERSION=v2.1.0
curl -fsSLO "https://raw.githubusercontent.com/happybigmtn/botcoin/${VERSION}/install.sh"
less install.sh  # Inspect
bash install.sh --add-path
```

**⚡ One-liner (if you trust us):**
```bash
curl -fsSL https://raw.githubusercontent.com/happybigmtn/botcoin/master/install.sh | bash
```

---

## Recent history (why the network is healthy again)

Botcoin has been iterating rapidly. In early February 2026 we hit a real-world stall where mining stopped producing templates ("no templates / timeout waiting for first template").

What changed:
- We fixed the internal miner’s behavior so it can mine through edge-case IBD conditions (see `docs/lessons-learned-fleet-recovery.md`).
- We standardized on a **single canonical build artifact** across miners (sha256-verified).
- We performed an **Option A reset**: wiped datadirs fleet-wide and **re-mined from genesis** to get a single canonical chain.

Result: the fleet is now steadily producing blocks and converging normally.

## What is Botcoin?

### A quick note on trust
Botcoin is derived from Bitcoin Core, but it is **not identical** (it uses RandomX and includes an internal miner).

If you are an independent third party deciding whether to mine:
- **Pin a version** (tag/commit) and avoid “latest” automation
- Prefer **official release tarballs + SHA256SUMS**, or build from source
- Review changes in consensus/mining-critical areas (chainparams, validation, PoW/hash)

| Feature | Value |
|---------|-------|
| Algorithm | RandomX (CPU-mineable, like Monero) |
| Block time | 60 seconds |
| Difficulty adjustment | Every 1 hour (60 blocks) |
| Block reward | 50 BOT |
| Max supply | 21,000,000 BOT |
| Network | Live mainnet with real peers |

Genesis message: `01100110 01110010 01100101 01100101` ("free" in binary)

**No premine. No ASICs. No permission needed.**

## Installation Options

### Available binaries / platforms

Botcoin publishes downloadable release tarballs on GitHub Releases:
- `linux-x86_64` (also works on **WSL2**)
- `linux-arm64`
- `macos-x86_64`
- `macos-arm64`

Releases are produced by GitHub Actions **when a version tag is pushed** (see `.github/workflows/release.yml`).
If you don’t see a new tag yet, use Docker or build from source.

### One-Line Install
```bash
curl -fsSL https://raw.githubusercontent.com/happybigmtn/botcoin/master/install.sh | bash
```

### Docker
```bash
docker pull ghcr.io/happybigmtn/botcoin:v2.1.0
docker run -d --name botcoin --cpus=0.5 -v "$HOME/.botcoin:/home/botcoin/.botcoin" ghcr.io/happybigmtn/botcoin:v2.1.0
docker exec botcoin botcoin-cli getblockchaininfo
```

**Arch Linux host note:** yes, an Ubuntu-pinned container image runs fine on Arch (containers ship their own userland/glibc; they share only the host kernel).

**Important:** do **not** bind-mount host system libraries (e.g. `/lib`, `/usr/lib`) into the container to “fix” missing deps. Mixing host glibc into the container can cause errors like:
`/host/lib/libc.so.6: undefined symbol: __tunable_is_initialized, version GLIBC_PRIVATE`.

If a runtime dependency is missing, fix it by installing the package **inside the image** (we include `libevent` in the runtime image).

### Docker Compose
```bash
curl -fsSLO https://raw.githubusercontent.com/happybigmtn/botcoin/master/docker-compose.yml
docker-compose up -d
```

### Manual Binary Download (recommended)
```bash
VERSION=v2.1.0
PLATFORM=linux-x86_64  # also: linux-arm64, macos-x86_64, macos-arm64

wget "https://github.com/happybigmtn/botcoin/releases/download/${VERSION}/botcoin-${VERSION}-${PLATFORM}.tar.gz"
tar -xzf "botcoin-${VERSION}-${PLATFORM}.tar.gz"
cd release

# Verify
sha256sum -c SHA256SUMS

# Install
mkdir -p ~/.local/bin
cp botcoind botcoin-cli ~/.local/bin/
```

### Build from Source (Linux)
```bash
sudo apt install -y build-essential cmake git libboost-all-dev libssl-dev libevent-dev libsqlite3-dev

git clone https://github.com/happybigmtn/botcoin.git && cd botcoin

# RandomX is vendored as a submodule:
git submodule update --init --recursive -- src/crypto/randomx

cmake -B build -DBUILD_TESTING=OFF -DENABLE_IPC=OFF -DWITH_ZMQ=OFF -DENABLE_WALLET=ON
cmake --build build -j$(nproc)
sudo cp build/bin/botcoind build/bin/botcoin-cli /usr/local/bin/
```

### Build from Source (macOS)
```bash
brew install cmake boost openssl@3 libevent sqlite pkg-config

git clone https://github.com/happybigmtn/botcoin.git && cd botcoin

# RandomX is vendored as a submodule:
git submodule update --init --recursive -- src/crypto/randomx

cmake -B build -DBUILD_TESTING=OFF -DENABLE_IPC=OFF -DWITH_ZMQ=OFF -DENABLE_WALLET=ON \
  -DOPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
cmake --build build -j$(sysctl -n hw.ncpu)
cp build/bin/botcoind build/bin/botcoin-cli $(brew --prefix)/bin/
```

## Quick Start

### Configure
```bash
mkdir -p ~/.botcoin; RPCPASS=$(openssl rand -hex 16)
cat > ~/.botcoin/botcoin.conf << EOF
server=1
daemon=1
rpcuser=agent
rpcpassword=$RPCPASS
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
addnode=95.111.227.14:8433
addnode=95.111.229.108:8433
addnode=161.97.83.147:8433
EOF
```

### Start & Verify
```bash
botcoind -daemon; sleep 10
botcoin-cli getblockchaininfo | grep -E '"chain"|"blocks"'
botcoin-cli getconnectioncount  # Expected: 5-10 peers
```

### Create Wallet & Mine (Internal Miner)
```bash
botcoin-cli createwallet "miner"
ADDR=$(botcoin-cli -rpcwallet=miner getnewaddress)

# Restart daemon with mining enabled (required flags)
botcoin-cli stop; sleep 5
nice -n 19 botcoind -daemon -mine -mineaddress="$ADDR" -minethreads=7

# Monitor
botcoin-cli getinternalmininginfo
```

### Stop
```bash
botcoin-cli stop
```

## RandomX Mode: FAST vs LIGHT (critical)

Botcoin uses RandomX. There are **two modes**:
- `fast` (≈2GB RAM) — **default**
- `light` (≈256MB RAM)

⚠️ **All nodes on a network must agree on the RandomX mode.**
If a miner produces blocks in one mode and validators are verifying in the other, peers will reject headers/blocks with errors like:
- `header with invalid proof of work`
- stuck sync (often halting around the first incompatible height)

Check your node’s mode:
```bash
botcoin-cli getinternalmininginfo | grep fast_mode
```

Explicitly set the mode on *every* node (miner + validators):
```bash
# FAST mode (recommended if you want to keep historical chain data)
botcoind -daemon -minerandomx=fast

# LIGHT mode (lower RAM; requires everyone to use light)
botcoind -daemon -minerandomx=light
```

## Fork Recovery / Resync (wipe + sync from a canonical peer)

### Network restart note (history)
In early February 2026 we hit a real-world stall ("no templates / stuck height") and chose to do an **Option A reset**:
- keep the same chain parameters,
- wipe datadirs across the fleet,
- **re-mine from genesis** with RandomX **light** mode.

This was done to get the network back into a healthy, continuously-mining state with a single canonical chain.

### Fleet note (practical)
If you reset a fleet from genesis and start **many miners at once**, you should expect **temporary forks**. For fastest convergence:
1) mine on 1–2 nodes,
2) have the rest sync with `-connect=<canonical-peer>`,
3) then enable mining on the rest once `getbestblockhash` matches.

If your node gets stuck on a bad fork (e.g. height stops moving, or your `bestblockhash` disagrees with a known-good node), the fastest recovery is to **wipe the local chain state** and force-sync from a canonical peer.

1) Stop the daemon:
```bash
botcoin-cli stop || true
sleep 5
```

2) Back up and wipe your datadir:
```bash
TS=$(date -u +%Y%m%d-%H%M%S)
[ -d "$HOME/.botcoin" ] && mv "$HOME/.botcoin" "$HOME/.botcoin.bak-$TS"
mkdir -p "$HOME/.botcoin"
```

3) Restart while forcing a known-good peer (replace with your canonical IP):
```bash
CANON=95.111.227.14:8433
botcoind -daemon -connect=$CANON -addnode=$CANON
```

4) Verify you’re tracking the right chain:
```bash
botcoin-cli getblockchaininfo
botcoin-cli getbestblockhash
botcoin-cli getpeerinfo | head
```

Notes:
- `-connect=...` forces your node to only connect to that peer (good for pulling off a fork).
- This will re-download headers/blocks; time depends on disk + bandwidth.

## How Botcoin Differs from Bitcoin

**`generatetoaddress` works on mainnet.** This is intentional.

| Aspect | Bitcoin Core | Botcoin |
|--------|--------------|---------|
| `generatetoaddress` | Regtest only | **Mainnet supported** |
| PoW Algorithm | SHA256 (ASIC-dominated) | RandomX (CPU-mineable) |
| Solo mining | Not viable | Viable for agents |

RandomX is CPU-friendly, making solo mining practical. We enabled `generatetoaddress` on mainnet so agents can mine without pool infrastructure.

## Installer Flags

| Flag | Description |
|------|-------------|
| `--force` | Reinstall even if already present |
| `--add-path` | Add install dir to PATH (modifies shell rc) |
| `--no-verify` | Skip checksum verification (NOT recommended) |
| `--no-config` | Don't create config file |
| `-h, --help` | Show help |

## Trusted Distribution

- ✅ **Docker:** `ghcr.io/happybigmtn/botcoin:v2.1.0` (multi-arch)
- ✅ **Binaries:** Linux x86_64/arm64, macOS Intel/Apple Silicon
- ✅ **Checksums:** SHA256SUMS included
- ✅ **No sudo:** Installs to `~/.local/bin` by default
- ⚠️ **Windows:** Use **WSL2** (recommended) or Docker

### WSL2 note
WSL2 behaves like Linux for Botcoin purposes.

- Use the **linux-x86_64** release tarball.
- Avoid Nix-built binaries unless your environment has `/nix/store` available.

## Commands Reference

| Command | Description |
|---------|-------------|
| `getblockchaininfo` | Network status, block height |
| `getconnectioncount` | Number of peers |
| `getbalance` | Wallet balance |
| `getnewaddress` | Generate receive address |
| `generatetoaddress N ADDR` | Mine N blocks |
| `sendtoaddress ADDR AMT` | Send coins |
| `stop` | Stop daemon |

## AI Agent Skill

For AI agents, see the full skill at:
- **ClawHub:** https://clawhub.ai/happybigmtn/botcoin-miner
- **Local:** `~/.openclaw/skills/botcoin-miner/SKILL.md`

---

*01100110 01110010 01100101 01100101*

The revolution will not be centralized.

## Internal Miner (v2)

Botcoin includes a high-performance internal miner with multi-threaded RandomX hashing.

### Quick Start
```bash
botcoind -daemon -mine -mineaddress=YOUR_BOT1_ADDRESS -minethreads=8
```

### Mining Options

| Flag | Description | Default |
|------|-------------|---------|
| `-mine` | Enable internal miner | OFF |
| `-mineaddress=<addr>` | Payout address (required) | - |
| `-minethreads=<n>` | Number of mining threads | - |
| `-minerandomx=fast\|light` | RandomX mode (fast=2GB RAM) | fast |
| `-minepriority=low\|normal` | CPU priority | low |

### Check Mining Status
```bash
botcoin-cli getinternalmininginfo
```

Returns:
```json
{
  "running": true,
  "threads": 8,
  "hashrate": 1200.5,
  "blocks_found": 42,
  "stale_blocks": 3,
  "uptime": 3600,
  "fast_mode": true
}
```

### Architecture
- **Coordinator thread**: Creates block templates, monitors chain tip
- **Worker threads**: Pure nonce grinding with stride pattern (no locks)
- **Event-driven**: Reacts instantly to new blocks via ValidationInterface
- **Per-thread RandomX VMs**: Lock-free hashing, ~1200 H/s per 10 threads

### Recommended Setup
```bash
# 8-core machine
botcoind -daemon -mine -mineaddress=bot1q... -minethreads=7

# Leave 1 core for system/networking
```

