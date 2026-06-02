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

# Проверка прав
#if [ "$EUID" -eq 0 ]; then
#    echo -e "${RED}Do not run as root. Run as normal user with sudo privileges${NC}"
#    exit 1
#fi

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
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
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
    
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    echo -e "${GREEN}Docker Compose installed${NC}"
}

# Проверка и установка зависимостей
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Update package list
    sudo apt-get update -qq
    
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        sudo apt-get install -y curl
    fi
    
    # Install git if not present
    if ! command -v git &> /dev/null; then
        sudo apt-get install -y git
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
    
    # Validate
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
    
    # Stop and remove if exists
    docker compose down 2>/dev/null || true
    
    # Build and start
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
    
    # Небольшая пауза для применения группы Docker
    if ! groups | grep -q docker; then
        echo -e "${YELLOW}Please log out and back in for Docker group changes, then run:${NC}"
        echo "  cd $(pwd) && ./install.sh"
        echo ""
        echo -e "${YELLOW}Or run the next part manually:${NC}"
        echo "  newgrp docker"
        echo "  cd $(pwd) && ./install.sh"
        exit 0
    fi
    
    get_config
    create_env
    start_container
}

# Запуск
main
