# Branding Specification

## Topic
The user-facing identity of Botcoin software, ensuring consistent naming throughout.

## Behavioral Requirements

### Product Name
- **Full name**: Botcoin Core
- **Currency name**: Botcoin
- **Ticker symbol**: BTC
- **Smallest unit**: botoshi (1 BTC = 100,000,000 botoshi)

### Binary Names
Users interact with these executables:
| Binary | Purpose |
|--------|---------|
| `botcoind` | Full node daemon |
| `botcoin-cli` | Command-line RPC client |
| `botcoin-qt` | GUI wallet (optional) |
| `botcoin-tx` | Transaction utility |
| `botcoin-wallet` | Wallet utility |

### Data Directory
Default locations where Botcoin stores data:
| OS | Path |
|----|------|
| Linux | `~/.botcoin/` |
| macOS | `~/Library/Application Support/Botcoin/` |
| Windows | `%APPDATA%\Botcoin\` |

### Configuration
- Config file: `botcoin.conf`
- PID file: `botcoind.pid`

### Version Identity
- Version string: `Botcoin Core version v0.1.0`
- User agent: `/Botcoin:0.1.0/`
- Protocol: Botcoin protocol

### User-Facing Text
All user-visible text must reference "Botcoin":
- Help messages (`--help`)
- Error messages
- RPC responses
- Log output
- Documentation

### No Bitcoin References
Users must never see "Bitcoin" in normal operation:
- No "BTC" in amount displays
- No "bitcoin" in paths or filenames
- No "satoshi" in unit names (use "botoshi")

## Acceptance Criteria

1. [ ] `botcoind --version` shows "Botcoin Core"
2. [ ] `botcoind --help` contains no "Bitcoin" references
3. [ ] Default data directory is `~/.botcoin` (Linux)
4. [ ] Config file is `botcoin.conf`
5. [ ] All RPC help text references "Botcoin"
6. [ ] Amount displays use "BTC" not "BTC"
7. [ ] Unit conversion uses "botoshi" not "satoshi"
8. [ ] Log files reference "Botcoin"
9. [ ] Error messages reference "Botcoin"
10. [ ] Man pages document "botcoin" commands

## Test Scenarios

- Run `botcoind --help`, grep for "bitcoin" (should find none)
- Check data directory creation path
- Verify config file naming
- Check RPC `getnetworkinfo` output for user agent
- Verify amount formatting in `getbalance` response
- Review all error messages for correct branding
