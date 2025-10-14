#!/bin/bash

# Install git hooks for OSM-Notes-Analytics
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Installing git hooks...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if we're in a git repository
if [ ! -d "${PROJECT_ROOT}/.git" ]; then
 echo -e "${RED}❌ Not in a git repository${NC}"
 exit 1
fi

# Create .git/hooks directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/.git/hooks"

# Install pre-commit hook
if [ -f "${PROJECT_ROOT}/.git-hooks/pre-commit" ]; then
 ln -sf "../../.git-hooks/pre-commit" "${PROJECT_ROOT}/.git/hooks/pre-commit"
 chmod +x "${PROJECT_ROOT}/.git-hooks/pre-commit"
 chmod +x "${PROJECT_ROOT}/.git/hooks/pre-commit"
 echo -e "${GREEN}✅ Installed pre-commit hook${NC}"
else
 echo -e "${YELLOW}⚠️  pre-commit hook not found${NC}"
fi

# Install pre-push hook
if [ -f "${PROJECT_ROOT}/.git-hooks/pre-push" ]; then
 ln -sf "../../.git-hooks/pre-push" "${PROJECT_ROOT}/.git/hooks/pre-push"
 chmod +x "${PROJECT_ROOT}/.git-hooks/pre-push"
 chmod +x "${PROJECT_ROOT}/.git/hooks/pre-push"
 echo -e "${GREEN}✅ Installed pre-push hook${NC}"
else
 echo -e "${YELLOW}⚠️  pre-push hook not found${NC}"
fi

echo ""
echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo "Installed hooks:"
echo "  - pre-commit: Runs shellcheck, shfmt, and basic checks"
echo "  - pre-push: Runs full quality and DWH tests"
echo ""
echo "To bypass hooks (not recommended):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo ""

exit 0
