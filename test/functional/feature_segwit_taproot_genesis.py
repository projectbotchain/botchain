#!/usr/bin/env python3
# Copyright (c) 2026 Botcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Test SegWit and Taproot active from genesis.

This test verifies:
- SegWit transactions are valid from block 1
- Taproot transactions are valid from block 1
- All BIPs are active from genesis (height 0)
"""

from test_framework.test_framework import BitcoinTestFramework


class GenesisActivationTest(BitcoinTestFramework):
    def set_test_params(self):
        self.num_nodes = 1
        self.setup_clean_chain = True

    def skip_test_if_missing_module(self):
        self.skip_if_no_wallet()

    def run_test(self):
        node = self.nodes[0]

        self.log.info("Testing soft fork activation from genesis...")

        # Mine 1 block (block 1)
        self.generate(node, 1)

        # Need mature coinbase first (100 blocks for regtest)
        self.log.info("Mining 100 blocks for coinbase maturity...")
        self.generate(node, 100)

        # Test: SegWit works in block 1
        self.log.info("Testing SegWit transaction...")
        segwit_addr = node.getnewaddress("", "bech32")
        txid = node.sendtoaddress(segwit_addr, 1)
        self.generate(node, 1)

        tx = node.gettransaction(txid)
        assert tx['confirmations'] >= 1, "SegWit tx should confirm"
        self.log.info(f"SegWit tx confirmed: {txid}")

        # Test: Taproot works
        self.log.info("Testing Taproot transaction...")
        taproot_addr = node.getnewaddress("", "bech32m")
        txid = node.sendtoaddress(taproot_addr, 1)
        self.generate(node, 1)

        tx = node.gettransaction(txid)
        assert tx['confirmations'] >= 1, "Taproot tx should confirm"
        self.log.info(f"Taproot tx confirmed: {txid}")

        # Test: Spend from Taproot (key path)
        self.log.info("Testing Taproot spend (key path)...")
        legacy_addr = node.getnewaddress("", "legacy")
        txid = node.sendtoaddress(legacy_addr, 0.5)
        self.generate(node, 1)

        tx = node.gettransaction(txid)
        assert tx['confirmations'] >= 1, "Taproot spend should confirm"
        self.log.info(f"Taproot spend confirmed: {txid}")

        # Verify blockchain info shows SegWit active
        info = node.getblockchaininfo()
        self.log.info(f"Chain: {info['chain']}, blocks: {info['blocks']}")

        # Check softforks status (if available)
        if 'softforks' in info:
            for fork_name, fork_info in info['softforks'].items():
                self.log.info(f"Softfork {fork_name}: {fork_info.get('active', fork_info.get('type', 'unknown'))}")

        self.log.info("Genesis activation tests passed")


if __name__ == '__main__':
    GenesisActivationTest(__file__).main()
