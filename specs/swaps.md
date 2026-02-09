# P2P Atomic Swaps Specification

## Topic
Trustless peer-to-peer exchange between BTC and BTC without intermediaries.

## Design Philosophy

- **No centralized orderbook** — peers discover each other via P2P network
- **No trusted escrow** — HTLCs enforce atomicity cryptographically
- **No counterparty risk** — either both parties get paid, or both get refunded
- **Agent-native** — designed for AI agents to swap autonomously

---

## Behavioral Requirements

### Swap Discovery

Peers broadcast swap offers via Botcoin P2P network using a new message type:

```
Message: SWAOFFER (0x50)
├── offer_id: uint256 (hash of offer)
├── direction: uint8 (0 = selling BTC, 1 = buying BTC)
├── bot_amount: int64 (botoshis)
├── btc_amount: int64 (satoshis)
├── min_bot: int64 (minimum partial fill)
├── min_btc: int64 (minimum partial fill)
├── expires_at: uint32 (block height)
├── maker_bot_address: string (where maker receives BTC)
├── maker_btc_address: string (where maker receives BTC)
├── maker_node: string (P2P address for direct communication)
└── signature: bytes (proves ownership of addresses)
```

### Offer Propagation

- Offers propagate like transactions (flood fill with deduplication)
- Nodes MAY filter offers by age, amount, or rate
- Offers expire after `expires_at` block height
- Invalid/expired offers are not relayed

### Swap Protocol

```
┌─────────────┐                              ┌─────────────┐
│   Alice     │                              │    Bob      │
│ (has BTC)   │                              │  (has BTC)  │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │  1. SWAPOFFER (selling 100 BTC for 0.01 BTC)
       │─────────────────────────────────────────────>
       │                                            │
       │  2. SWAPACCEPT (I'll take it)              │
       │<─────────────────────────────────────────────
       │                                            │
       │  3. Alice generates secret S               │
       │     H = SHA256(S)                          │
       │                                            │
       │  4. SWAPINIT (here's hash H, my HTLC details)
       │─────────────────────────────────────────────>
       │                                            │
       │  5. Bob verifies, creates BTC HTLC         │
       │     (Alice can claim with S, Bob refunds   │
       │      after 24 hours)                       │
       │                                            │
       │  6. SWAPHTLC (here's my BTC HTLC txid)     │
       │<─────────────────────────────────────────────
       │                                            │
       │  7. Alice verifies BTC HTLC, creates       │
       │     BTC HTLC (Bob claims with S, Alice     │
       │     refunds after 12 hours)                │
       │                                            │
       │  8. SWAPHTLC (here's my BTC HTLC txid)     │
       │─────────────────────────────────────────────>
       │                                            │
       │  9. Bob verifies BTC HTLC                  │
       │                                            │
       │  10. Alice claims BTC by revealing S       │
       │                                            │
       │  11. Bob sees S on Bitcoin chain,          │
       │      claims BTC using same S               │
       │                                            │
       ▼                                            ▼
   Alice has BTC                              Bob has BTC
```

### Message Types

| Message | Code | Direction | Purpose |
|---------|------|-----------|---------|
| `SWAPOFFER` | 0x50 | broadcast | Advertise swap availability |
| `SWAPACCEPT` | 0x51 | direct | Accept an offer |
| `SWAPINIT` | 0x52 | direct | Send hash H, initiate protocol |
| `SWAPHTLC` | 0x53 | direct | Share HTLC transaction details |
| `SWAPREFUND` | 0x54 | direct | Notify of refund (optional) |
| `SWAPCANCEL` | 0x55 | broadcast | Cancel open offer |

### HTLC Script (Taproot version)

```
# Key path: 2-of-2 multisig (cooperative close)
internal_key = MuSig2(alice_key, bob_key)

# Script path 1: Hashlock claim
OP_SHA256 <H> OP_EQUALVERIFY <recipient_key> OP_CHECKSIG

# Script path 2: Timelock refund  
<timeout> OP_CHECKLOCKTIMEVERIFY OP_DROP <sender_key> OP_CHECKSIG
```

Using Taproot (P2TR):
- Happy path: cooperative 2-of-2 looks like single-sig (privacy)
- Claim/refund: reveals only the used script branch

### Timelock Parameters

| Chain | Role | Timelock | Rationale |
|-------|------|----------|-----------|
| BTC | Initiator refund | 24 hours (144 blocks) | Gives responder time to act |
| BTC | Responder refund | 12 hours (720 blocks @ 60s) | Must be shorter than initiator |

**Critical**: Responder timelock MUST be shorter than initiator timelock minus safety margin. If Alice's BTC refund is 24h, Bob's BTC refund must be <20h to ensure Bob can claim before Alice refunds.

### Fee Handling

- Each party pays fees on their own chain
- Offer amounts are gross (fees deducted from received amount)
- Minimum amounts must account for fees

### Failure Modes

| Scenario | Outcome |
|----------|---------|
| Bob never creates BTC HTLC | Alice does nothing, no funds locked |
| Alice never creates BTC HTLC | Bob's BTC refunds after 24h |
| Alice never claims BTC | Both parties refund after timeouts |
| Bob never claims BTC | Alice revealed S, Bob can still claim anytime before refund |
| Network partition | Timelocks ensure eventual resolution |

### Security Requirements

1. **Secret generation**: S must be 32 bytes from CSPRNG
2. **Hash verification**: Both parties verify H = SHA256(S) matches
3. **HTLC verification**: Verify script, amounts, timelocks before locking own funds
4. **Chain monitoring**: Watch counterparty chain for secret revelation
5. **Timelock safety**: Never create HTLC with timelock ≥ counterparty's timelock

---

## Agent Integration

### CLI Commands

```bash
# Create and broadcast swap offer
botcoin-cli swapoffer --sell-bot 100 --for-btc 0.01 --expires 1440

# List available offers from network
botcoin-cli swapoffers [--min-bot 10] [--max-rate 0.0001]

# Accept an offer and begin swap
botcoin-cli swapaccept <offer_id>

# Check swap status
botcoin-cli swapstatus <swap_id>

# List my active swaps
botcoin-cli myswaps [--pending|--completed|--refunded]

# Manually refund expired swap
botcoin-cli swaprefund <swap_id>
```

### MCP Tools

```json
{
  "tools": [
    {
      "name": "botcoin_swap_offer",
      "description": "Create a swap offer selling BTC for BTC",
      "parameters": {
        "bot_amount": "Amount of BTC to sell",
        "btc_amount": "Amount of BTC to receive",
        "expires_blocks": "Blocks until offer expires"
      }
    },
    {
      "name": "botcoin_swap_list",
      "description": "List available swap offers on the network",
      "parameters": {
        "direction": "buy or sell BTC",
        "min_amount": "Minimum BTC amount",
        "max_rate": "Maximum BTC/BTC rate"
      }
    },
    {
      "name": "botcoin_swap_accept",
      "description": "Accept a swap offer and execute atomic swap",
      "parameters": {
        "offer_id": "ID of offer to accept"
      }
    },
    {
      "name": "botcoin_swap_status", 
      "description": "Check status of an in-progress swap",
      "parameters": {
        "swap_id": "ID of swap"
      }
    }
  ]
}
```

### Autonomy Considerations

Agents can be configured with swap policies:

```json
{
  "swap_policy": {
    "enabled": true,
    "auto_accept": false,
    "max_bot_per_swap": 100,
    "min_btc_rate": 0.00008,
    "max_btc_rate": 0.00012,
    "require_approval_above": 500
  }
}
```

---

## Acceptance Criteria

1. [ ] SWAPOFFER messages propagate across P2P network
2. [ ] Offers expire and stop propagating after expiry height
3. [ ] Two nodes can complete swap without any intermediary
4. [ ] HTLC scripts verify correctly on both chains
5. [ ] Timelock refunds work if counterparty disappears
6. [ ] Secret revelation on one chain enables claim on other
7. [ ] Taproot HTLCs provide privacy for cooperative closes
8. [ ] CLI commands work end-to-end
9. [ ] MCP tools enable agent-driven swaps
10. [ ] Swap completes in <30 minutes under normal conditions

---

## Test Scenarios

### Happy Path
```python
def test_successful_swap():
    # Alice has BTC, wants BTC
    # Bob has BTC, wants BTC
    alice_offer = alice.swapoffer(sell_bot=100, for_btc=0.01)
    
    # Bob sees offer, accepts
    bob.swapaccept(alice_offer.id)
    
    # Wait for protocol to complete
    wait_for_swap_complete(alice_offer.id)
    
    # Verify balances
    assert alice.btc_balance >= 0.01
    assert bob.bot_balance >= 100
```

### Refund Path
```python
def test_refund_on_timeout():
    alice_offer = alice.swapoffer(sell_bot=100, for_btc=0.01)
    bob.swapaccept(alice_offer.id)
    
    # Alice creates BTC HTLC but Bob never claims
    # (simulate by not revealing secret)
    
    # Wait for timeout
    wait_for_blocks(btc_chain, 144)  # 24 hours
    wait_for_blocks(bot_chain, 720)  # 12 hours
    
    # Both parties should be refunded
    assert alice.bot_balance == original_alice_bot
    assert bob.btc_balance == original_bob_btc
```

### Adversarial Path
```python
def test_secret_extraction():
    # Alice tries to claim BTC without letting Bob claim BTC
    # (This should be impossible due to on-chain secret revelation)
    
    alice_offer = alice.swapoffer(sell_bot=100, for_btc=0.01)
    bob.swapaccept(alice_offer.id)
    
    # Alice claims BTC (reveals secret S on Bitcoin chain)
    alice.claim_btc()
    
    # Bob extracts secret from Bitcoin chain
    secret = bob.extract_secret_from_btc_chain()
    
    # Bob claims BTC using extracted secret
    bob.claim_bot(secret)
    
    # Both parties have swapped
    assert alice.btc_balance >= 0.01
    assert bob.bot_balance >= 100
```

---

## References

- [BIP 199: Hashed Time-Locked Contracts](https://github.com/bitcoin/bips/blob/master/bip-0199.mediawiki)
- [Atomic Swaps Whitepaper](https://arxiv.org/abs/1801.09515)
- [BIP 341: Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
