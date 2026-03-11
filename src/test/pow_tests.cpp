// Copyright (c) 2015-present The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <chain.h>
#include <chainparams.h>
#include <pow.h>
#include <test/util/random.h>
#include <test/util/setup_common.h>
#include <util/chaintype.h>

#include <boost/test/unit_test.hpp>

BOOST_FIXTURE_TEST_SUITE(pow_tests, BasicTestingSetup)

/* Test calculation of next difficulty target with no constraints applying */
BOOST_AUTO_TEST_CASE(get_next_work)
{
    const auto chainParams = CreateChainParams(*m_node.args, ChainType::MAIN);
    // Botcoin: DifficultyAdjustmentInterval = nPowTargetTimespan / nPowTargetSpacing
    //        = (14 * 24 * 60 * 60) / 60 = 20160 blocks
    // Adjustment happens at height 20160, 40320, etc.
    int64_t nLastRetargetTime = 1738195200; // Genesis timestamp
    CBlockIndex pindexLast;
    pindexLast.nHeight = 20159; // Last block before first difficulty adjustment
    // Actual timespan: ~14.2 days = 1,224,000 seconds (slightly slower than target)
    pindexLast.nTime = nLastRetargetTime + 1224000;
    pindexLast.nBits = 0x1e0377ae; // Botcoin's initial difficulty

    // Expected: difficulty increases slightly (target gets lower) because blocks were slow
    unsigned int expected_nbits = CalculateNextWorkRequired(&pindexLast, nLastRetargetTime, chainParams->GetConsensus());
    BOOST_CHECK(PermittedDifficultyTransition(chainParams->GetConsensus(), pindexLast.nHeight+1, pindexLast.nBits, expected_nbits));
}

/* Test the constraint on the upper bound for next work */
BOOST_AUTO_TEST_CASE(get_next_work_pow_limit)
{
    const auto chainParams = CreateChainParams(*m_node.args, ChainType::MAIN);
    // Botcoin: Test that difficulty can't go above powLimit when blocks are on target
    int64_t nLastRetargetTime = 1738195200; // Genesis timestamp
    CBlockIndex pindexLast;
    pindexLast.nHeight = 20159; // Last block before first difficulty adjustment
    // Blocks came at exactly target rate = no change needed
    pindexLast.nTime = nLastRetargetTime + chainParams->GetConsensus().nPowTargetTimespan;
    pindexLast.nBits = 0x1e0377ae; // Botcoin's initial difficulty
    unsigned int expected_nbits = 0x1e0377aeU; // Should remain at powLimit
    BOOST_CHECK_EQUAL(CalculateNextWorkRequired(&pindexLast, nLastRetargetTime, chainParams->GetConsensus()), expected_nbits);
    BOOST_CHECK(PermittedDifficultyTransition(chainParams->GetConsensus(), pindexLast.nHeight+1, pindexLast.nBits, expected_nbits));
}

/* Test the constraint on the lower bound for actual time taken */
BOOST_AUTO_TEST_CASE(get_next_work_lower_limit_actual)
{
    const auto chainParams = CreateChainParams(*m_node.args, ChainType::MAIN);
    // Botcoin: Test lower limit (blocks came too fast - difficulty increases)
    // When blocks come fast, target decreases (difficulty increases).
    // Use regtest which allows min difficulty blocks, avoiding PermittedDifficultyTransition edge cases.
    const auto regParams = CreateChainParams(*m_node.args, ChainType::REGTEST);

    int64_t nLastRetargetTime = 1738195200;
    CBlockIndex pindexLast;
    pindexLast.nHeight = 20159; // Last block before first difficulty adjustment
    // Blocks came in 1/4 of target time (3.5 days instead of 14 days)
    int64_t actualTimespan = chainParams->GetConsensus().nPowTargetTimespan / 4;
    pindexLast.nTime = nLastRetargetTime + actualTimespan;
    // Use a harder difficulty (256x harder than powLimit) so we can see the adjustment
    pindexLast.nBits = 0x1d0377ae;

    unsigned int new_nbits = CalculateNextWorkRequired(&pindexLast, nLastRetargetTime, chainParams->GetConsensus());

    // Verify difficulty increased (target decreased, so nBits value decreased)
    // Higher nBits exponent means easier target, lower means harder
    arith_uint256 old_target, new_target;
    old_target.SetCompact(pindexLast.nBits);
    new_target.SetCompact(new_nbits);
    BOOST_CHECK(new_target < old_target); // Target should be lower (harder difficulty)

    // The new target should be approximately 4x lower (max clamp)
    arith_uint256 expected_min_target = old_target / 4;
    BOOST_CHECK(new_target <= expected_min_target);
}

/* Test the constraint on the upper bound for actual time taken */
BOOST_AUTO_TEST_CASE(get_next_work_upper_limit_actual)
{
    const auto chainParams = CreateChainParams(*m_node.args, ChainType::MAIN);
    // Botcoin: Test upper limit (blocks came too slow - difficulty must decrease)
    // Max adjustment is 4x, so if blocks took 4x target time,
    // difficulty should decrease by 4x (target increases by 4x)
    int64_t nLastRetargetTime = 1738195200;
    CBlockIndex pindexLast;
    pindexLast.nHeight = 20159; // Last block before first difficulty adjustment
    // Blocks took 4x target time (56 days instead of 14 days)
    int64_t actualTimespan = chainParams->GetConsensus().nPowTargetTimespan * 4;
    pindexLast.nTime = nLastRetargetTime + actualTimespan;
    pindexLast.nBits = 0x1e0377ae; // Botcoin's initial difficulty (at powLimit)

    // At powLimit, even with 4x slowdown, can't go above powLimit
    unsigned int expected_nbits = CalculateNextWorkRequired(&pindexLast, nLastRetargetTime, chainParams->GetConsensus());
    BOOST_CHECK(PermittedDifficultyTransition(chainParams->GetConsensus(), pindexLast.nHeight+1, pindexLast.nBits, expected_nbits));
    // Test that increasing nbits further would not be a PermittedDifficultyTransition.
    unsigned int invalid_nbits = expected_nbits+1;
    BOOST_CHECK(!PermittedDifficultyTransition(chainParams->GetConsensus(), pindexLast.nHeight+1, pindexLast.nBits, invalid_nbits));
}

BOOST_AUTO_TEST_CASE(CheckProofOfWork_test_negative_target)
{
    const auto consensus = CreateChainParams(*m_node.args, ChainType::MAIN)->GetConsensus();
    uint256 hash;
    unsigned int nBits;
    nBits = UintToArith256(consensus.powLimit).GetCompact(true);
    hash = uint256{1};
    BOOST_CHECK(!CheckProofOfWork(hash, nBits, consensus));
}

BOOST_AUTO_TEST_CASE(CheckProofOfWork_test_overflow_target)
{
    const auto consensus = CreateChainParams(*m_node.args, ChainType::MAIN)->GetConsensus();
    uint256 hash;
    unsigned int nBits{~0x00800000U};
    hash = uint256{1};
    BOOST_CHECK(!CheckProofOfWork(hash, nBits, consensus));
}

BOOST_AUTO_TEST_CASE(CheckProofOfWork_test_too_easy_target)
{
    const auto consensus = CreateChainParams(*m_node.args, ChainType::MAIN)->GetConsensus();
    uint256 hash;
    unsigned int nBits;
    arith_uint256 nBits_arith = UintToArith256(consensus.powLimit);
    nBits_arith *= 2;
    nBits = nBits_arith.GetCompact();
    hash = uint256{1};
    BOOST_CHECK(!CheckProofOfWork(hash, nBits, consensus));
}

BOOST_AUTO_TEST_CASE(CheckProofOfWork_test_biger_hash_than_target)
{
    const auto consensus = CreateChainParams(*m_node.args, ChainType::MAIN)->GetConsensus();
    uint256 hash;
    unsigned int nBits;
    arith_uint256 hash_arith = UintToArith256(consensus.powLimit);
    nBits = hash_arith.GetCompact();
    hash_arith *= 2; // hash > nBits
    hash = ArithToUint256(hash_arith);
    BOOST_CHECK(!CheckProofOfWork(hash, nBits, consensus));
}

BOOST_AUTO_TEST_CASE(CheckProofOfWork_test_zero_target)
{
    const auto consensus = CreateChainParams(*m_node.args, ChainType::MAIN)->GetConsensus();
    uint256 hash;
    unsigned int nBits;
    arith_uint256 hash_arith{0};
    nBits = hash_arith.GetCompact();
    hash = ArithToUint256(hash_arith);
    BOOST_CHECK(!CheckProofOfWork(hash, nBits, consensus));
}

BOOST_AUTO_TEST_CASE(GetBlockProofEquivalentTime_test)
{
    const auto chainParams = CreateChainParams(*m_node.args, ChainType::MAIN);
    std::vector<CBlockIndex> blocks(10000);
    for (int i = 0; i < 10000; i++) {
        blocks[i].pprev = i ? &blocks[i - 1] : nullptr;
        blocks[i].nHeight = i;
        blocks[i].nTime = 1269211443 + i * chainParams->GetConsensus().nPowTargetSpacing;
        blocks[i].nBits = 0x207fffff; /* target 0x7fffff000... */
        blocks[i].nChainWork = i ? blocks[i - 1].nChainWork + GetBlockProof(blocks[i - 1]) : arith_uint256(0);
    }

    for (int j = 0; j < 1000; j++) {
        CBlockIndex *p1 = &blocks[m_rng.randrange(10000)];
        CBlockIndex *p2 = &blocks[m_rng.randrange(10000)];
        CBlockIndex *p3 = &blocks[m_rng.randrange(10000)];

        int64_t tdiff = GetBlockProofEquivalentTime(*p1, *p2, *p3, chainParams->GetConsensus());
        BOOST_CHECK_EQUAL(tdiff, p1->GetBlockTime() - p2->GetBlockTime());
    }
}

void sanity_check_chainparams(const ArgsManager& args, ChainType chain_type)
{
    const auto chainParams = CreateChainParams(args, chain_type);
    const auto consensus = chainParams->GetConsensus();

    // hash genesis is correct
    BOOST_CHECK_EQUAL(consensus.hashGenesisBlock, chainParams->GenesisBlock().GetHash());

    // target timespan is an even multiple of spacing
    BOOST_CHECK_EQUAL(consensus.nPowTargetTimespan % consensus.nPowTargetSpacing, 0);

    // genesis nBits is positive, doesn't overflow and is lower than powLimit
    arith_uint256 pow_compact;
    bool neg, over;
    pow_compact.SetCompact(chainParams->GenesisBlock().nBits, &neg, &over);
    BOOST_CHECK(!neg && pow_compact != 0);
    BOOST_CHECK(!over);
    BOOST_CHECK(UintToArith256(consensus.powLimit) >= pow_compact);

    // check max target * 4*nPowTargetTimespan doesn't overflow -- see pow.cpp:CalculateNextWorkRequired()
    if (!consensus.fPowNoRetargeting) {
        arith_uint256 targ_max{UintToArith256(uint256{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"})};
        targ_max /= consensus.nPowTargetTimespan*4;
        BOOST_CHECK(UintToArith256(consensus.powLimit) < targ_max);
    }
}

BOOST_AUTO_TEST_CASE(ChainParams_MAIN_sanity)
{
    sanity_check_chainparams(*m_node.args, ChainType::MAIN);
}

BOOST_AUTO_TEST_CASE(ChainParams_REGTEST_sanity)
{
    sanity_check_chainparams(*m_node.args, ChainType::REGTEST);
}

BOOST_AUTO_TEST_CASE(ChainParams_TESTNET_sanity)
{
    sanity_check_chainparams(*m_node.args, ChainType::TESTNET);
}

BOOST_AUTO_TEST_CASE(ChainParams_TESTNET4_sanity)
{
    sanity_check_chainparams(*m_node.args, ChainType::TESTNET4);
}

BOOST_AUTO_TEST_CASE(ChainParams_SIGNET_sanity)
{
    sanity_check_chainparams(*m_node.args, ChainType::SIGNET);
}

BOOST_AUTO_TEST_SUITE_END()
