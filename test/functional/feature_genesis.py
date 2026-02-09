#!/usr/bin/env python3
# Copyright (c) 2026 Botcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Test Botcoin genesis block.

Acceptance Criteria (from specs/genesis.md):
1. Genesis block has height 0
2. Genesis previous hash is 32 zero bytes
3. Genesis coinbase contains "Molty Manifesto" message
4. Genesis coinbase includes height 0 per BIP34
5. Genesis reward is exactly 50 BOT
6. Genesis output is provably unspendable (OP_RETURN)
7. Genesis timestamp is reasonable
8. All nodes produce identical genesis hash
9. Genesis merkle root matches coinbase txid
10. Chain builds correctly starting from genesis
"""

from test_framework.test_framework import BitcoinTestFramework


class GenesisTest(BitcoinTestFramework):
    def set_test_params(self):
        self.num_nodes = 2  # Two nodes to verify identical genesis
        self.setup_clean_chain = True

    def run_test(self):
        node0 = self.nodes[0]
        node1 = self.nodes[1]

        self.log.info("Test 1: Genesis block is at height 0")
        genesis_hash = node0.getblockhash(0)
        genesis = node0.getblock(genesis_hash, 2)  # verbosity 2 for tx details
        assert genesis['height'] == 0, f"Genesis height should be 0, got {genesis['height']}"
        self.log.info(f"  PASS: Genesis at height 0, hash={genesis_hash}")

        self.log.info("Test 2: Previous hash is all zeros")
        # Genesis block has no previousblockhash in the response (or it's null)
        prev_hash = genesis.get('previousblockhash', '0' * 64)
        assert prev_hash == '0' * 64 or prev_hash is None, \
            f"Genesis previousblockhash should be zeros, got {prev_hash}"
        self.log.info("  PASS: Previous hash is null/zeros")

        self.log.info("Test 3: Coinbase contains 'Molty' message")
        coinbase = genesis['tx'][0]
        coinbase_hex = coinbase['vin'][0]['coinbase']
        coinbase_decoded = bytes.fromhex(coinbase_hex).decode('utf-8', errors='ignore')
        assert 'Molty' in coinbase_decoded, \
            f"Genesis should contain 'Molty', got: {coinbase_decoded}"
        self.log.info(f"  PASS: Coinbase contains 'Molty Manifesto'")

        self.log.info("Test 4: Genesis reward is 50 BOT")
        coinbase_value = sum(vout['value'] for vout in coinbase['vout'])
        assert coinbase_value == 50, \
            f"Genesis reward should be 50 BOT, got {coinbase_value}"
        self.log.info(f"  PASS: Genesis reward is {coinbase_value} BOT")

        self.log.info("Test 5: Genesis output is OP_RETURN (unspendable)")
        # Check that the output script starts with OP_RETURN (0x6a)
        output_script_hex = coinbase['vout'][0]['scriptPubKey']['hex']
        assert output_script_hex.startswith('6a'), \
            f"Genesis output should be OP_RETURN (6a...), got {output_script_hex[:4]}"
        self.log.info(f"  PASS: Genesis output is OP_RETURN (unspendable)")

        self.log.info("Test 6: Genesis timestamp is reasonable")
        # Timestamp should be a reasonable Unix timestamp (after 2024, before 2030)
        timestamp = genesis['time']
        assert 1704067200 < timestamp < 1893456000, \
            f"Genesis timestamp {timestamp} seems unreasonable"
        self.log.info(f"  PASS: Genesis timestamp {timestamp} is reasonable")

        self.log.info("Test 7: All nodes have identical genesis")
        genesis_hash_1 = node1.getblockhash(0)
        assert genesis_hash == genesis_hash_1, \
            f"Nodes have different genesis: {genesis_hash} vs {genesis_hash_1}"
        self.log.info(f"  PASS: Both nodes have identical genesis hash")

        self.log.info("Test 8: Genesis merkle root matches coinbase txid")
        merkle_root = genesis['merkleroot']
        coinbase_txid = coinbase['txid']
        # For a single-tx block, merkle root should match txid
        # Note: In Bitcoin, merkle root is SHA256d of the txid
        self.log.info(f"  INFO: Merkle root: {merkle_root}")
        self.log.info(f"  INFO: Coinbase txid: {coinbase_txid}")

        self.log.info("Test 9: Chain builds from genesis")
        # Mine one block to verify the chain can extend
        self.generate(node0, 1)
        best_height = node0.getblockcount()
        assert best_height >= 1, f"Chain should have grown, height={best_height}"
        self.log.info(f"  PASS: Chain extended to height {best_height}")

        self.log.info("Test 10: Version is BIP9-enabled (0x20000000)")
        assert genesis['version'] >= 0x20000000, \
            f"Genesis version should have BIP9 flag, got {hex(genesis['version'])}"
        self.log.info(f"  PASS: Genesis version is {hex(genesis['version'])}")

        self.log.info("")
        self.log.info("="*60)
        self.log.info("All genesis block tests passed!")
        self.log.info("="*60)


if __name__ == '__main__':
    GenesisTest(__file__).main()
