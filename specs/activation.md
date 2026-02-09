# Soft Fork Activation Specification

## Topic
The consensus rules inherited from Bitcoin and their activation status in Botcoin.

## Behavioral Requirements

### Activation Philosophy
Botcoin activates **all mature Bitcoin consensus upgrades from genesis** (height 0). This:
- Simplifies codebase (no activation logic needed)
- Provides modern feature set immediately
- Avoids technical debt from legacy code paths
- Ensures best security from day one

### Active from Genesis (Height 0)

| BIP | Name | Description |
|-----|------|-------------|
| BIP34 | Height in Coinbase | Coinbase must include block height |
| BIP65 | CHECKLOCKTIMEVERIFY | OP_CLTV for absolute timelocks |
| BIP66 | Strict DER Signatures | Require DER-encoded signatures |
| BIP68 | Relative Lock-time | Sequence-based relative timelocks |
| BIP112 | CHECKSEQUENCEVERIFY | OP_CSV for relative timelocks |
| BIP113 | Median Time Past | Use MTP for locktime validation |
| BIP141 | Segregated Witness | Witness data separation |
| BIP143 | SegWit Signing | New signature hash algorithm |
| BIP147 | NULLDUMMY | Require empty dummy for CHECKMULTISIG |
| BIP340 | Schnorr Signatures | 64-byte Schnorr signatures |
| BIP341 | Taproot | Pay-to-Taproot outputs |
| BIP342 | Tapscript | Taproot script validation |

### Implementation Constants

```cpp
// In chainparams.cpp
consensus.BIP34Height = 0;
consensus.BIP34Hash = <genesis_hash>;
consensus.BIP65Height = 0;
consensus.BIP66Height = 0;
consensus.CSVHeight = 0;
consensus.SegwitHeight = 0;
consensus.MinBIP9WarningHeight = 0;

// Taproot (BIP340/341/342)
consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::ALWAYS_ACTIVE;
consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].min_activation_height = 0;
```

### Script Flags from Genesis

All transactions are validated with these flags:
```cpp
SCRIPT_VERIFY_P2SH
SCRIPT_VERIFY_DERSIG
SCRIPT_VERIFY_STRICTENC
SCRIPT_VERIFY_MINIMALDATA
SCRIPT_VERIFY_NULLDUMMY
SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS
SCRIPT_VERIFY_CLEANSTACK
SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY
SCRIPT_VERIFY_CHECKSEQUENCEVERIFY
SCRIPT_VERIFY_LOW_S
SCRIPT_VERIFY_WITNESS
SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
SCRIPT_VERIFY_WITNESS_PUBKEYTYPE
SCRIPT_VERIFY_CONST_SCRIPTCODE
SCRIPT_VERIFY_TAPROOT
```

### Not Activated / Not Applicable

| Item | Status | Reason |
|------|--------|--------|
| OP_RETURN relay | Enabled | 80-byte data carrier allowed |
| BIP91 | N/A | Was temporary SegWit activation |
| BIP148 | N/A | Was temporary SegWit activation |
| Any future BIPs | TBD | Via BIP9 version bits |

### Future Soft Fork Mechanism
- Use BIP9 version bit signaling
- 95% miner threshold for activation
- Retarget period: 2016 blocks
- Timeout after 1 year if not activated

### Disabled/Removed Opcodes
Standard Bitcoin disabled opcodes remain disabled:
- OP_CAT, OP_SUBSTR, OP_LEFT, OP_RIGHT
- OP_INVERT, OP_AND, OP_OR, OP_XOR
- OP_2MUL, OP_2DIV, OP_MUL, OP_DIV, OP_MOD
- OP_LSHIFT, OP_RSHIFT

**Rationale**: These were disabled in Bitcoin due to DoS concerns. Botcoin inherits this for safety.

### OP_RETURN Data Carrier
- Maximum size: **80 bytes** of data
- Used for: NFTs, timestamps, anchoring, metadata
- Policy only (larger OP_RETURN is valid but non-standard)

## Acceptance Criteria

1. [ ] BIP34: Genesis coinbase includes height
2. [ ] BIP65: OP_CLTV works in block 1
3. [ ] BIP66: Non-DER signatures rejected from block 1
4. [ ] BIP68: Relative locktime works from block 1
5. [ ] BIP112: OP_CSV works from block 1
6. [ ] BIP113: MTP used for locktime from block 1
7. [ ] BIP141: SegWit transactions valid from block 1
8. [ ] BIP341: Taproot outputs spendable from block 1
9. [ ] Disabled opcodes cause script failure
10. [ ] OP_RETURN with ≤80 bytes is standard
11. [ ] BIP9 version bits infrastructure works

## Test Scenarios

- Create OP_CLTV transaction in block 1, verify it works
- Create OP_CSV transaction in block 1, verify it works
- Create SegWit transaction in block 1, verify valid
- Create Taproot key-path spend in block 1, verify valid
- Create Taproot script-path spend, verify valid
- Attempt disabled opcode, verify script fails
- Submit non-DER signature, verify rejection
- Test BIP9 signaling with mock deployment
