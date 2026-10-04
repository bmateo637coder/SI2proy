from fastapi import WebSocket
from typing import List
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        # We convert to text so it's a JSON string
        text = json.dumps(message)
        for connection in self.active_connections:
            try:
                await connection.send_text(text)
            except:
                pass

manager = ConnectionManager()
