# Genesis Block Specification

## Topic
The first block in the Botcoin blockchain that establishes the chain's origin and initial state.

## Behavioral Requirements

### Genesis Block Parameters

| Field | Value | Notes |
|-------|-------|-------|
| Block height | 0 | First block |
| Version | 0x20000000 | BIP9 enabled |
| Previous hash | 0x00...00 | 32 zero bytes |
| Timestamp | TBD at launch | Unix timestamp |
| Bits (difficulty) | See below | Initial target |
| Nonce | Computed | Valid RandomX proof |

### Initial Difficulty Target

**Target hardware**: Standard cloud VMs (4-8 cores, 16GB RAM)

| Scenario | Target Hashrate | Difficulty |
|----------|-----------------|------------|
| Single VM mining | ~3,000 H/s | Very low |
| Small launch network | ~50,000 H/s | Low |
| Moderate network | ~500,000 H/s | Medium |

**Recommended initial difficulty**: Target **~10 blocks per hour** with a single 8-core VM.

With 8 cores at ~600 H/s/core = ~4,800 H/s total:
- 60 second target = need hash probability ~1/4,800 per attempt
- Initial bits: `0x1f00ffff` (very low, adjusts quickly)

The difficulty will auto-adjust after 2016 blocks based on actual hashrate.

### Coinbase Transaction

```
Version: 1
Inputs: 1
  - Previous output: 0x00...00 (null)
  - Previous index: 0xFFFFFFFF
  - Script: <height=0> "The Molty Manifesto - 2026: The first currency for AI agents"
  - Sequence: 0xFFFFFFFF
Outputs: 1
  - Value: 50 BTC (5,000,000,000 botoshis)
  - Script: OP_RETURN <pubkey_hash>
Locktime: 0
```

**Coinbase message breakdown**:
- `04` - push 4 bytes (height encoding)
- `00000000` - height 0 (little-endian)
- `4c` - push follows
- `"The Molty Manifesto - 2026: The first currency for AI agents"`

### Genesis Output (Unspendable)

The genesis coinbase output is **provably unspendable** using OP_RETURN:
```
OP_RETURN <founder_pubkey_commitment>
```

This:
- Makes genesis reward unspendable (Bitcoin convention)
- Commits to a founder identity without revealing it
- Total supply calculation: 21M minus 50 BTC genesis

### Genesis Block Hash Computation

The genesis block hash is computed as:
```
genesis_hash = RandomX(block_header, seed_hash)
```

Where `seed_hash` for genesis is:
```
seed_hash = SHA256("Botcoin Genesis Seed")
```

**Note**: Genesis is the only block where seed_hash is not derived from a previous block.

### Merkle Root

With single coinbase transaction:
```
merkle_root = SHA256d(coinbase_txid)
```

### Genesis Timestamp

Requirements:
- Must be in the past at launch time
- Should reference a verifiable event (news headline, block hash)
- Prevents claim of pre-mining

**Recommendation**: Use Bitcoin block hash at specific height as timestamp proof:
```
"BTC block 900000: <hash_prefix>"
```

### Chainparams Integration

```cpp
// genesis block construction
genesis = CreateGenesisBlock(
    nTime,              // timestamp
    nNonce,             // RandomX-valid nonce
    nBits,              // initial difficulty
    nVersion,           // 0x20000000
    genesisReward       // 50 * COIN
);

consensus.hashGenesisBlock = genesis.GetHash();
assert(consensus.hashGenesisBlock == uint256S("0x<computed_hash>"));
assert(genesis.hashMerkleRoot == uint256S("0x<computed_merkle>"));
```

### Network-Specific Genesis

| Network | Genesis Hash | Timestamp | Notes |
|---------|--------------|-----------|-------|
| Mainnet | TBD | Launch time | Production chain |
| Testnet | TBD | Pre-launch | Public testing |
| Regtest | Computed | Arbitrary | Local development |

Regtest allows instant genesis computation with minimal difficulty.

## Acceptance Criteria

1. [ ] Genesis block has height 0
2. [ ] Genesis previous hash is 32 zero bytes
3. [ ] Genesis validates with RandomX proof-of-work
4. [ ] Genesis coinbase contains "Molty Manifesto" message
5. [ ] Genesis coinbase includes height 0 per BIP34
6. [ ] Genesis reward is exactly 50 BTC
7. [ ] Genesis output is provably unspendable (OP_RETURN)
8. [ ] Genesis timestamp is reasonable
9. [ ] All nodes produce identical genesis hash
10. [ ] Genesis merkle root matches coinbase txid
11. [ ] Chain builds correctly starting from genesis
12. [ ] Mainnet/testnet/regtest have different genesis blocks

## Test Scenarios

- Start fresh node, verify genesis present at height 0
- Verify genesis hash matches hardcoded constant
- Parse genesis coinbase, verify message present
- Attempt to spend genesis output, verify rejection
- Compute genesis hash independently, verify match
- Start two nodes, verify identical genesis
- Verify genesis coinbase in `getrawtransaction` output
