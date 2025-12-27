#!/bin/bash
# Install pgml extension from source for PostgreSQL 15
# This script compiles and installs pgml in your existing PostgreSQL installation
#
# Prerequisites:
# - PostgreSQL 15+ installed
# - Build tools (build-essential)
# - Python 3 development headers
#
# Usage: sudo ./install_pgml.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== pgml Installation Script ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
 echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
 exit 1
fi

# Check PostgreSQL version
echo -e "${YELLOW}Checking PostgreSQL installation...${NC}"
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
if [[ -z "$PG_VERSION" ]]; then
 echo -e "${RED}Error: PostgreSQL not found${NC}"
 exit 1
fi
echo "Found PostgreSQL ${PG_VERSION}"

# Check if PostgreSQL 14+
if [[ $PG_VERSION -lt 14 ]]; then
 echo -e "${RED}Error: pgml requires PostgreSQL 14 or higher (found ${PG_VERSION})${NC}"
 exit 1
fi

# Install build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
apt-get update
apt-get install -y \
 build-essential \
 "postgresql-server-dev-${PG_VERSION}" \
 libpython3-dev \
 python3-pip \
 curl \
 git \
 pkg-config \
 libssl-dev

# Check if Rust is installed
echo -e "${YELLOW}Checking Rust installation...${NC}"
if ! command -v cargo &> /dev/null; then
 echo "Rust not found. Installing Rust..."
 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

 # Source Rust environment for current shell
 export PATH="$HOME/.cargo/bin:$PATH"
 # shellcheck disable=SC1091
 # Source may not exist immediately after installation
 if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
 fi

 # Also add to current session
 export CARGO_HOME="$HOME/.cargo"
 export RUSTUP_HOME="$HOME/.rustup"
else
 echo "Rust already installed: $(cargo --version)"
fi

# Ensure Rust is in PATH
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v cargo &> /dev/null; then
 echo -e "${RED}Error: Rust installation failed or not in PATH${NC}"
 echo "Please run: source \$HOME/.cargo/env"
 exit 1
fi

# Clone pgml repository
BUILD_DIR="/tmp/pgml-build"
echo -e "${YELLOW}Cloning pgml repository...${NC}"
if [[ -d "$BUILD_DIR" ]]; then
 echo "Removing existing build directory..."
 rm -rf "$BUILD_DIR"
fi

git clone https://github.com/postgresml/postgresml.git "$BUILD_DIR"
cd "$BUILD_DIR"

# Checkout latest stable release (optional, but recommended)
echo -e "${YELLOW}Checking out latest stable release...${NC}"
LATEST_TAG=$(git describe --tags --abbrev=0 2> /dev/null || echo "")
if [[ -n "$LATEST_TAG" ]]; then
 echo "Using tag: $LATEST_TAG"
 git checkout "$LATEST_TAG"
else
 echo "Using latest commit from main branch"
fi

# Build pgml
echo -e "${YELLOW}Building pgml (this may take 10-30 minutes)...${NC}"
echo "This is a long process. Please be patient..."

# Set environment variables for build
PG_CONFIG=$(which pg_config)
export PG_CONFIG
CARGO_BUILD_JOBS=$(nproc)
export CARGO_BUILD_JOBS

# Build with release optimizations
cargo build --release

# Install pgml extension
echo -e "${YELLOW}Installing pgml extension...${NC}"
make install

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
PG_LIBDIR=$(pg_config --pkglibdir)
PG_SHAREDIR=$(pg_config --sharedir)

if [[ -f "$PG_SHAREDIR/extension/pgml.control" ]]; then
 echo -e "${GREEN}✓ pgml extension files installed successfully${NC}"
 echo "  Control file: $PG_SHAREDIR/extension/pgml.control"
else
 echo -e "${RED}✗ Error: pgml.control not found${NC}"
 exit 1
fi

if [[ -f "$PG_LIBDIR/pgml.so" ]] || [[ -f "$PG_LIBDIR/pgml-*.so" ]]; then
 echo -e "${GREEN}✓ pgml library installed successfully${NC}"
 echo "  Library directory: $PG_LIBDIR"
else
 echo -e "${YELLOW}⚠ Warning: pgml.so not found (may be normal if using static linking)${NC}"
fi

# Cleanup
echo -e "${YELLOW}Cleaning up build directory...${NC}"
cd /
rm -rf "$BUILD_DIR"

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Restart PostgreSQL service:"
echo "   sudo systemctl restart postgresql"
echo ""
echo "2. Enable the extension in your database:"
echo "   psql -d osm_notes -c 'CREATE EXTENSION IF NOT EXISTS pgml;'"
echo ""
echo "3. Verify installation:"
echo "   psql -d osm_notes -c 'SELECT pgml.version();'"
echo ""
