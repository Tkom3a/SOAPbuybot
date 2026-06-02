#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SOAPbuy - Automatic Installer   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Определение ОС
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS${NC}"
        exit 1
    fi
}

# Установка Docker
install_docker() {
    echo -e "${YELLOW}Installing Docker...${NC}"

    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker already installed${NC}"
        return
    fi

    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    echo -e "${GREEN}Docker installed${NC}"
}

# Установка Docker Compose V2
install_docker_compose() {
    echo -e "${YELLOW}Installing Docker Compose...${NC}"

    if docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker Compose already installed${NC}"
        return
    fi

    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    echo -e "${GREEN}Docker Compose installed${NC}"
}

# Проверка и установка зависимостей
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"

    if command -v apt-get &> /dev/null; then
        apt-get update -qq 2>/dev/null || true
    fi

    if ! command -v curl &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            apt-get install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        fi
    fi

    if ! command -v git &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            apt-get install -y git
        elif command -v yum &> /dev/null; then
            yum install -y git
        fi
    fi

    echo -e "${GREEN}Dependencies OK${NC}"
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

    sleep 5

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

        # Проверка доступности Telegram API
        echo -e "${YELLOW}Checking Telegram API connection...${NC}"
        sleep 5
        
        # Проверяем логи на наличие ошибок подключения
        if docker compose logs --tail=30 2>&1 | grep -qi "error\|failed\|timeout\|connection\|Cannot connect"; then
            echo -e "${RED}========================================${NC}"
            echo -e "${RED}  Telegram connection issue detected!  ${NC}"
            echo -e "${RED}========================================${NC}"
            echo ""
            echo -e "${YELLOW}If you are in Russia or having connection problems:${NC}"
            echo ""
            echo "1. Run the proxy setup script:"
            echo "   ./proxy-setup.sh"
            echo ""
            echo "2. Choose option 1 (Quick fix - use public proxy)"
            echo ""
            echo "3. After proxy is configured, restart the bot:"
            echo "   docker compose restart"
            echo ""
            echo -e "${YELLOW}Or manually add proxy to .env:${NC}"
            echo "   echo 'HTTP_PROXY=socks5://91.230.238.128:443' >> .env"
            echo "   echo 'HTTPS_PROXY=socks5://91.230.238.128:443' >> .env"
            echo "   docker compose restart"
            echo ""
        else
            echo -e "${GREEN}Telegram connection successful${NC}"
            echo -e "${GREEN}Check your Telegram for welcome message${NC}"
        fi

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
    detect_os
    check_dependencies
    install_docker
    install_docker_compose
    get_config
    create_env
    start_container
}

main
