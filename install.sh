#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SOAPbuy - Installation   ${BLUE}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git not installed${NC}"
    exit 1
fi

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose not installed${NC}"
    exit 1
fi

echo -e "${GREEN}All dependencies found${NC}"
echo ""

# Клонирование или обновление
REPO_DIR="SOAPbuybot"
if [ ! -d "$REPO_DIR" ]; then
    git clone https://github.com/Tkom3a/SOAPbuybot.git
    cd $REPO_DIR
else
    echo -e "${YELLOW}Updating repository...${NC}"
    cd $REPO_DIR
    git pull
fi

echo ""

# Функция для ввода
read_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -p "$prompt: " value
        echo "$value"
    fi
}

# Сбор настроек
echo -e "${BLUE}Bot configuration${NC}"
echo ""

echo -e "${YELLOW}How to get TELEGRAM_BOT_TOKEN:${NC}"
echo "   1. Write to @BotFather in Telegram"
echo "   2. Send /newbot command"
echo "   3. Copy the token"
echo ""
TELEGRAM_BOT_TOKEN=$(read_with_default "Enter TELEGRAM_BOT_TOKEN" "")

echo ""
echo -e "${YELLOW}How to get TELEGRAM_CHAT_ID:${NC}"
echo "   1. Write to @userinfobot in Telegram"
echo "   2. Send /start command"
echo "   3. Copy your ID (digits)"
echo ""
TELEGRAM_CHAT_ID=$(read_with_default "Enter TELEGRAM_CHAT_ID" "")

echo ""
echo -e "${YELLOW}Threshold percent for notification${NC}"
THRESHOLD_PERCENT=$(read_with_default "Threshold percent" "4.0")

echo ""
echo -e "${YELLOW}Lookback time in minutes${NC}"
LOOKBACK_MINUTES=$(read_with_default "Lookback minutes" "5")

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Verify entered data:${NC}"
echo -e "  ${YELLOW}TELEGRAM_BOT_TOKEN:${NC} ${TELEGRAM_BOT_TOKEN:0:30}..."
echo -e "  ${YELLOW}TELEGRAM_CHAT_ID:${NC} ${TELEGRAM_CHAT_ID}"
echo -e "  ${YELLOW}THRESHOLD_PERCENT:${NC} ${THRESHOLD_PERCENT}%"
echo -e "  ${YELLOW}LOOKBACK_MINUTES:${NC} ${LOOKBACK_MINUTES} min"
echo -e "${BLUE}========================================${NC}"
echo ""

read -p "Correct? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation cancelled${NC}"
    exit 1
fi

# Создание .env
echo ""
echo -e "${GREEN}Creating config file...${NC}"
cat > .env <<EOF
# SOAPbuy Configuration
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
THRESHOLD_PERCENT=${THRESHOLD_PERCENT}
LOOKBACK_MINUTES=${LOOKBACK_MINUTES}
EOF

echo -e "${GREEN}env file created${NC}"

# Запуск Docker
echo ""
echo -e "${GREEN}Starting Docker container...${NC}"
docker-compose down 2>/dev/null
docker-compose build --quiet
docker-compose up -d

sleep 3
if docker ps | grep -q soapbuy-bot; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     SOAPbuy STARTED SUCCESSFULLY     ${GREEN}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  ${GREEN}View logs:${NC} docker-compose logs -f"
    echo -e "  ${GREEN}Stop bot:${NC} docker-compose down"
    echo -e "  ${GREEN}Restart:${NC} docker-compose restart"
    echo -e "  ${GREEN}Status:${NC} docker-compose ps"
    echo ""
    echo -e "${YELLOW}Expect welcome message in Telegram${NC}"
else
    echo -e "${RED}Error starting container${NC}"
    echo -e "${YELLOW}Check logs: docker-compose logs${NC}"
    exit 1
fi
