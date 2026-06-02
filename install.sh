#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SOAPbuy - Installer   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка Docker
check_docker() {
    echo -e "${YELLOW}Checking Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not installed${NC}"
        echo -e "${YELLOW}Install Docker: https://docs.docker.com/engine/install/${NC}"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose not installed${NC}"
        echo -e "${YELLOW}Install Docker Compose: https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Docker OK${NC}"
}

# Запрос настроек
get_config() {
    echo ""
    echo -e "${BLUE}Telegram Configuration${NC}"
    echo -e "${YELLOW}How to get TELEGRAM_BOT_TOKEN:${NC}"
    echo "   1. Write to @BotFather in Telegram"
    echo "   2. Send /newbot command"
    echo "   3. Copy the token"
    echo ""
    read -p "Enter TELEGRAM_BOT_TOKEN: " TELEGRAM_BOT_TOKEN

    echo ""
    echo -e "${YELLOW}How to get TELEGRAM_CHAT_ID:${NC}"
    echo "   1. Write to @userinfobot in Telegram"
    echo "   2. Send /start command"
    echo "   3. Copy your ID (digits)"
    echo ""
    read -p "Enter TELEGRAM_CHAT_ID: " TELEGRAM_CHAT_ID

    echo ""
    echo -e "${BLUE}Monitoring Settings${NC}"
    read -p "Threshold percent for notification [4.0]: " THRESHOLD_PERCENT
    THRESHOLD_PERCENT=${THRESHOLD_PERCENT:-4.0}

    read -p "Lookback time in minutes [5]: " LOOKBACK_MINUTES
    LOOKBACK_MINUTES=${LOOKBACK_MINUTES:-5}

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo -e "${RED}TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are required${NC}"
        exit 1
    fi
}

# Создание .env файла
create_env() {
    echo ""
    echo -e "${YELLOW}Creating .env file...${NC}"

    cat > .env <<EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
THRESHOLD_PERCENT=${THRESHOLD_PERCENT}
LOOKBACK_MINUTES=${LOOKBACK_MINUTES}
EOF

    echo -e "${GREEN}.env file created${NC}"
}

# Запуск контейнера
start_container() {
    echo ""
    echo -e "${YELLOW}Starting Docker container...${NC}"

    docker compose down 2>/dev/null || true
    docker compose up -d --build

    sleep 3

    if docker ps | grep -q soapbuy-bot; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}     SOAPbuy STARTED SUCCESSFULLY     ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${BLUE}Useful commands:${NC}"
        echo -e "  ${GREEN}View logs:${NC} docker compose logs -f"
        echo -e "  ${GREEN}Stop bot:${NC} docker compose down"
        echo -e "  ${GREEN}Restart:${NC} docker compose restart"
        echo -e "  ${GREEN}Status:${NC} docker ps"
        echo ""
        echo -e "${YELLOW}Check Telegram for welcome message${NC}"
        echo ""
        echo -e "${BLUE}========================================${NC}"
    else
        echo -e "${RED}Error starting container${NC}"
        echo -e "${YELLOW}Check logs: docker compose logs${NC}"
        exit 1
    fi
}

# Основной процесс
main() {
    check_docker
    get_config
    create_env
    start_container
}

main
