import asyncio
from kwp_core import ChatMessageIn, OutboundExecutor, Responder, handle_incoming

class DummyBot:
    async def send_message(self, chat_id, text, **kwargs):
        print(f"[send_message] chat_id={chat_id} text={text}")
    async def send_photo(self, chat_id, photo, **kwargs):
        print(f"[send_photo] chat_id={chat_id} photo={photo}")

async def main():
    executor = OutboundExecutor(telegram_bot=DummyBot())
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

if __name__ == "__main__":
    asyncio.run(main())
