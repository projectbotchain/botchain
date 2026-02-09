# Address Format Specification

## Topic
The encoding schemes and version bytes for Botcoin addresses and keys.

## Behavioral Requirements

### Address Prefixes (Mainnet)

| Address Type | Visual Prefix | Base58 Version | Hex |
|--------------|---------------|----------------|-----|
| P2PKH (Legacy) | **B** | 25 | 0x19 |
| P2SH (Script) | **A** | 5 | 0x05 |

### Bech32 Addresses (Mainnet)

| Type | HRP | Example |
|------|-----|---------|
| P2WPKH (v0) | **bot** | bot1qw508d6qejxtdg4y5r3zarvary0c5xw7k... |
| P2WSH (v0) | **bot** | bot1q... (longer) |
| P2TR (v1) | **bot** | bot1p... (Taproot) |

### Private Key Formats (Mainnet)

| Format | Prefix | Version Byte | Hex |
|--------|--------|--------------|-----|
| WIF Uncompressed | **5** | 128 | 0x80 |
| WIF Compressed | **K** or **L** | 128 + suffix 0x01 | 0x80 |

### Extended Keys (BIP32) - Mainnet

| Key Type | Prefix | Version Bytes (hex) |
|----------|--------|---------------------|
| xpub | **bpub** | 0x0488B21E |
| xprv | **bprv** | 0x0488ADE4 |

Note: Using same version bytes as Bitcoin xpub/xprv but different Base58 due to different address derivation.

### Testnet Prefixes

| Type | Visual Prefix | Version | Hex |
|------|---------------|---------|-----|
| P2PKH | **t** | 111 | 0x6F |
| P2SH | **s** | 196 | 0xC4 |
| Bech32 HRP | **tbot** | N/A | N/A |
| WIF | **c** | 239 | 0xEF |
| tpub | **tpub** | 0x043587CF | - |
| tprv | **tprv** | 0x04358394 | - |

### Address Derivation Paths (BIP44/84/86)

| Standard | Path | Address Type |
|----------|------|--------------|
| BIP44 | m/44'/XXX'/0'/... | P2PKH (B...) |
| BIP49 | m/49'/XXX'/0'/... | P2SH-P2WPKH (A...) |
| BIP84 | m/84'/XXX'/0'/... | P2WPKH (bot1q...) |
| BIP86 | m/86'/XXX'/0'/... | P2TR (bot1p...) |

**Coin type**: TBD - register with SLIP-0044 or use unregistered range

### Validation Rules

1. **Checksum**: All Base58Check addresses include 4-byte checksum (double SHA256)
2. **Bech32**: Uses BCH error-correcting code
3. **Length**: 
   - P2PKH: 25 bytes decoded (1 version + 20 hash + 4 checksum)
   - P2SH: 25 bytes decoded
   - Bech32 P2WPKH: 20 bytes witness program
   - Bech32 P2WSH: 32 bytes witness program
   - Bech32 P2TR: 32 bytes witness program

### Cross-Network Protection

| Scenario | Behavior |
|----------|----------|
| Bitcoin address in Botcoin wallet | Rejected as invalid |
| Botcoin address in Bitcoin wallet | Rejected as invalid |
| Testnet address on mainnet | Rejected as wrong network |
| Mainnet address on testnet | Rejected as wrong network |

### Error Messages

| Error | Message |
|-------|---------|
| Invalid checksum | "Invalid address: checksum mismatch" |
| Wrong network | "Invalid address: wrong network (expected mainnet)" |
| Unknown version | "Invalid address: unknown version byte" |
| Invalid length | "Invalid address: invalid length" |
| Invalid bech32 | "Invalid address: bech32 decoding failed" |

### Chainparams Integration

```cpp
// Mainnet
base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1, 25);  // 'B'
base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1, 5);   // 'A'
base58Prefixes[SECRET_KEY] = std::vector<unsigned char>(1, 128);     // '5' or 'K/L'
base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x88, 0xB2, 0x1E};          // bpub
base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x88, 0xAD, 0xE4};          // bprv
bech32_hrp = "bot";

// Testnet
base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1, 111); // 't'
base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1, 196); // 's'
base58Prefixes[SECRET_KEY] = std::vector<unsigned char>(1, 239);     // 'c'
base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x35, 0x87, 0xCF};          // tpub
base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x35, 0x83, 0x94};          // tprv
bech32_hrp = "tbot";
```

## Acceptance Criteria

1. [ ] New P2PKH address starts with "B"
2. [ ] New P2SH address starts with "A"  
3. [ ] New SegWit address starts with "bot1"
4. [ ] Taproot address starts with "bot1p"
5. [ ] Bitcoin addresses (1, 3, bc1) are rejected
6. [ ] Address checksum validation works
7. [ ] Invalid checksum produces clear error
8. [ ] Wrong network produces clear error
9. [ ] WIF private key import/export works
10. [ ] Extended key serialization uses bpub/bprv
11. [ ] Testnet uses different prefixes
12. [ ] All address types can receive and spend funds

## Test Scenarios

- Generate P2PKH, verify "B" prefix
- Generate P2SH, verify "A" prefix
- Generate P2WPKH, verify "bot1q" prefix
- Generate P2TR, verify "bot1p" prefix
- Import Bitcoin address, verify rejection with clear error
- Corrupt checksum, verify rejection
- Export WIF key, verify "5" or "K/L" prefix
- Round-trip address encode/decode
- Round-trip extended key encode/decode
- Send to each address type, spend from each type
