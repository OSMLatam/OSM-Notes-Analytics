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

# Find all PostgreSQL versions installed
echo "Checking for installed PostgreSQL versions..."
PG_VERSIONS=$(find /usr/lib/postgresql -maxdepth 2 -name 'pg_config' -type f 2> /dev/null | sed 's|.*postgresql/\([0-9]*\)/.*|\1|' | sort -V)
if [[ -z "$PG_VERSIONS" ]]; then
 # Try alternative location
 PG_VERSIONS=$(find /usr/share/postgresql -maxdepth 2 -type d -name 'extension' 2> /dev/null | sed 's|.*postgresql/\([0-9]*\)/.*|\1|' | sort -V)
fi

if [[ -n "$PG_VERSIONS" ]]; then
 echo "Found PostgreSQL versions: $PG_VERSIONS"
fi

# Get version from psql
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
if [[ -z "$PG_VERSION" ]]; then
 echo -e "${RED}Error: PostgreSQL not found${NC}"
 exit 1
fi
echo "Using PostgreSQL ${PG_VERSION} (from psql --version)"

# Find the correct pg_config for this version
PG_CONFIG_DEFAULT=$(which pg_config)
PG_CONFIG_VERSION="/usr/lib/postgresql/${PG_VERSION}/bin/pg_config"

if [[ -f "$PG_CONFIG_VERSION" ]]; then
 PG_CONFIG_FULL="$PG_CONFIG_VERSION"
 echo "Using pg_config from PostgreSQL ${PG_VERSION}: $PG_CONFIG_FULL"
elif [[ -n "$PG_CONFIG_DEFAULT" ]]; then
 PG_CONFIG_FULL="$PG_CONFIG_DEFAULT"
 echo "Using default pg_config: $PG_CONFIG_FULL"
 echo "Version: $($PG_CONFIG_FULL --version 2> /dev/null || echo 'unknown')"
else
 echo -e "${RED}Error: pg_config not found${NC}"
 exit 1
fi

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
 binutils \
 lld \
 "postgresql-server-dev-${PG_VERSION}" \
 libpython3-dev \
 python3-pip \
 curl \
 git \
 pkg-config \
 libssl-dev \
 libopenblas-dev \
 libgomp1

# Verify linkers are available
if ! command -v ld &> /dev/null; then
 echo -e "${RED}Error: Linker 'ld' not found after installing binutils${NC}"
 exit 1
fi
echo "Linker 'ld' found: $(which ld)"

if ! command -v ld.lld &> /dev/null; then
 echo -e "${YELLOW}Warning: LLD linker not found, but continuing...${NC}"
else
 echo "LLD linker found: $(which ld.lld)"
fi

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

# Install pgrx (PostgreSQL extension framework for Rust)
echo -e "${YELLOW}Installing pgrx...${NC}"
if ! command -v cargo-pgrx &> /dev/null; then
 echo "Installing cargo-pgrx..."
 if ! cargo install --locked cargo-pgrx --version 0.12.9; then
  echo -e "${RED}Error: Failed to install cargo-pgrx${NC}"
  exit 1
 fi
else
 echo "cargo-pgrx already installed: $(cargo-pgrx --version)"
fi

# Set up PGRX_HOME (required by pgrx framework)
echo -e "${YELLOW}Setting up pgrx environment...${NC}"
# Use explicit path to avoid issues with $HOME when running as root
PGRX_HOME_DIR="${PGRX_HOME:-$HOME/.pgrx}"
export PGRX_HOME="$PGRX_HOME_DIR"
mkdir -p "$PGRX_HOME"
echo "PGRX_HOME set to: $PGRX_HOME"
echo "Current user: $(whoami)"
echo "HOME: $HOME"

# Initialize pgrx (creates config.toml)
# The correct command is 'cargo pgrx init', not 'cargo-pgrx init'
if command -v cargo-pgrx &> /dev/null; then
 echo -e "${YELLOW}Initializing pgrx for PostgreSQL ${PG_VERSION}...${NC}"
 # Use the pg_config we found earlier (for the correct PostgreSQL version)
 echo "Using pg_config: $PG_CONFIG_FULL"
 echo "pg_config version: $($PG_CONFIG_FULL --version 2> /dev/null || echo 'unknown')"

 # Initialize pgrx with explicit PostgreSQL version and pg_config path
 # The correct syntax is --pg16=/path/to/pg_config (with =)
 echo "Running: cargo pgrx init --pg${PG_VERSION}=$PG_CONFIG_FULL"

 # Try with = syntax first (this is the correct syntax)
 if cargo pgrx init --pg"${PG_VERSION}"="$PG_CONFIG_FULL"; then
  echo -e "${GREEN}pgrx initialized successfully for PostgreSQL ${PG_VERSION}${NC}"
 else
  echo -e "${YELLOW}Warning: pgrx init with = syntax failed, trying space syntax...${NC}"
  # Try with space syntax
  if cargo pgrx init --pg"${PG_VERSION}" "$PG_CONFIG_FULL"; then
   echo -e "${GREEN}pgrx initialized successfully for PostgreSQL ${PG_VERSION}${NC}"
  else
   echo -e "${YELLOW}Warning: pgrx init with pg_config path failed, trying without path...${NC}"
   # Try with just the version flag
   if cargo pgrx init --pg"${PG_VERSION}"; then
    echo -e "${GREEN}pgrx initialized successfully for PostgreSQL ${PG_VERSION}${NC}"
   else
    echo -e "${RED}Error: Failed to initialize pgrx${NC}"
    echo "This is required for building pgml. Please check:"
    echo "  1. PostgreSQL ${PG_VERSION} is installed"
    echo "  2. pg_config is in PATH: $(which pg_config)"
    echo "  3. pg_config version: $(pg_config --version)"
    echo "  4. pg_config path: $PG_CONFIG_FULL"
    echo "  5. You have permissions to write to $PGRX_HOME"
    echo ""
    echo "Trying to get help from cargo-pgrx:"
    cargo pgrx init --help || true
    exit 1
   fi
  fi
 fi

 # Verify config.toml was created
 if [[ ! -f "$PGRX_HOME/config.toml" ]]; then
  echo -e "${RED}Error: pgrx config.toml was not created${NC}"
  exit 1
 fi

 echo "pgrx config.toml created at: $PGRX_HOME/config.toml"
 echo "Config contents:"
 head -20 < "$PGRX_HOME/config.toml"
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

# pgml uses a monorepo structure - the extension is in pgml-extension/
if [[ ! -d "pgml-extension" ]]; then
 echo -e "${RED}Error: pgml-extension directory not found${NC}"
 echo "Repository structure may have changed. Please check https://github.com/postgresml/postgresml"
 exit 1
fi

# Change to the extension directory
cd pgml-extension

# Build pgml
echo -e "${YELLOW}Building pgml (this may take 10-30 minutes)...${NC}"
echo "This is a long process. Please be patient..."

# Set environment variables for build
# Use the pg_config we found earlier (for the correct PostgreSQL version)
export PG_CONFIG="$PG_CONFIG_FULL"
echo "PG_CONFIG set to: $PG_CONFIG"
CARGO_BUILD_JOBS=$(nproc)
export CARGO_BUILD_JOBS

# Set PGRX_HOME (required by pgrx framework)
export PGRX_HOME="${PGRX_HOME:-$HOME/.pgrx}"
mkdir -p "$PGRX_HOME"
echo "PGRX_HOME set to: $PGRX_HOME"

# Configure Rust linker - use standard ld if lld is not available
# Rust tries to use lld by default, but it may not be installed
if ! command -v ld.lld &> /dev/null; then
 echo -e "${YELLOW}LLD not found, configuring Rust to use standard linker...${NC}"
 # Use bfd linker (standard GNU linker) instead of lld
 export RUSTFLAGS="-C link-arg=-fuse-ld=bfd"
else
 echo "Using LLD linker: $(which ld.lld)"
fi

# CRITICAL: Ensure config.toml exists before building
# This must happen BEFORE cargo build
echo -e "${YELLOW}Ensuring pgrx config.toml exists...${NC}"

if [[ ! -f "$PGRX_HOME/config.toml" ]]; then
 echo -e "${YELLOW}config.toml not found, creating it now...${NC}"
 mkdir -p "$PGRX_HOME"

 # Use the pg_config we found earlier (for the correct PostgreSQL version)
 # Create config.toml with correct format for pgrx
 # Format: [pg16] path = "/path/to/pg_config"
 echo "Creating config.toml with:"
 echo "  Version: pg${PG_VERSION}"
 echo "  Path: $PG_CONFIG_FULL"

 cat > "$PGRX_HOME/config.toml" << EOF
[pg${PG_VERSION}]
path = "$PG_CONFIG_FULL"
EOF

 # Verify it was created
 if [[ ! -f "$PGRX_HOME/config.toml" ]]; then
  echo -e "${RED}Error: Failed to create config.toml${NC}"
  exit 1
 fi

 echo -e "${GREEN}✓ config.toml created${NC}"
 echo "Contents:"
 cat "$PGRX_HOME/config.toml"
else
 echo -e "${GREEN}✓ config.toml already exists${NC}"
fi

# Verify config.toml contains the correct version
echo -e "${YELLOW}Verifying pgrx configuration...${NC}"
if grep -q "pg${PG_VERSION}" "$PGRX_HOME/config.toml" 2> /dev/null; then
 echo -e "${GREEN}✓ pgrx config.toml contains pg${PG_VERSION}${NC}"
else
 echo -e "${RED}Error: pgrx config.toml does not contain pg${PG_VERSION}${NC}"
 echo "Config contents:"
 cat "$PGRX_HOME/config.toml"
 echo ""
 echo "Recreating config.toml with correct version..."
 cat > "$PGRX_HOME/config.toml" << EOF
[pg${PG_VERSION}]
path = "$PG_CONFIG_FULL"
EOF
 cat "$PGRX_HOME/config.toml"
fi

# Set environment variables to force pgrx to use the correct PostgreSQL version
# Use the pg_config we found earlier (for the correct PostgreSQL version)
export PGRX_PG_CONFIG_PATH="$PG_CONFIG_FULL"
export PGRX_PG_VERSION_OVERRIDE="pg${PG_VERSION}"
export PGRX_PG_VERSION="pg${PG_VERSION}"

# Also set default version in config if it doesn't exist
if ! grep -q "^default" "$PGRX_HOME/config.toml" 2> /dev/null; then
 echo "default = \"pg${PG_VERSION}\"" >> "$PGRX_HOME/config.toml"
fi

echo ""
echo "Environment variables set:"
echo "  PGRX_PG_CONFIG_PATH=$PGRX_PG_CONFIG_PATH"
echo "  PGRX_PG_VERSION_OVERRIDE=$PGRX_PG_VERSION_OVERRIDE"
echo "  PGRX_PG_VERSION=$PGRX_PG_VERSION"
echo "  PGRX_HOME=$PGRX_HOME"
echo ""
echo "Final config.toml:"
cat "$PGRX_HOME/config.toml"
echo ""

# Build with release optimizations
# CRITICAL: Force pgrx to use pg16 by setting PGRX_DEFAULT_PG_VERSION
# This prevents pgrx from auto-detecting pg17
export PGRX_DEFAULT_PG_VERSION="pg${PG_VERSION}"

echo ""
echo -e "${YELLOW}Starting build with forced PostgreSQL version...${NC}"
echo "Using: pg${PG_VERSION}"
echo "Config: $PGRX_HOME/config.toml"
echo ""

# Verify config one more time before building
if ! grep -q "pg${PG_VERSION}" "$PGRX_HOME/config.toml" 2> /dev/null; then
 echo -e "${RED}ERROR: config.toml verification failed before build!${NC}"
 echo "Expected: pg${PG_VERSION}"
 echo "Config contents:"
 cat "$PGRX_HOME/config.toml"
 exit 1
fi

# Build with explicit version override
# CRITICAL: pgml's Cargo.toml has default = ["pg17", "python"]
# We MUST disable default features and enable pg16 + python explicitly
# Python feature is required for the extension to compile
echo ""
echo -e "${YELLOW}Building pgml extension...${NC}"
echo "CRITICAL: pgml defaults to pg17, forcing pg16..."
echo "Using: cargo build --release --no-default-features --features pg16,python"

# Use cargo build (not cargo pgrx build - that command doesn't exist)
# pgrx is configured via environment variables and config.toml
# The --pg16 flag is handled by pgrx automatically via config.toml
# We need both pg16 (PostgreSQL version) and python (required feature)
cargo build --release --no-default-features --features pg16,python

# Install pgml extension
echo -e "${YELLOW}Installing pgml extension...${NC}"
# Use cargo pgrx install instead of make install
# pgrx handles the installation process for PostgreSQL extensions
# pgrx install uses the default version from config.toml or PGRX_PG_VERSION env var
if command -v cargo-pgrx &> /dev/null; then
 echo "Using: cargo pgrx install (with pg${PG_VERSION} from config.toml)"
 echo "PGRX_PG_VERSION=${PGRX_PG_VERSION}"
 echo "PGRX_HOME=${PGRX_HOME}"
 # pgrx install should use the default version from config.toml
 # But we can also explicitly set it via environment variable
 export PGRX_PG_VERSION="pg${PG_VERSION}"
 cargo pgrx install
else
 echo -e "${RED}Error: cargo-pgrx not found, cannot install extension${NC}"
 exit 1
fi

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
# Use the pg_config we found earlier (for the correct PostgreSQL version)
PG_LIBDIR=$($PG_CONFIG_FULL --pkglibdir)
PG_SHAREDIR=$($PG_CONFIG_FULL --sharedir)

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
