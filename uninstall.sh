#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}Removing SOAPbuy${NC}"
read -p "Are you sure? (y/n): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Stopping container...${NC}"
    docker compose down -v 2>/dev/null || true
    
    echo -e "${YELLOW}Removing image...${NC}"
    docker rmi soapbuy-bot 2>/dev/null || true
    
    echo -e "${YELLOW}Removing files...${NC}"
    cd ..
    rm -rf SOAPbuybot
    
    echo -e "${GREEN}SOAPbuy removed${NC}"
else
    echo -e "${GREEN}Removal cancelled${NC}"
fi
