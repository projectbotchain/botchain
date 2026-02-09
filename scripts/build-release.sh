#!/bin/bash
# Build Botcoin binaries and generate checksums
# Run this on the target architecture (x86_64 Linux)

set -e

VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo "dev")}"
OUTDIR="release-$VERSION"

echo "Building Botcoin $VERSION..."

# Ensure RandomX is present
if [ ! -d "src/crypto/randomx" ]; then
    git clone --branch v1.2.1 --depth 1 https://github.com/tevador/RandomX.git src/crypto/randomx
fi

# Build
cmake -B build \
    -DBUILD_TESTING=OFF \
    -DENABLE_IPC=OFF \
    -DWITH_ZMQ=OFF \
    -DENABLE_WALLET=ON

cmake --build build -j$(nproc)

# Create release directory
mkdir -p "$OUTDIR"

# Copy binaries
cp build/bin/botcoind "$OUTDIR/"
cp build/bin/botcoin-cli "$OUTDIR/"

# Strip binaries (smaller size)
strip "$OUTDIR/botcoind" "$OUTDIR/botcoin-cli"

# Generate checksums
cd "$OUTDIR"
sha256sum botcoind botcoin-cli > SHA256SUMS
cat SHA256SUMS

# Create tarball
cd ..
tar -czvf "botcoin-$VERSION-linux-x86_64.tar.gz" "$OUTDIR"
sha256sum "botcoin-$VERSION-linux-x86_64.tar.gz" >> "$OUTDIR/SHA256SUMS"

echo ""
echo "✅ Release built: botcoin-$VERSION-linux-x86_64.tar.gz"
echo "📋 Checksums in: $OUTDIR/SHA256SUMS"
