#!/usr/bin/env bash
#
# install-parallel.sh - Install GNU Parallel for improved performance
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Installing GNU Parallel for improved cluster-snapshot.sh performance...${NC}\n"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ "$(uname -s)" = "Darwin" ]; then
    OS="macos"
else
    echo -e "${RED}Unable to detect operating system${NC}"
    exit 1
fi

# Install based on OS
case "$OS" in
    ubuntu|debian)
        echo "Detected Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y parallel
        ;;
    fedora|rhel|centos)
        echo "Detected Fedora/RHEL/CentOS"
        sudo dnf install -y parallel || sudo yum install -y parallel
        ;;
    arch|manjaro)
        echo "Detected Arch Linux"
        sudo pacman -S --noconfirm parallel
        ;;
    macos)
        echo "Detected macOS"
        if command -v brew &> /dev/null; then
            brew install parallel
        else
            echo -e "${RED}Homebrew not found. Please install Homebrew first: https://brew.sh${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Unsupported OS: $OS${NC}"
        echo "Please install GNU Parallel manually:"
        echo "  - Debian/Ubuntu: sudo apt install parallel"
        echo "  - Fedora/RHEL: sudo dnf install parallel"
        echo "  - macOS: brew install parallel"
        exit 1
        ;;
esac

# Verify installation
if command -v parallel &> /dev/null; then
    echo -e "\n${GREEN}✓ GNU Parallel installed successfully!${NC}"
    parallel --version | head -3
    echo -e "\n${GREEN}cluster-snapshot.sh will now run much faster!${NC}"
else
    echo -e "\n${RED}Installation failed. Please install manually.${NC}"
    exit 1
fi
