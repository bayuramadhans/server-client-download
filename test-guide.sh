#!/bin/bash

# Interactive testing guide for File Download System

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SERVER_URL="http://localhost:8080"

show_menu() {
    echo ""
    echo -e "${BLUE}========================================"
    echo "File Download System - Test Menu"
    echo -e "========================================${NC}"
    echo "1. Check system health"
    echo "2. List connected clients"
    echo "3. Download file from restaurant-001"
    echo "4. Download file from restaurant-002"
    echo "5. Download file from restaurant-003"
    echo "6. Download from all clients"
    echo "7. Check download status"
    echo "8. Verify downloaded files (checksums)"
    echo "9. View server logs"
    echo "10. View client logs"
    echo "11. Clean up downloads"
    echo "0. Exit"
    echo ""
}

check_health() {
    echo -e "${BLUE}Checking system health...${NC}"
    response=$(curl -s ${SERVER_URL}/health)
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

list_clients() {
    echo -e "${BLUE}Listing connected clients...${NC}"
    response=$(curl -s ${SERVER_URL}/api/clients)
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

download_file() {
    local client_id=$1
    echo -e "${BLUE}Triggering download from ${client_id}...${NC}"
    
    response=$(curl -s -X POST ${SERVER_URL}/api/download \
        -H "Content-Type: application/json" \
        -d "{\"client_id\": \"${client_id}\", \"file_path\": \"\$HOME/file_to_download.txt\"}")
    
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    
    # Extract download_id
    download_id=$(echo "$response" | grep -o '"download_id": "[^"]*"' | cut -d'"' -f4)
    
    if [ ! -z "$download_id" ]; then
        echo -e "\n${YELLOW}Download ID: ${download_id}${NC}"
        echo -e "${BLUE}Monitoring progress...${NC}\n"
        
        # Monitor progress
        for i in {1..30}; do
            sleep 2
            status=$(curl -s ${SERVER_URL}/api/downloads/${download_id})
            current_status=$(echo "$status" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
            chunks=$(echo "$status" | grep -o '"chunks_received": [0-9]*' | grep -o '[0-9]*')
            
            echo -ne "\r  Status: ${current_status} | Chunks received: ${chunks}    "
            
            if [ "$current_status" = "completed" ]; then
                echo ""
                echo -e "\n${GREEN}✓ Download completed!${NC}"
                echo "$status" | python3 -m json.tool 2>/dev/null
                break
            elif [ "$current_status" = "failed" ]; then
                echo ""
                echo -e "\n${RED}✗ Download failed${NC}"
                echo "$status" | python3 -m json.tool 2>/dev/null
                break
            fi
        done
    fi
}

download_all() {
    echo -e "${BLUE}Downloading from all clients...${NC}\n"
    download_file "restaurant-001"
    echo ""
    download_file "restaurant-002"
    echo ""
    download_file "restaurant-003"
}

check_download_status() {
    echo -e "${YELLOW}Enter download ID:${NC} "
    read download_id
    
    if [ -z "$download_id" ]; then
        echo -e "${RED}Download ID cannot be empty${NC}"
        return
    fi
    
    echo -e "${BLUE}Checking status for download: ${download_id}${NC}"
    response=$(curl -s ${SERVER_URL}/api/downloads/${download_id})
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

verify_files() {
    echo -e "${BLUE}Verifying downloaded files...${NC}\n"
    
    if [ ! -f checksums.txt ]; then
        echo -e "${RED}checksums.txt not found. Run setup.sh first.${NC}"
        return
    fi
    
    # Check each downloaded file
    for file in downloads/*_file_to_download.txt; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo -e "${YELLOW}Checking: ${filename}${NC}"
            
            # Determine which client this came from
            if [[ $filename == *"restaurant-001"* ]]; then
                original="test-files/restaurant-001/file_to_download.txt"
            elif [[ $filename == *"restaurant-002"* ]]; then
                original="test-files/restaurant-002/file_to_download.txt"
            elif [[ $filename == *"restaurant-003"* ]]; then
                original="test-files/restaurant-003/file_to_download.txt"
            else
                echo -e "${RED}  Could not determine source client${NC}"
                continue
            fi
            
            # Compare checksums
            original_md5=$(md5sum "$original" | cut -d' ' -f1)
            downloaded_md5=$(md5sum "$file" | cut -d' ' -f1)
            
            if [ "$original_md5" = "$downloaded_md5" ]; then
                echo -e "${GREEN}  ✓ Checksum match! File integrity verified.${NC}"
            else
                echo -e "${RED}  ✗ Checksum mismatch! File may be corrupted.${NC}"
            fi
            echo "  Original:   $original_md5"
            echo "  Downloaded: $downloaded_md5"
            echo ""
        fi
    done
    
    if [ $(ls downloads/*_file_to_download.txt 2>/dev/null | wc -l) -eq 0 ]; then
        echo -e "${YELLOW}No downloaded files found in ./downloads/${NC}"
    fi
}

view_server_logs() {
    echo -e "${BLUE}Server logs (last 50 lines):${NC}"
    docker-compose logs --tail=50 server
}

view_client_logs() {
    echo ""
    echo "Available clients:"
    echo "  1. restaurant-001"
    echo "  2. restaurant-002"
    echo "  3. restaurant-003"
    echo -e "${YELLOW}Enter client number (1-3):${NC} "
    read client_num
    
    case $client_num in
        1) docker-compose logs --tail=50 client-restaurant-001 ;;
        2) docker-compose logs --tail=50 client-restaurant-002 ;;
        3) docker-compose logs --tail=50 client-restaurant-003 ;;
        *) echo -e "${RED}Invalid selection${NC}" ;;
    esac
}

cleanup_downloads() {
    echo -e "${YELLOW}This will delete all files in ./downloads/${NC}"
    echo -e "${YELLOW}Are you sure? (yes/no):${NC} "
    read confirm
    
    if [ "$confirm" = "yes" ]; then
        rm -f downloads/*
        echo -e "${GREEN}✓ Downloads directory cleaned${NC}"
    else
        echo -e "${BLUE}Cleanup cancelled${NC}"
    fi
}

# Main loop
while true; do
    show_menu
    echo -e "${YELLOW}Enter your choice:${NC} "
    read choice
    
    case $choice in
        1) check_health ;;
        2) list_clients ;;
        3) download_file "restaurant-001" ;;
        4) download_file "restaurant-002" ;;
        5) download_file "restaurant-003" ;;
        6) download_all ;;
        7) check_download_status ;;
        8) verify_files ;;
        9) view_server_logs ;;
        10) view_client_logs ;;
        11) cleanup_downloads ;;
        0) 
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
done