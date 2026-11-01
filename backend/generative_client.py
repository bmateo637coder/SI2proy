"""Cliente REST de Gemini: sin acceso a base de datos ni SDK obsoleto."""
import json
import os
import re
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class GeminiError(RuntimeError):
    """Mensaje apto para el usuario; nunca contiene credenciales ni respuesta cruda."""


def generate_text(prompt: str, *, json_mode=False) -> str:
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        raise GeminiError("La IA generativa no está configurada. Agregue GEMINI_API_KEY al backend en Render.")
    model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
    if not re.fullmatch(r'[a-zA-Z0-9._-]+', model):
        raise GeminiError("GEMINI_MODEL no es válido. Revise la configuración del backend.")
    body = {"contents": [{"parts": [{"text": prompt}]}], "generationConfig": {"temperature": 0, "maxOutputTokens": 4096}}
    if json_mode:
        body["generationConfig"]["responseMimeType"] = "application/json"
    req = Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": key})
    try:
        with urlopen(req, timeout=25) as response:
            result = json.load(response)
    except HTTPError as error:
        messages = {400: 'Gemini rechazó la solicitud. Revise la clave y el modelo configurado.',
            401: 'La clave de Gemini no es válida.', 403: 'La clave no tiene acceso a Gemini.',
            404: 'El modelo de Gemini no está disponible. Actualice GEMINI_MODEL.',
            429: 'Se alcanzó la cuota de Gemini. Revise la cuota en Google AI Studio e intente más tarde.'}
        raise GeminiError(messages.get(error.code, 'Gemini no está disponible temporalmente. Intente más tarde.')) from None
    except (TimeoutError, URLError, ValueError):
        raise GeminiError('No se pudo obtener una respuesta de Gemini. Intente nuevamente.') from None
    if not isinstance(result, dict):
        raise GeminiError('Gemini devolvió una respuesta no válida. Intente nuevamente.')
    candidates = result.get('candidates') or []
    parts = candidates[0].get('content', {}).get('parts', []) if candidates else []
    output = ''.join(p.get('text', '') for p in parts if not p.get('thought'))
    if not output.strip():
        raise GeminiError('Gemini no produjo una respuesta utilizable. Reformule la solicitud.')
    return output.strip()
