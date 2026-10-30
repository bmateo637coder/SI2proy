"""Cliente REST de Gemini: sin acceso a base de datos ni SDK obsoleto."""
import json
import os
from urllib.request import Request, urlopen


def generate_text(prompt: str, *, json_mode=False) -> str:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY no configurada")
    model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    body = {"contents": [{"parts": [{"text": prompt}]}], "generationConfig": {"temperature": 0}}
    if json_mode:
        body["generationConfig"]["responseMimeType"] = "application/json"
    req = Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urlopen(req, timeout=25) as response:
        result = json.load(response)
    return result["candidates"][0]["content"]["parts"][0]["text"]
