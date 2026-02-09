# Consensus Parameters Specification

## Topic
The consensus rules that govern block creation, rewards, and difficulty adjustment.

## Behavioral Requirements

### Block Timing
- Target block time: **60 seconds**
- Rationale: AI agents operate in real-time and need faster confirmations than Bitcoin's 10 minutes

### Block Rewards
- Initial block reward: **50 BTC**
- Halving interval: **2,100,000 blocks** (~4 years at 60s blocks)
- Maximum supply: **21,000,000 BTC** (matches Bitcoin's proven scarcity model)
- Smallest unit: **1 botoshi** = 0.00000001 BTC

### Difficulty Adjustment
- Retarget interval: **2016 blocks** (~1.4 days at 60s target)
- Target spacing: 60 seconds
- Maximum adjustment per period: **4x** (same as Bitcoin)
- Algorithm: Bitcoin's difficulty calculation, adjusted for 60s target

### Coinbase Maturity
- Coinbase outputs spendable after: **100 confirmations** (~100 minutes)

## Acceptance Criteria

1. [ ] Block at height 1 has reward of 50 BTC
2. [ ] Block at height 2,100,000 has reward of 25 BTC
3. [ ] Block at height 4,200,000 has reward of 12.5 BTC
4. [ ] Difficulty adjusts correctly when blocks are too fast (increases)
5. [ ] Difficulty adjusts correctly when blocks are too slow (decreases)
6. [ ] Difficulty cannot adjust more than 4x per retarget period
7. [ ] Total supply asymptotically approaches 21,000,000 BTC
8. [ ] Coinbase transaction is unspendable until 100 confirmations
9. [ ] Block timestamp validation allows reasonable clock drift

## Test Scenarios

- Generate 2016 blocks at varying speeds, verify difficulty adjusts correctly
- Mine past halving height, verify reward reduction
- Attempt to spend immature coinbase, verify rejection
- Calculate total supply after all halvings, verify approaches 21M
