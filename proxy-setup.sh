#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SOAPbuy - Server Proxy Setup   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка прав
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root for proxy setup${NC}"
        exit 1
    fi
}

# Способ 1: Установка 3proxy (простой HTTP/SOCKS прокси)
install_3proxy() {
    echo -e "${YELLOW}Installing 3proxy...${NC}"
    
    cd /tmp
    wget https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz
    tar -xzf 0.9.4.tar.gz
    cd 3proxy-0.9.4
    make -f Makefile.Linux
    make -f Makefile.Linux install
    
    # Создаем конфиг
    mkdir -p /etc/3proxy
    cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
users admin:CL:proxy123
auth strong
allow * * * 80-88,8080-8088
proxy -a -p8080
socks -p1080
flush
EOF
    
    # Создаем systemd сервис
    cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl start 3proxy
    
    echo -e "${GREEN}3proxy installed on port 8080 (HTTP) and 1080 (SOCKS5)${NC}"
    echo -e "${YELLOW}Username: admin, Password: proxy123${NC}"
}

# Способ 2: Использование публичного прокси для бота
use_public_proxy() {
    echo -e "${YELLOW}Configuring bot to use public proxy...${NC}"
    
    # Останавливаем бота
    docker compose down
    
    # Добавляем прокси в .env
    cat >> .env <<EOF

# Proxy settings for Telegram API (Russia bypass)
HTTP_PROXY=socks5://91.230.238.128:443
HTTPS_PROXY=socks5://91.230.238.128:443
NO_PROXY=localhost,127.0.0.1
EOF
    
    # Запускаем бота
    docker compose up -d
    
    echo -e "${GREEN}Proxy configured in .env${NC}"
    echo -e "${YELLOW}Bot restarted with proxy${NC}"
}

# Способ 3: Установка Dante SOCKS прокси
install_dante() {
    echo -e "${YELLOW}Installing Dante SOCKS proxy...${NC}"
    
    apt-get update
    apt-get install -y dante-server
    
    # Бэкап конфига
    mv /etc/danted.conf /etc/danted.conf.bak
    
    # Новый конфиг
    cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: eth0 port = 1080
external: eth0
method: username none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
}
EOF
    
    systemctl restart danted
    systemctl enable danted
    
    echo -e "${GREEN}Dante SOCKS proxy installed on port 1080${NC}"
}

# Способ 4: Настройка Docker для работы через прокси
configure_docker_proxy() {
    echo -e "${YELLOW}Configuring Docker daemon to use proxy...${NC}"
    
    mkdir -p /etc/systemd/system/docker.service.d
    
    cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=socks5://91.230.238.128:443"
Environment="HTTPS_PROXY=socks5://91.230.238.128:443"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
    
    systemctl daemon-reload
    systemctl restart docker
    
    echo -e "${GREEN}Docker configured to use proxy${NC}"
    echo -e "${YELLOW}Restart bot: docker compose up -d${NC}"
}

# Способ 5: Установка MTProto прокси для сервера
install_mtproto() {
    echo -e "${YELLOW}Installing MTProto Proxy for server...${NC}"
    
    # Останавливаем старый
    docker stop mtproxy 2>/dev/null || true
    docker rm mtproxy 2>/dev/null || true
    
    # Запускаем MTProto
    docker run -d \
        --name=mtproxy \
        --restart=unless-stopped \
        --network=host \
        -p 443:443 \
        telegrammessenger/proxy:latest
    
    sleep 5
    
    SECRET=$(docker logs mtproxy 2>&1 | grep -oE '[a-f0-9]{32}' | head -1)
    IP=$(curl -s ifconfig.me)
    
    echo -e "${GREEN}MTProto proxy installed on port 443${NC}"
    echo -e "${YELLOW}Server: ${IP}${NC}"
    echo -e "${YELLOW}Port: 443${NC}"
    echo -e "${YELLOW}Secret: ${SECRET}${NC}"
    echo ""
    echo "Add these to your Telegram app to bypass blocks"
}

# Способ 6: Тест подключения
test_connection() {
    echo -e "${YELLOW}Testing connection to Telegram API...${NC}"
    
    echo -e "${BLUE}Direct connection:${NC}"
    curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" https://api.telegram.org --max-time 5 || echo "FAILED"
    
    echo ""
    echo -e "${BLUE}Through public proxy (socks5://91.230.238.128:443):${NC}"
    curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" --socks5-hostname 91.230.238.128:443 https://api.telegram.org --max-time 10 || echo "FAILED"
    
    echo ""
    if docker ps | grep -q soapbuy-bot; then
        echo -e "${BLUE}Bot logs (Telegram errors):${NC}"
        docker compose logs --tail=20 2>&1 | grep -i "telegram\|error" || echo "No errors found"
    fi
}

# Меню
echo -e "${BLUE}Select solution for server to reach Telegram API:${NC}"
echo ""
echo "1) Quick fix - Configure bot to use public proxy"
echo "2) Install local 3proxy (HTTP/SOCKS on port 8080/1080)"
echo "3) Install Dante SOCKS5 proxy (port 1080)"
echo "4) Configure Docker daemon to use proxy"
echo "5) Install MTProto proxy (for bypassing blocks)"
echo "6) Test current connection to Telegram"
echo ""
read -p "Choice [1-6]: " choice

case $choice in
    1)
        use_public_proxy
        ;;
    2)
        check_root
        install_3proxy
        echo -e "${YELLOW}Now configure bot to use your proxy:${NC}"
        echo "Add to .env:"
        echo "HTTP_PROXY=http://admin:proxy123@YOUR_SERVER_IP:8080"
        echo "HTTPS_PROXY=http://admin:proxy123@YOUR_SERVER_IP:8080"
        ;;
    3)
        check_root
        install_dante
        echo -e "${YELLOW}Now configure bot to use your proxy:${NC}"
        echo "Add to .env:"
        echo "HTTP_PROXY=socks5://YOUR_SERVER_IP:1080"
        echo "HTTPS_PROXY=socks5://YOUR_SERVER_IP:1080"
        ;;
    4)
        check_root
        configure_docker_proxy
        ;;
    5)
        check_root
        install_mtproto
        ;;
    6)
        test_connection
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}After setup:${NC}"
echo "1. Restart bot: docker compose restart"
echo "2. Check logs: docker compose logs -f"
echo "3. Verify you get Telegram messages"
echo -e "${GREEN}========================================${NC}"
