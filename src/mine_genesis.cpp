// mine_genesis.cpp - Utility to mine a valid genesis block nonce
// Compile with: g++ -o mine_genesis mine_genesis.cpp -I. -Icrypto/randomx/src -Lbuild/lib -lrandomx -lpthread -O3

#include <cstdint>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <vector>
#include <chrono>

extern "C" {
#include "crypto/randomx/src/randomx.h"
}

// Botcoin genesis seed: SHA256("Botcoin Genesis Seed")
// Precomputed: c7da9c30fb211702bf3f7e42f605f2168d131ee6fe36b9f621e4cd732464f3bd
const uint8_t GENESIS_SEED[32] = {
    0xc7, 0xda, 0x9c, 0x30, 0xfb, 0x21, 0x17, 0x02,
    0xbf, 0x3f, 0x7e, 0x42, 0xf6, 0x05, 0xf2, 0x16,
    0x8d, 0x13, 0x1e, 0xe6, 0xfe, 0x36, 0xb9, 0xf6,
    0x21, 0xe4, 0xcd, 0x73, 0x24, 0x64, 0xf3, 0xbd
};

// Block header structure (80 bytes)
struct BlockHeader {
    int32_t nVersion;           // 4 bytes
    uint8_t hashPrevBlock[32];  // 32 bytes
    uint8_t hashMerkleRoot[32]; // 32 bytes
    uint32_t nTime;             // 4 bytes
    uint32_t nBits;             // 4 bytes
    uint32_t nNonce;            // 4 bytes
};

// Convert compact nBits to 256-bit target
void compact_to_target(uint32_t nBits, uint8_t target[32]) {
    memset(target, 0, 32);
    int size = (nBits >> 24) & 0xFF;
    uint32_t word = nBits & 0x007FFFFF;

    if (size <= 3) {
        word >>= 8 * (3 - size);
        target[0] = word & 0xFF;
        target[1] = (word >> 8) & 0xFF;
        target[2] = (word >> 16) & 0xFF;
    } else {
        int offset = size - 3;
        target[offset] = word & 0xFF;
        target[offset + 1] = (word >> 8) & 0xFF;
        target[offset + 2] = (word >> 16) & 0xFF;
    }
}

// Compare hash against target (little-endian)
bool hash_below_target(const uint8_t hash[32], const uint8_t target[32]) {
    // Compare from most significant byte (index 31) to least
    for (int i = 31; i >= 0; i--) {
        if (hash[i] < target[i]) return true;
        if (hash[i] > target[i]) return false;
    }
    return true; // Equal
}

std::string to_hex(const uint8_t* data, size_t len) {
    std::stringstream ss;
    for (size_t i = 0; i < len; i++) {
        ss << std::hex << std::setfill('0') << std::setw(2) << (int)data[i];
    }
    return ss.str();
}

void hex_to_bytes(const char* hex, uint8_t* out, size_t len) {
    for (size_t i = 0; i < len; i++) {
        sscanf(hex + 2*i, "%2hhx", &out[i]);
    }
}

int main(int argc, char** argv) {
    // Default: regtest parameters
    uint32_t nBits = 0x207fffff;  // Very easy target for regtest
    uint32_t nTime = 1738195200;

    // Mainnet merkle root (computed from coinbase tx)
    const char* merkle_root_hex = "90abe18522cab144a5901d694605664f7336860bd93292f161497fdf3a0c3750";

    if (argc > 1) {
        // Allow specifying nBits for mainnet mining
        nBits = strtoul(argv[1], nullptr, 16);
    }

    std::cout << "Mining genesis block nonce..." << std::endl;
    std::cout << "nBits: 0x" << std::hex << nBits << std::dec << std::endl;
    std::cout << "nTime: " << nTime << std::endl;
    std::cout << "Merkle root: " << merkle_root_hex << std::endl;

    // Compute target
    uint8_t target[32];
    compact_to_target(nBits, target);
    std::cout << "Target: " << to_hex(target, 32) << std::endl;

    // Initialize RandomX in light mode (faster startup)
    randomx_flags flags = randomx_get_flags();
    randomx_cache* cache = randomx_alloc_cache(flags | RANDOMX_FLAG_JIT);
    if (!cache) {
        cache = randomx_alloc_cache(flags);
    }
    if (!cache) {
        std::cerr << "Failed to allocate RandomX cache" << std::endl;
        return 1;
    }

    randomx_init_cache(cache, GENESIS_SEED, 32);

    randomx_vm* vm = randomx_create_vm(flags | RANDOMX_FLAG_JIT, cache, nullptr);
    if (!vm) {
        vm = randomx_create_vm(flags, cache, nullptr);
    }
    if (!vm) {
        std::cerr << "Failed to create RandomX VM" << std::endl;
        return 1;
    }

    std::cout << "RandomX initialized (light mode)" << std::endl;

    // Prepare block header
    BlockHeader header;
    header.nVersion = 0x20000000;
    memset(header.hashPrevBlock, 0, 32);
    hex_to_bytes(merkle_root_hex, header.hashMerkleRoot, 32);
    // Reverse merkle root (Bitcoin uses little-endian internally)
    for (int i = 0; i < 16; i++) {
        std::swap(header.hashMerkleRoot[i], header.hashMerkleRoot[31-i]);
    }
    header.nTime = nTime;
    header.nBits = nBits;
    header.nNonce = 0;

    uint8_t hash[32];
    auto start_time = std::chrono::steady_clock::now();
    uint64_t attempts = 0;

    while (true) {
        // Compute RandomX hash
        randomx_calculate_hash(vm, &header, 80, hash);
        attempts++;

        if (hash_below_target(hash, target)) {
            auto end_time = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();

            std::cout << "\n*** FOUND VALID NONCE! ***" << std::endl;
            std::cout << "Nonce: " << header.nNonce << " (0x" << std::hex << header.nNonce << std::dec << ")" << std::endl;
            std::cout << "Hash: " << to_hex(hash, 32) << std::endl;
            std::cout << "Attempts: " << attempts << std::endl;
            std::cout << "Time: " << elapsed << "ms" << std::endl;
            std::cout << "Hashrate: " << (attempts * 1000 / (elapsed + 1)) << " H/s" << std::endl;
            break;
        }

        header.nNonce++;

        if (header.nNonce % 1000 == 0) {
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
            if (elapsed > 0) {
                std::cout << "\rNonce: " << header.nNonce << " (" << (attempts / elapsed) << " H/s)" << std::flush;
            }
        }

        if (header.nNonce == 0) {
            std::cerr << "\nExhausted nonce space!" << std::endl;
            break;
        }
    }

    randomx_destroy_vm(vm);
    randomx_release_cache(cache);

    return 0;
}
