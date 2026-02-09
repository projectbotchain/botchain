// Copyright (c) 2024-present The Botcoin developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <crypto/randomx_hash.h>
#include <hash.h>
#include <pow.h>
#include <primitives/block.h>
#include <streams.h>
#include <test/util/setup_common.h>
#include <uint256.h>

#include <boost/test/unit_test.hpp>

#include <vector>

BOOST_FIXTURE_TEST_SUITE(randomx_tests, BasicTestingSetup)

// =============================================================================
// Phase 1.2 Tests: RandomX Hash Function
// =============================================================================

/**
 * Test: Known hash vector (deterministic output)
 * Acceptance: Same input produces same output; hash is not all zeros.
 */
BOOST_AUTO_TEST_CASE(randomx_known_vector)
{
    // Create test input (80-byte "header")
    std::vector<uint8_t> header(80, 0);

    // Use genesis seed
    uint256 seed = Hash(std::string("Botcoin Genesis Seed"));

    // Compute hash twice
    uint256 hash1 = RandomXHash(header, seed);
    uint256 hash2 = RandomXHash(header, seed);

    // Same input = same output (deterministic)
    BOOST_CHECK_EQUAL(hash1, hash2);

    // Hash is not all zeros (actually computed something)
    BOOST_CHECK(hash1 != uint256());

    // Hash is not the same as seed (different operation)
    BOOST_CHECK(hash1 != seed);
}

/**
 * Test: Different input produces different output
 * Acceptance: RandomX is a proper hash function with collision resistance.
 */
BOOST_AUTO_TEST_CASE(randomx_different_input)
{
    std::vector<uint8_t> header1(80, 0);
    std::vector<uint8_t> header2(80, 1); // Different content
    uint256 seed = Hash(std::string("Botcoin Genesis Seed"));

    uint256 hash1 = RandomXHash(header1, seed);
    uint256 hash2 = RandomXHash(header2, seed);

    // Different input should produce different output
    BOOST_CHECK(hash1 != hash2);
}

/**
 * Test: Different seed produces different output
 * Acceptance: The seed hash properly influences the RandomX computation.
 */
BOOST_AUTO_TEST_CASE(randomx_different_seed)
{
    std::vector<uint8_t> header(80, 0);
    uint256 seed1 = uint256(); // All zeros
    uint256 seed2{"0000000000000000000000000000000000000000000000000000000000000001"};

    uint256 hash1 = RandomXHash(header, seed1);
    uint256 hash2 = RandomXHash(header, seed2);

    // Different seed should produce different output
    BOOST_CHECK(hash1 != hash2);
}

/**
 * Test: Light mode works (same as default Hash function)
 * Acceptance: RandomXHashLight produces valid hashes.
 */
BOOST_AUTO_TEST_CASE(randomx_light_mode)
{
    std::vector<uint8_t> header(80, 0);
    uint256 seed = Hash(std::string("Botcoin Genesis Seed"));

    // Light mode should work (uses 256 MiB cache)
    uint256 hash = RandomXHashLight(header, seed);
    BOOST_CHECK(hash != uint256());

    // Light mode should give same result as regular RandomXHash
    // (since RandomXHash uses light mode internally for validation)
    uint256 hash2 = RandomXHash(header, seed);
    BOOST_CHECK_EQUAL(hash, hash2);
}

// =============================================================================
// Phase 1.3 Tests: Seed Height Calculation
// =============================================================================

/**
 * Test: Seed height follows spec (every 2048 blocks + 64 lag)
 * Acceptance: Seed rotates correctly per specs/randomx.md.
 *
 * Spec:
 * - Epoch: 2048 blocks
 * - Lag: 64 blocks
 * - Key changes when: block_height >= EPOCH_LENGTH + LAG
 * - Seed block: floor((block_height - LAG) / EPOCH_LENGTH) * EPOCH_LENGTH
 */
BOOST_AUTO_TEST_CASE(seed_height_calculation)
{
    // Before first rotation: seed height = 0
    // Blocks 0 through 2111 use genesis seed (height 0)
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(0), 0ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(64), 0ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(2047), 0ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(2048), 0ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(2111), 0ULL);

    // First rotation at 2048 + 64 = 2112
    // Blocks 2112+ use seed from block 2048
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(2112), 2048ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(4000), 2048ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(4095), 2048ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(4096), 2048ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(4159), 2048ULL);

    // Second rotation at 4096 + 64 = 4160
    // Blocks 4160+ use seed from block 4096
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(4160), 4096ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(6000), 4096ULL);
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(6207), 4096ULL);

    // Third rotation at 6144 + 64 = 6208
    BOOST_CHECK_EQUAL(GetRandomXSeedHeight(6208), 6144ULL);
}

/**
 * Test: Epoch length and lag constants are correct.
 * Acceptance: Constants match specs/randomx.md.
 */
BOOST_AUTO_TEST_CASE(randomx_constants)
{
    // From specs/randomx.md:
    // - Epoch: 2048 blocks (~34 hours at 60s blocks)
    // - Lag: 64 blocks (~1 hour)
    BOOST_CHECK_EQUAL(RANDOMX_EPOCH_LENGTH, 2048ULL);
    BOOST_CHECK_EQUAL(RANDOMX_EPOCH_LAG, 64ULL);
}

// =============================================================================
// Phase 1.4 Tests: Block PoW Validation
// =============================================================================

/**
 * Test: Block header serialization for RandomX
 * Acceptance: Serialized header is 80 bytes (standard Bitcoin header size).
 */
BOOST_AUTO_TEST_CASE(block_header_serialization)
{
    CBlockHeader header;
    header.nVersion = 0x20000000;
    header.hashPrevBlock = uint256();
    header.hashMerkleRoot = uint256();
    header.nTime = 1234567890;
    header.nBits = 0x207fffff;
    header.nNonce = 0;

    DataStream ss{};
    ss << header;

    // Block header should be exactly 80 bytes
    BOOST_CHECK_EQUAL(ss.size(), 80U);
}

/**
 * Test: GetBlockPoWHash produces valid hash
 * Acceptance: PoW hash computation works on block headers.
 */
BOOST_AUTO_TEST_CASE(get_block_pow_hash)
{
    CBlockHeader header;
    header.nVersion = 0x20000000;
    header.hashPrevBlock = uint256();
    header.hashMerkleRoot = uint256();
    header.nTime = 1234567890;
    header.nBits = 0x207fffff;
    header.nNonce = 0;

    uint256 seed = Hash(std::string("Botcoin Genesis Seed"));
    uint256 pow_hash = GetBlockPoWHash(header, seed);

    // Hash should not be zero
    BOOST_CHECK(pow_hash != uint256());

    // Same header should produce same hash
    uint256 pow_hash2 = GetBlockPoWHash(header, seed);
    BOOST_CHECK_EQUAL(pow_hash, pow_hash2);

    // Different nonce should produce different hash
    header.nNonce = 1;
    uint256 pow_hash3 = GetBlockPoWHash(header, seed);
    BOOST_CHECK(pow_hash != pow_hash3);
}

/**
 * Test: Genesis seed hash computation
 * Acceptance: Genesis seed is SHA256("Botcoin Genesis Seed").
 */
BOOST_AUTO_TEST_CASE(genesis_seed_hash)
{
    // GetRandomXSeedHash with null pindex should return genesis seed
    uint256 expected = Hash(std::string("Botcoin Genesis Seed"));
    uint256 actual = GetRandomXSeedHash(nullptr);

    BOOST_CHECK_EQUAL(actual, expected);
}

// =============================================================================
// Integration Tests
// =============================================================================

/**
 * Test: RandomX context singleton works correctly.
 * Acceptance: Repeated calls work, context is properly managed.
 */
BOOST_AUTO_TEST_CASE(randomx_context_singleton)
{
    RandomXContext& ctx = RandomXContext::GetInstance();

    // Should start uninitialized or get initialized on first use
    std::vector<uint8_t> data(80, 42);
    uint256 seed = Hash(std::string("Test Seed"));

    // This will initialize the context if needed
    uint256 hash1 = ctx.Hash(data, seed);
    BOOST_CHECK(hash1 != uint256());

    // Context should now be initialized
    BOOST_CHECK(ctx.IsInitialized());

    // Same seed should be cached
    auto cached_seed = ctx.GetCurrentSeedHash();
    BOOST_CHECK(cached_seed.has_value());
    BOOST_CHECK_EQUAL(*cached_seed, seed);

    // Repeated hash should give same result
    uint256 hash2 = ctx.Hash(data, seed);
    BOOST_CHECK_EQUAL(hash1, hash2);
}

/**
 * Test: Seed hash update works correctly.
 * Acceptance: Changing seed produces different hashes.
 */
BOOST_AUTO_TEST_CASE(randomx_context_seed_update)
{
    RandomXContext& ctx = RandomXContext::GetInstance();

    std::vector<uint8_t> data(80, 0);
    uint256 seed1 = Hash(std::string("Seed One"));
    uint256 seed2 = Hash(std::string("Seed Two"));

    uint256 hash1 = ctx.Hash(data, seed1);
    uint256 hash2 = ctx.Hash(data, seed2);

    // Different seeds should produce different hashes
    BOOST_CHECK(hash1 != hash2);

    // Going back to first seed should give same hash as before
    uint256 hash3 = ctx.Hash(data, seed1);
    BOOST_CHECK_EQUAL(hash1, hash3);
}

BOOST_AUTO_TEST_SUITE_END()
