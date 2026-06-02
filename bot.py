#!/usr/bin/env python3
import asyncio
import aiohttp
import logging
import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from collections import deque

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SOAPbuyBot:
    def __init__(self):
        self.telegram_bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
        self.telegram_chat_id = os.getenv('TELEGRAM_CHAT_ID')
        self.symbol = "QUAIUSDT"
        self.lookback_minutes = int(os.getenv('LOOKBACK_MINUTES', '5'))
        self.threshold_percent = float(os.getenv('THRESHOLD_PERCENT', '4.0'))
        
        if not self.telegram_bot_token or not self.telegram_chat_id:
            raise ValueError("TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set")
        
        self.base_url = "https://api.mexc.com"
        self.price_history = deque(maxlen=100)
        self.last_price = None
        self.last_notification_time = None
        self.notification_cooldown = 60
        self.is_running = True
        
        logger.info(f"SOAPbuy bot initialized with symbol: {self.symbol}")
        logger.info(f"Threshold: {self.threshold_percent}% over {self.lookback_minutes} minutes")
        
    async def send_telegram_message(self, message: str) -> bool:
        url = f"https://api.telegram.org/bot{self.telegram_bot_token}/sendMessage"
        payload = {
            "chat_id": self.telegram_chat_id,
            "text": message,
            "parse_mode": "HTML"
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload, timeout=10) as response:
                    if response.status == 200:
                        logger.info("Telegram message sent")
                        return True
                    else:
                        text = await response.text()
                        logger.error(f"Failed to send: {text}")
                        return False
        except Exception as e:
            logger.error(f"Error sending to Telegram: {e}")
            return False
    
    async def get_current_price(self) -> Optional[float]:
        try:
            url = f"{self.base_url}/api/v3/ticker/price"
            params = {"symbol": self.symbol}
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        price = float(data["price"])
                        logger.debug(f"Current price: {price}")
                        return price
                    else:
                        logger.error(f"API error: {response.status}")
                        return None
        except Exception as e:
            logger.error(f"Error fetching price: {e}")
            return None
    
    async def send_welcome_message(self) -> None:
        current_price = await self.get_current_price()
        
        if current_price:
            current_time = datetime.now()
            self.price_history.appendleft((current_time, current_price))
            self.last_price = current_price
        
        welcome_msg = f"""
SOAPbuy - STARTED

Bot started successfully
Trading pair: {self.symbol}
Threshold: {self.threshold_percent}% over {self.lookback_minutes} minutes
Check interval: 60 seconds
"""
        
        if current_price:
            welcome_msg += f"""
Current price: ${current_price:.8f} USDT
Time: {current_time.strftime('%H:%M:%S')}

Monitoring started
"""
        else:
            welcome_msg += """
Failed to get price
Monitoring started, data will be obtained later
"""
        
        await self.send_telegram_message(welcome_msg.strip())
    
    def calculate_price_change(self, current_price: float) -> Optional[Dict[str, Any]]:
        if len(self.price_history) < 2:
            return None
        
        current_time = datetime.now()
        cutoff_time = current_time - timedelta(minutes=self.lookback_minutes)
        
        old_price = None
        old_timestamp = None
        
        for timestamp, price in self.price_history:
            if timestamp <= cutoff_time:
                old_price = price
                old_timestamp = timestamp
                break
        
        if old_price is None and len(self.price_history) > 0:
            oldest_timestamp, oldest_price = self.price_history[-1]
            age_seconds = (current_time - oldest_timestamp).total_seconds()
            if age_seconds >= 60:
                old_price = oldest_price
                old_timestamp = oldest_timestamp
        
        if old_price is None:
            return None
        
        price_change = current_price - old_price
        percent_change = (price_change / old_price) * 100
        
        return {
            "old_price": old_price,
            "current_price": current_price,
            "change": price_change,
            "percent_change": percent_change,
            "time_span": (current_time - old_timestamp).total_seconds() / 60,
            "current_timestamp": current_time
        }
    
    def should_notify(self, percent_change: float) -> bool:
        if percent_change < self.threshold_percent:
            return False
        
        if self.last_notification_time:
            time_since_last = (datetime.now() - self.last_notification_time).total_seconds()
            if time_since_last < self.notification_cooldown:
                return False
        
        return True
    
    async def check_and_notify(self, current_price: float) -> None:
        change_info = self.calculate_price_change(current_price)
        
        if not change_info:
            return
        
        percent_change = change_info["percent_change"]
        
        if self.should_notify(percent_change):
            message = f"""
SOAPbuy - PRICE INCREASE

Price increased by {percent_change:.2f}% over last {change_info['time_span']:.1f} minutes

Old price: ${change_info['old_price']:.8f}
New price: ${change_info['current_price']:.8f}
Absolute increase: +${change_info['change']:.8f}

Time: {change_info['current_timestamp'].strftime('%H:%M:%S')}
"""
            
            success = await self.send_telegram_message(message.strip())
            if success:
                self.last_notification_time = datetime.now()
                logger.info(f"Notification sent for {percent_change:.2f}% increase")
    
    async def run(self, interval_seconds: int = 60):
        logger.info("Starting SOAPbuy monitoring bot")
        await self.send_welcome_message()
        
        check_count = 0
        while self.is_running:
            try:
                current_price = await self.get_current_price()
                
                if current_price:
                    current_time = datetime.now()
                    self.price_history.appendleft((current_time, current_price))
                    self.last_price = current_price
                    
                    check_count += 1
                    if check_count % 5 == 0:
                        logger.info(f"Price: ${current_price:.8f} at {current_time.strftime('%H:%M:%S')}")
                    
                    await self.check_and_notify(current_price)
                else:
                    logger.warning("Failed to fetch price")
                
                await asyncio.sleep(interval_seconds)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                await asyncio.sleep(interval_seconds)
    
    async def close(self):
        self.is_running = False
        await self.send_telegram_message("SOAPbuy - STOPPED")
        logger.info("SOAPbuy bot stopped")


async def main():
    bot = SOAPbuyBot()
    try:
        await bot.run()
    finally:
        await bot.close()


if __name__ == "__main__":
    asyncio.run(main())
