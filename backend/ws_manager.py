from fastapi import WebSocket
from typing import List
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[WebSocket, int | None] = {}

    async def connect(self, websocket: WebSocket, tenant_id: int | None):
        await websocket.accept(subprotocol="raices")
        self.active_connections[websocket] = tenant_id

    def disconnect(self, websocket: WebSocket):
        self.active_connections.pop(websocket, None)

    async def broadcast(self, message: dict):
        # We convert to text so it's a JSON string
        text = json.dumps(message)
        for connection, tenant_id in list(self.active_connections.items()):
            if tenant_id is not None and tenant_id != message.get("id_tenant"):
                continue
            try:
                await connection.send_text(text)
            except Exception:
                self.disconnect(connection)

manager = ConnectionManager()
