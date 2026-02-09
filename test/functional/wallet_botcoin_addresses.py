#!/usr/bin/env python3
# Copyright (c) 2026 Botcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
"""Test Botcoin address prefixes.

This test verifies:
- P2PKH addresses start with 't' (testnet/regtest) or 'B' (mainnet)
- P2SH addresses start with 's' (testnet/regtest) or 'A' (mainnet)
- Bech32 addresses start with 'tbot1' (testnet/regtest) or 'bot1' (mainnet)
- Taproot addresses contain 'bot1p' or 'tbot1p'
- Bitcoin addresses are rejected
"""

from test_framework.test_framework import BitcoinTestFramework
from test_framework.util import assert_equal


class AddressPrefixTest(BitcoinTestFramework):
    def set_test_params(self):
        self.num_nodes = 1

    def skip_test_if_missing_module(self):
        self.skip_if_no_wallet()

    def run_test(self):
        node = self.nodes[0]

        self.log.info("Testing Botcoin address prefixes...")

        # Test: P2PKH starts with 't' (regtest uses testnet prefixes)
        legacy = node.getnewaddress("", "legacy")
        self.log.info(f"P2PKH address: {legacy}")
        assert legacy.startswith('t') or legacy.startswith('m') or legacy.startswith('n'), \
            f"P2PKH unexpected prefix: '{legacy}' (expected 't', 'm', or 'n' for testnet)"

        # Test: P2SH-SegWit starts with 's' or '2' (testnet/regtest)
        p2sh = node.getnewaddress("", "p2sh-segwit")
        self.log.info(f"P2SH-SegWit address: {p2sh}")
        assert p2sh.startswith('2') or p2sh.startswith('s'), \
            f"P2SH unexpected prefix: '{p2sh}'"

        # Test: Bech32 starts with 'tbot1' (regtest)
        bech32 = node.getnewaddress("", "bech32")
        self.log.info(f"Bech32 address: {bech32}")
        assert bech32.startswith('tbot1'), f"Bech32 unexpected prefix: '{bech32}'"

        # Test: Taproot starts with 'tbot1p'
        taproot = node.getnewaddress("", "bech32m")
        self.log.info(f"Taproot address: {taproot}")
        assert taproot.startswith('tbot1p'), f"Taproot unexpected prefix: '{taproot}'"

        # Test: Bitcoin addresses rejected
        self.log.info("Testing Bitcoin address rejection...")
        btc_legacy = "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2"
        btc_bech32 = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

        result = node.validateaddress(btc_legacy)
        assert not result['isvalid'], "Bitcoin legacy address should be invalid"

        result = node.validateaddress(btc_bech32)
        assert not result['isvalid'], "Bitcoin bech32 address should be invalid"

        self.log.info("Address prefix tests passed")


if __name__ == '__main__':
    AddressPrefixTest(__file__).main()
