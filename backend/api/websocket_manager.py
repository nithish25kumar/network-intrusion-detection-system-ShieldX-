import asyncio
import json

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.active: list[WebSocket] = []
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop):
        self._loop = loop

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self.active:
            self.active.remove(ws)

    async def _broadcast_async(self, message: dict):
        dead = []
        for ws in self.active:
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

    def broadcast(self, message: dict):
        """
        Thread-safe broadcast callable — this is what DetectionEngine calls
        from the (non-async) sniffer/replay thread. It schedules the actual
        send onto the FastAPI event loop.
        """
        if self._loop is None:
            return
        asyncio.run_coroutine_threadsafe(self._broadcast_async(message), self._loop)


manager = ConnectionManager()
