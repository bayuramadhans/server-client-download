#!/bin/bash

# Setup script for File Download System Docker simulation

set -e

echo "========================================"
echo "File Download System - Docker Setup"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create directory structure
echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p test-files/restaurant-001
mkdir -p test-files/restaurant-002
mkdir -p test-files/restaurant-003
mkdir -p downloads

# Generate test files (100MB each)
echo -e "${BLUE}Generating test files (100MB each)...${NC}"
echo "This may take a minute..."

# Restaurant 1 - Random data
if [ ! -f test-files/restaurant-001/file_to_download.txt ]; then
    echo -e "  Creating file for restaurant-001..."
    dd if=/dev/urandom of=test-files/restaurant-001/file_to_download.txt bs=1M count=100 2>/dev/null
    echo -e "${GREEN}  ✓ restaurant-001/file_to_download.txt created (100MB)${NC}"
else
    echo -e "${YELLOW}  ℹ restaurant-001/file_to_download.txt already exists${NC}"
fi

# Restaurant 2 - Different content
if [ ! -f test-files/restaurant-002/file_to_download.txt ]; then
    echo -e "  Creating file for restaurant-002..."
    dd if=/dev/urandom of=test-files/restaurant-002/file_to_download.txt bs=1M count=100 2>/dev/null
    echo -e "${GREEN}  ✓ restaurant-002/file_to_download.txt created (100MB)${NC}"
else
    echo -e "${YELLOW}  ℹ restaurant-002/file_to_download.txt already exists${NC}"
fi

# Restaurant 3 - Different content
if [ ! -f test-files/restaurant-003/file_to_download.txt ]; then
    echo -e "  Creating file for restaurant-003..."
    dd if=/dev/urandom of=test-files/restaurant-003/file_to_download.txt bs=1M count=100 2>/dev/null
    echo -e "${GREEN}  ✓ restaurant-003/file_to_download.txt created (100MB)${NC}"
else
    echo -e "${YELLOW}  ℹ restaurant-003/file_to_download.txt already exists${NC}"
fi

# Calculate checksums for verification later
echo -e "\n${BLUE}Calculating checksums for verification...${NC}"
echo "restaurant-001:" > checksums.txt
md5sum test-files/restaurant-001/file_to_download.txt >> checksums.txt
echo "restaurant-002:" >> checksums.txt
md5sum test-files/restaurant-002/file_to_download.txt >> checksums.txt
echo "restaurant-003:" >> checksums.txt
md5sum test-files/restaurant-003/file_to_download.txt >> checksums.txt
echo -e "${GREEN}✓ Checksums saved to checksums.txt${NC}"

# Set permissions
echo -e "\n${BLUE}Setting permissions...${NC}"
chmod -R 755 test-files/
chmod 644 test-files/*/file_to_download.txt

echo -e "\n${GREEN}========================================"
echo "Setup Complete!"
echo "========================================${NC}"
echo ""
echo "Directory structure:"
echo "  ├── test-files/"
echo "  │   ├── restaurant-001/file_to_download.txt (100MB)"
echo "  │   ├── restaurant-002/file_to_download.txt (100MB)"
echo "  │   └── restaurant-003/file_to_download.txt (100MB)"
echo "  └── downloads/ (downloads will appear here)"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Build and start containers: ${YELLOW}docker-compose up --build${NC}"
echo "  2. Follow the testing guide in test-guide.sh"
echo ""