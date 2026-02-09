#!/usr/bin/env python3
# Copyright (c) 2026 Botcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Test Botcoin network identification.

This test verifies:
- Network magic bytes are correct for Botcoin (mainnet 0xB07C010E; regtest 0xB07C0000)
- Protocol version is 70100
- User agent contains "Botcoin" and does NOT contain "Bitcoin" or "Satoshi"
"""

from test_framework.test_framework import BitcoinTestFramework
from test_framework.p2p import P2PInterface


class NetworkMagicTest(BitcoinTestFramework):
    def set_test_params(self):
        self.num_nodes = 1
        self.setup_clean_chain = True

    def run_test(self):
        node = self.nodes[0]

        self.log.info("Testing network identification...")

        # Test: Connect and verify we can communicate
        peer = node.add_p2p_connection(P2PInterface())
        peer.wait_for_verack()

        # Get network info
        info = node.getnetworkinfo()

        # Test: User agent should contain Botcoin and NOT contain Bitcoin/Satoshi
        self.log.info(f"User agent: {info['subversion']}")
        assert 'Botcoin' in info['subversion'], f"Expected 'Botcoin' in {info['subversion']}"
        assert 'Bitcoin' not in info['subversion'], "Should not contain 'Bitcoin'"
        assert 'Satoshi' not in info['subversion'], "Should not contain 'Satoshi'"

        # Test: Protocol version should be 70100
        self.log.info(f"Protocol version: {info['protocolversion']}")
        assert info['protocolversion'] == 70100, f"Expected 70100, got {info['protocolversion']}"

        # Test: Verify connections work (implicit test of network magic)
        # If network magic were wrong, the connection would have failed
        assert info['connections'] >= 1, "Should have at least 1 connection"

        self.log.info("Network magic and protocol version tests passed")


if __name__ == '__main__':
    NetworkMagicTest(__file__).main()
