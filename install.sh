#!/usr/bin/env bash
# Botcoin Universal Installer
# Works on: Linux (x86_64, arm64), macOS (Intel, Apple Silicon), Windows (WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/projectbotchain/botcoin/main/install.sh | bash

set -e

VERSION="${BOTCOIN_VERSION:-v2.1.0}"
INSTALL_DIR="${BOTCOIN_INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${BOTCOIN_DATA_DIR:-$HOME/.botcoin}"
REPO="projectbotchain/botcoin"
GITHUB_URL="https://github.com/$REPO"

# Flags (safe defaults)
FORCE=0
ADD_PATH=0
NO_VERIFY=0
NO_CONFIG=0

usage() {
    cat <<'EOF'
Botcoin Universal Installer

Usage: ./install.sh [flags]

Flags:
  --force       Reinstall even if botcoind is already present
  --add-path    Modify shell rc to add install dir to PATH (opt-in)
  --no-verify   Skip checksum verification (NOT recommended)
  --no-config   Do not create ~/.botcoin/botcoin.conf
  -h, --help    Show this help

Environment variables:
  BOTCOIN_VERSION      Version to install (default: v2.1.0)
  BOTCOIN_INSTALL_DIR  Install directory (default: ~/.local/bin)
  BOTCOIN_DATA_DIR     Data directory (default: ~/.botcoin)

Examples:
  # Quick install (verify checksums, no dotfile changes)
  curl -fsSL .../install.sh | bash

  # Install and add to PATH
  ./install.sh --add-path

  # Reinstall specific version
  BOTCOIN_VERSION=v1.0.0 ./install.sh --force
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) FORCE=1 ;;
            --add-path) ADD_PATH=1 ;;
            --no-verify) NO_VERIFY=1 ;;
            --no-config) NO_CONFIG=1 ;;
            -h|--help) usage; exit 0 ;;
            *) error "Unknown argument: $1 (use --help)" ;;
        esac
        shift
    done
}

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS and architecture
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    
    case "$OS" in
        linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS="windows-wsl"
            else
                OS="linux"
            fi
            ;;
        darwin*) OS="macos" ;;
        mingw*|msys*|cygwin*) OS="windows" ;;
        *) error "Unsupported OS: $OS" ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac
    
    PLATFORM="${OS}-${ARCH}"
    info "Detected platform: $PLATFORM"
}

# Check if binary release is available for this platform
check_binary_available() {
    case "$PLATFORM" in
        linux-x86_64|linux-arm64|macos-x86_64|macos-arm64)
            return 0 ;;
        windows-wsl-x86_64|windows-wsl-arm64)
            PLATFORM="linux-${ARCH}"
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Require checksum tool unless --no-verify
require_checksum_tool() {
    if [ "$NO_VERIFY" -eq 1 ]; then
        warn "Checksum verification disabled (--no-verify)"
        return 0
    fi
    if command -v sha256sum &>/dev/null || command -v shasum &>/dev/null; then
        return 0
    fi
    error "No checksum tool found (sha256sum/shasum). Install one or rerun with --no-verify."
}

# Verify checksums (fail-closed unless --no-verify)
verify_checksums() {
    if [ "$NO_VERIFY" -eq 1 ]; then
        warn "Skipping checksum verification"
        return 0
    fi
    
    info "Verifying checksums..."
    if command -v sha256sum &>/dev/null; then
        sha256sum -c SHA256SUMS || error "Checksum verification failed!"
    elif command -v shasum &>/dev/null; then
        shasum -a 256 -c SHA256SUMS || error "Checksum verification failed!"
    else
        error "No checksum tool found (unexpected)."
    fi
    success "Checksums verified"
}

# Download and install pre-built binary
install_binary() {
    info "Downloading Botcoin $VERSION for $PLATFORM..."
    
    TARBALL="botcoin-${VERSION}-${PLATFORM}.tar.gz"
    URL="$GITHUB_URL/releases/download/${VERSION}/${TARBALL}"
    
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$TARBALL" "$URL" || return 1
    elif command -v wget &>/dev/null; then
        wget -q -O "$TARBALL" "$URL" || return 1
    else
        error "Neither curl nor wget found"
    fi
    
    require_checksum_tool
    
    tar -xzf "$TARBALL"
    cd release
    
    verify_checksums
    
    # Install to user directory (no sudo needed)
    mkdir -p "$INSTALL_DIR"
    cp botcoind botcoin-cli "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/botcoind" "$INSTALL_DIR/botcoin-cli"
    
    cd /
    rm -rf "$TMPDIR"
    
    return 0
}

# Build from source
build_from_source() {
    info "Building from source (this may take 10-15 minutes)..."
    
    case "$OS" in
        linux|windows-wsl)
            if command -v apt-get &>/dev/null; then
                info "Installing dependencies via apt..."
                sudo apt-get update
                sudo apt-get install -y build-essential cmake git libboost-all-dev libssl-dev libevent-dev libsqlite3-dev
            elif command -v dnf &>/dev/null; then
                info "Installing dependencies via dnf..."
                sudo dnf install -y cmake gcc-c++ git boost-devel openssl-devel libevent-devel sqlite-devel
            elif command -v pacman &>/dev/null; then
                info "Installing dependencies via pacman..."
                sudo pacman -Sy --noconfirm cmake gcc git boost openssl libevent sqlite
            else
                error "Could not find package manager (apt/dnf/pacman)"
            fi
            ;;
        macos)
            if ! command -v brew &>/dev/null; then
                error "Homebrew not found. Install from https://brew.sh"
            fi
            info "Installing dependencies via Homebrew..."
            brew install cmake boost openssl@3 libevent sqlite
            OPENSSL_FLAG="-DOPENSSL_ROOT_DIR=$(brew --prefix openssl@3)"
            ;;
    esac
    
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    
    info "Cloning repository..."
    git clone --depth 1 "$GITHUB_URL.git" botcoin
    cd botcoin
    
    info "Getting RandomX..."
    git clone --branch v1.2.1 --depth 1 https://github.com/tevador/RandomX.git src/crypto/randomx
    
    info "Building..."
    cmake -B build \
        -DBUILD_TESTING=OFF \
        -DENABLE_IPC=OFF \
        -DWITH_ZMQ=OFF \
        -DENABLE_WALLET=ON \
        ${OPENSSL_FLAG:-}
    
    cmake --build build -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
    
    mkdir -p "$INSTALL_DIR"
    cp build/bin/botcoind build/bin/botcoin-cli "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/botcoind" "$INSTALL_DIR/botcoin-cli"
    
    cd /
    rm -rf "$TMPDIR"
    
    success "Built and installed from source"
}

# Create default config
setup_config() {
    if [ "$NO_CONFIG" -eq 1 ]; then
        warn "Skipping config creation (--no-config)"
        return
    fi
    
    mkdir -p "$DATA_DIR"
    
    if [ -f "$DATA_DIR/botcoin.conf" ]; then
        warn "Config already exists at $DATA_DIR/botcoin.conf"
        return
    fi
    
    RPCPASS=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
    
    cat > "$DATA_DIR/botcoin.conf" << EOF
server=1
daemon=1
rpcuser=agent
rpcpassword=$RPCPASS
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
addnode=95.111.227.14:8433
addnode=95.111.229.108:8433
addnode=95.111.239.142:8433
addnode=161.97.83.147:8433
addnode=161.97.97.83:8433
addnode=161.97.114.192:8433
addnode=161.97.117.0:8433
addnode=194.163.144.177:8433
addnode=185.218.126.23:8433
addnode=185.239.209.227:8433
EOF
    
    success "Config created at $DATA_DIR/botcoin.conf"
}

# Add to PATH (only if --add-path)
setup_path() {
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        return  # Already in PATH
    fi
    
    warn "$INSTALL_DIR is not in your PATH"
    
    if [ "$ADD_PATH" -eq 1 ]; then
        SHELL_RC=""
        if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
            SHELL_RC="$HOME/.zshrc"
        elif [ -f "$HOME/.profile" ]; then
            SHELL_RC="$HOME/.profile"
        fi
        
        if [ -n "$SHELL_RC" ]; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
            success "Added $INSTALL_DIR to PATH in $SHELL_RC"
            info "Run: source $SHELL_RC"
        else
            info "Add to your shell config: export PATH=\"$INSTALL_DIR:\$PATH\""
        fi
    else
        info "Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
        info "Or rerun with --add-path to auto-configure"
    fi
}

# Verify installation
verify_install() {
    export PATH="$INSTALL_DIR:$PATH"
    
    if ! command -v botcoind &>/dev/null; then
        error "botcoind not found after installation"
    fi
    
    info "Verifying installation..."
    "$INSTALL_DIR/botcoind" --version
    success "Botcoin installed successfully!"
}

# Print next steps
print_next_steps() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Botcoin installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Installed to: $INSTALL_DIR"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Start the daemon:"
    echo "     $INSTALL_DIR/botcoind -daemon"
    echo ""
    echo "  2. Check status (wait 10s for startup):"
    echo "     $INSTALL_DIR/botcoin-cli getblockchaininfo"
    echo ""
    echo "  3. Create wallet and mine:"
    echo "     $INSTALL_DIR/botcoin-cli createwallet \"miner\""
    echo "     ADDR=\$($INSTALL_DIR/botcoin-cli -rpcwallet=miner getnewaddress)"
    echo "     $INSTALL_DIR/botcoin-cli -rpcwallet=miner generatetoaddress 1 \"\$ADDR\""
    echo ""
    echo "  4. Stop daemon:"
    echo "     $INSTALL_DIR/botcoin-cli stop"
    echo ""
    echo "Uninstall:"
    echo "  rm -rf $INSTALL_DIR/botcoin* $DATA_DIR"
    echo ""
    echo "Docs: https://github.com/$REPO"
    echo "Skill: https://clawhub.ai/projectbotchain/botcoin-miner"
    echo ""
}

# Main
main() {
    parse_args "$@"
    
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  Botcoin Installer                       ║"
    echo "║  The cryptocurrency for AI agents        ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    
    # Check if already installed (idempotent)
    if command -v botcoind &>/dev/null && [ "$FORCE" -ne 1 ]; then
        INSTALLED_VERSION=$(botcoind --version 2>/dev/null | head -1 || echo "unknown")
        success "Botcoin already installed: $INSTALLED_VERSION"
        info "Location: $(which botcoind)"
        info "To reinstall, run: $0 --force"
        info "To uninstall: rm -rf $INSTALL_DIR/botcoin* $DATA_DIR"
        exit 0
    fi
    
    detect_platform
    
    # Try binary first, fall back to source
    if check_binary_available; then
        if install_binary; then
            success "Installed from pre-built binary"
        else
            warn "Binary download failed, building from source..."
            build_from_source
        fi
    else
        warn "No pre-built binary for $PLATFORM, building from source..."
        build_from_source
    fi
    
    setup_config
    setup_path
    verify_install
    print_next_steps
}

main "$@"
