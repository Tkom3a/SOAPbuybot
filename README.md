# SOAPbuy - QUAI Price Monitoring Bot

Telegram bot for monitoring QUAI prices. 

## Quick Install

git clone https://github.com/Tkom3a/SOAPbuybot.git && cd SOAPbuybot && chmod +x install.sh && ./install.sh  

## OR  

git clone https://github.com/Tkom3a/SOAPbuybot.git    
cd SOAPbuybot    
chmod +x install.sh    
./install.sh    

##For Russia-based users (Telegram blocked)  
If you don't receive Telegram messages, run the proxy setup:  

chmod +x proxy-setup.sh  
./proxy-setup.sh  

## Commands  

docker-compose logs -f      # View logs  
docker-compose down         # Stop bot  
docker-compose up -d        # Start bot  
docker-compose restart      # Restart bot  
docker-compose ps           # Check status  

## Configuration  

Edit .env file:  

TELEGRAM_BOT_TOKEN=your_token  
TELEGRAM_CHAT_ID=your_chat_id  
THRESHOLD_PERCENT=4.0  
LOOKBACK_MINUTES=5  

## Uninstall  

./uninstall.sh
