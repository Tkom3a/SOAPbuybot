#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SOAPbuy - Proxy Setup   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Автоматическая настройка прокси
auto_setup() {
    echo -e "${YELLOW}Auto-configuring proxy...${NC}"
    
    # Удаляем старые прокси если есть
    sed -i '/HTTP_PROXY/d' .env
    sed -i '/HTTPS_PROXY/d' .env
    sed -i '/NO_PROXY/d' .env
    
    # Добавляем новые
    cat >> .env <<'EOF'

# Proxy for Telegram API
HTTP_PROXY=socks5://91.230.238.128:443
HTTPS_PROXY=socks5://91.230.238.128:443
NO_PROXY=localhost,127.0.0.1
EOF
    
    echo -e "${GREEN}Proxy configured${NC}"
    echo ""
    echo -e "${YELLOW}Restart bot: docker compose restart${NC}"
}

# Тест прокси
test_proxy() {
    echo -e "${YELLOW}Testing proxy connection...${NC}"
    
    PROXY_IP=$(grep HTTP_PROXY .env | cut -d'/' -f3 | cut -d':' -f1)
    PROXY_PORT=$(grep HTTP_PROXY .env | cut -d':' -f3)
    
    if curl --socks5-hostname ${PROXY_IP}:${PROXY_PORT} https://api.telegram.org -I --max-time 10 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}Proxy works${NC}"
    else
        echo -e "${RED}Proxy not working, try different server${NC}"
    fi
}

# Меню
echo -e "${BLUE}Select option:${NC}"
echo "1) Auto-configure proxy (recommended)"
echo "2) Test current proxy"
echo "3) Manually edit .env"
echo "4) Remove proxy"
echo ""

read -p "Choice [1-4]: " choice

case $choice in
    1)
        auto_setup
        ;;
    2)
        test_proxy
        ;;
    3)
        nano .env
        echo -e "${YELLOW}Restart bot: docker compose restart${NC}"
        ;;
    4)
        sed -i '/HTTP_PROXY/d' .env
        sed -i '/HTTPS_PROXY/d' .env
        sed -i '/NO_PROXY/d' .env
        echo -e "${GREEN}Proxy removed${NC}"
        echo -e "${YELLOW}Restart bot: docker compose restart${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        ;;
esac
