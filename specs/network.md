# Network Protocol Specification

## Topic
The peer-to-peer network protocol that enables Botcoin nodes to communicate.

## Behavioral Requirements

### Network Identification
Botcoin must be distinguishable from Bitcoin to prevent cross-chain confusion:

- **Network magic bytes** (4 bytes identifying protocol messages):
  - Mainnet: `0xB07C010E` 
  - Testnet: `0xB07C7E57`
  - Regtest: `0xB07C0000`

### Port Configuration
- **Mainnet P2P**: 8433
- **Mainnet RPC**: 8432
- **Testnet P2P**: 18433
- **Testnet RPC**: 18432
- **Regtest P2P**: 18544
- **Regtest RPC**: 18543

### DNS Seeds
Initial peer discovery via DNS seeds (to be configured at launch):
- seed1.botcoin.network
- seed2.botcoin.network
- seed3.botcoin.network

### Protocol Version
- Start at version **70100** (distinct from Bitcoin's current versions)
- User agent: `/Botcoin:0.1.0/`

### Message Protocol
- Retain Bitcoin's message structure
- All message types compatible with Bitcoin protocol
- Version handshake uses Botcoin network magic

## Acceptance Criteria

1. [ ] Botcoin node rejects connections with Bitcoin network magic
2. [ ] Bitcoin node rejects connections with Botcoin network magic
3. [ ] Mainnet listens on port 8433 by default
4. [ ] RPC server listens on port 8432 by default
5. [ ] Testnet uses separate ports (18433/18432)
6. [ ] User agent string contains "Botcoin"
7. [ ] Protocol version is 70100
8. [ ] DNS seed lookup returns valid Botcoin peers (post-launch)
9. [ ] Nodes can discover peers and maintain connections

## Test Scenarios

- Start two Botcoin nodes, verify they connect and sync
- Attempt Bitcoin node connection to Botcoin, verify rejection
- Verify correct ports in netstat/ss output
- Check user agent in peer info RPC response
