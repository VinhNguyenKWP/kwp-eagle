import asyncio
import os
from dotenv import load_dotenv
from loguru import logger
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters

from kwp_core import ChatMessageIn, OutboundExecutor, handle_incoming, Responder

# Load .env
load_dotenv()

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
if not TELEGRAM_TOKEN:
    raise RuntimeError("⚠️ TELEGRAM_BOT_TOKEN chưa được cấu hình trong .env")

# Adapter để gửi tin nhắn qua Telegram
class TelegramOutboundBot:
    def __init__(self, application):
        self.app = application.bot

    async def send_message(self, chat_id, text, **kwargs):
        await self.app.send_message(chat_id=chat_id, text=text, **kwargs)

    async def send_photo(self, chat_id, photo, **kwargs):
        await self.app.send_photo(chat_id=chat_id, photo=photo, **kwargs)

# Handler cho lệnh /start
async def start_cmd(update, context):
    await update.message.reply_text("Xin chào! Gõ /help để xem các lệnh hỗ trợ.")

# Handler cho mọi tin nhắn (pass vào kwp_core)
async def generic_message(update, context):
    text = update.message.text or ""
    photos = []
    if update.message.photo:
        # Lấy file_id ảnh lớn nhất
        file_id = update.message.photo[-1].file_id
        photos.append(file_id)

    msg_in = ChatMessageIn(
        channel="telegram",
        chat_id=str(update.message.chat_id),
        user_id=str(update.message.from_user.id),
        text=text,
        photos=photos,
        meta={"username": update.message.from_user.username}
    )

    executor = OutboundExecutor(telegram_bot=TelegramOutboundBot(context.application))
    responder = Responder(executor, channel="telegram", chat_id=msg_in.chat_id)

    await handle_incoming(msg_in, responder)

async def main():
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()

    # Command handler cơ bản
    app.add_handler(CommandHandler("start", start_cmd))

    # Message handler cho tất cả text
    app.add_handler(MessageHandler(filters.ALL, generic_message))

    logger.info("🚀 Bot đang chạy ở chế độ polling...")
    await app.run_polling()

if __name__ == "__main__":
    asyncio.run(main())
