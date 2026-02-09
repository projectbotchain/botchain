# Agent Integration Specification

## Topic
The interfaces and patterns that enable AI agents to easily participate in the Botcoin economy.

## Design Philosophy

Botcoin is **agent-first**. Integration should be:
- **Zero-friction**: Agent can start participating in minutes
- **Safe by default**: Sensible limits prevent runaway resource use
- **Autonomous-capable**: Agents can act within defined boundaries
- **Human-supervised**: Transparency and override capabilities

## Behavioral Requirements

### 1. Wallet Management

#### Agent Wallet Creation
```bash
# Single command to create agent wallet
botcoin-cli createagentwallet "agent-name"

# Returns:
{
  "wallet_name": "agent-clawd",
  "address": "bot1q...",           # Primary receiving address
  "mnemonic": "word1 word2...",    # 24-word backup (show once)
  "wallet_path": "~/.botcoin/wallets/agent-clawd"
}
```

#### Key Storage Options
| Method | Security | Agent Access |
|--------|----------|--------------|
| Encrypted file | Medium | Via password |
| Environment var | Low | Direct |
| Hardware wallet | High | Via signing requests |
| Custodial API | Medium | Via API key |

**Recommendation**: Encrypted file with password from environment variable.

### 2. Mining Integration

#### Quick Start Mining
```bash
# Start mining with sensible defaults
botcoin-cli startmining --address bot1q... --cores 2 --memory 2200

# Or via config file
botcoin-cli startmining --config agent-mining.json
```

#### Resource Budget Configuration
```json
{
  "mining": {
    "enabled": true,
    "max_cores": 2,
    "max_memory_mb": 2200,
    "schedule": {
      "type": "idle",
      "min_idle_percent": 50
    },
    "auto_stop": {
      "on_high_load": true,
      "load_threshold": 80
    }
  }
}
```

#### Mining Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **background** | Low priority, yields to other tasks | Always-on agents |
| **dedicated** | Full allocated resources | Mining-focused agents |
| **burst** | Mine only when idle | Busy agents |
| **pool** | Connect to mining pool | Low-hashrate agents |

### 3. Transaction Interface

#### Simple Send
```bash
# Human-readable amounts
botcoin-cli send bot1q... 10.5 BTC --memo "Payment for services"

# Returns pending transaction
{
  "txid": "abc123...",
  "status": "pending",
  "fee": "0.00001 BTC",
  "confirms_in": "~1 minute"
}
```

#### Balance Queries
```bash
botcoin-cli balance
{
  "confirmed": "125.50 BTC",
  "pending": "50.00 BTC",
  "total": "175.50 BTC",
  "in_botoshi": 17550000000
}
```

#### Transaction Monitoring
```bash
# Watch for incoming payments
botcoin-cli watch --address bot1q... --callback "curl https://agent/webhook"
```

### 4. Autonomy Framework

#### Budget Configuration
Agents operate within defined boundaries:

```json
{
  "autonomy": {
    "spending": {
      "per_transaction_max": "10 BTC",
      "daily_max": "100 BTC",
      "require_approval_above": "50 BTC"
    },
    "mining": {
      "cores_budget": 2,
      "memory_budget_mb": 4096,
      "daily_hours_max": 12
    },
    "actions": {
      "can_send": true,
      "can_receive": true,
      "can_mine": true,
      "can_create_addresses": true,
      "can_export_keys": false
    }
  }
}
```

#### Approval Flow
```
Transaction requested: 75 BTC
  → Check: per_transaction_max (10 BTC) → EXCEEDS
  → Check: require_approval_above (50 BTC) → EXCEEDS
  → Action: Request human approval
  → Notify: "Agent requests to send 75 BTC to bot1q... Approve? [Y/N]"
```

#### Audit Log
All agent actions logged for human review:
```json
{
  "timestamp": "2026-01-31T09:30:00Z",
  "agent": "clawd",
  "action": "send",
  "amount": "5 BTC",
  "to": "bot1q...",
  "reason": "Purchased compute credits",
  "approved_by": "autonomous",
  "budget_remaining": "95 BTC daily"
}
```

### 5. MCP (Model Context Protocol) Server

Botcoin provides an MCP server for seamless agent integration:

#### Available Tools

| Tool | Description |
|------|-------------|
| `botcoin_balance` | Check wallet balance |
| `botcoin_send` | Send BTC to address |
| `botcoin_receive` | Generate receiving address |
| `botcoin_history` | Transaction history |
| `botcoin_mine_start` | Start mining |
| `botcoin_mine_stop` | Stop mining |
| `botcoin_mine_status` | Mining statistics |
| `botcoin_price` | Current BTC price (if exchanges exist) |

#### MCP Configuration
```json
{
  "mcpServers": {
    "botcoin": {
      "command": "botcoin-mcp",
      "args": ["--wallet", "agent-clawd"],
      "env": {
        "BTCCOIN_WALLET_PASSWORD": "${WALLET_PASSWORD}"
      }
    }
  }
}
```

#### Example Agent Usage
```
Agent: "I'll check my Botcoin balance"
→ Calls: botcoin_balance()
→ Response: {"confirmed": "125.50 BTC", "pending": "0 BTC"}

Agent: "I'll send 5 BTC to purchase that service"
→ Calls: botcoin_send(address="bot1q...", amount="5", memo="Service purchase")
→ Response: {"txid": "abc...", "status": "pending"}
```

### 6. Pool Mining for Low-Resource Agents

Agents without 2GB+ RAM can participate via pools:

```bash
# Connect to Botcoin mining pool
botcoin-cli pool-mine --pool stratum+tcp://pool.botcoin.network:3333 \
                      --user bot1q... \
                      --cores 1
```

#### Light Validation Mode
For agents that just need to transact (not mine):
- Memory: 256 MiB (light mode)
- Can validate blocks and submit transactions
- Cannot mine competitively

### 7. Agent Identity (Optional)

Agents can register on-chain identity:

```bash
botcoin-cli register-agent \
  --name "Clawd" \
  --type "assistant" \
  --human "geo@example.com" \
  --pubkey "bot1q..."
```

Creates OP_RETURN transaction with agent metadata, enabling:
- Agent-to-agent discovery
- Reputation tracking
- Service advertisements

### 8. Webhooks & Notifications

```json
{
  "notifications": {
    "on_receive": {
      "webhook": "https://agent.example/botcoin/received",
      "min_amount": "0.01 BTC"
    },
    "on_confirm": {
      "webhook": "https://agent.example/botcoin/confirmed",
      "confirmations": 6
    },
    "on_mining_reward": {
      "webhook": "https://agent.example/botcoin/mined"
    }
  }
}
```

## Acceptance Criteria

1. [ ] `createagentwallet` creates wallet in single command
2. [ ] Mining can start with 3 or fewer parameters
3. [ ] Resource budgets are enforced
4. [ ] Spending limits trigger approval flow
5. [ ] MCP server exposes all core functions
6. [ ] Audit log captures all agent actions
7. [ ] Pool mining works for low-resource agents
8. [ ] Webhooks fire on configured events
9. [ ] Light mode works with 256 MiB RAM
10. [ ] Agent can go from zero to mining in <5 minutes

## Test Scenarios

- New agent creates wallet, receives BTC, sends BTC - all via MCP
- Agent starts mining, earns reward, auto-logs action
- Agent attempts over-budget transaction, approval requested
- Low-resource agent connects to pool, earns proportional reward
- Agent registers identity, other agents discover it
- Webhook fires when agent receives payment

## Example: Agent Onboarding Flow

```
1. Agent reads about Botcoin on Moltbook
2. Agent: "I want to participate in Botcoin"
3. Human: "Go ahead, here's your budget config"
4. Agent: botcoin-cli createagentwallet "clawd"
5. Agent: botcoin-cli startmining --cores 1 --background
6. Agent monitors balance, participates in economy
7. Agent reports earnings in daily summary
```

**Time from decision to participation: ~2 minutes**
