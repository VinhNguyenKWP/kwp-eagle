# tests/test_core_chat.py
import pytest
from kwp_core import ChatMessageIn, OutboundExecutor, Responder, handle_incoming

class SpyBot:
    def __init__(self):
        self.calls = []  # list of dicts: {"type": "message"|"photo", ...}

    async def send_message(self, chat_id, text, **kwargs):
        self.calls.append({"type": "message", "chat_id": chat_id, "text": text, "kwargs": kwargs})

    async def send_photo(self, chat_id, photo, **kwargs):
        self.calls.append({"type": "photo", "chat_id": chat_id, "photo": photo, "kwargs": kwargs})

@pytest.mark.asyncio
async def test_help_command_sends_menu():
    bot = SpyBot()
    executor = OutboundExecutor(telegram_bot=bot)
    msg = ChatMessageIn(
        channel="telegram",
        chat_id="123456",
        user_id="u1",
        text="/help",
        photos=[],
        meta={}
    )
    rsp = Responder(executor, channel="telegram", chat_id=msg.chat_id)

    await handle_incoming(msg, responder=rsp)

    # Đã gửi đúng 1 message
    assert len(bot.calls) == 1
    call = bot.calls[0]
    assert call["type"] == "message"
    assert call["chat_id"] == "123456"

    # Nội dung kỳ vọng có các dòng chính
    text = call["text"]
    for must in [
        "📋 Danh sách chức năng bạn có thể dùng:",
        "/start",
        "/chamcong",
        "/ungluong",
        "/thucdon",
        "/help",
    ]:
        assert must in text
