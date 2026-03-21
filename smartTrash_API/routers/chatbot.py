import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
import os
from dotenv import load_dotenv

# Load .env file from the API root
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env"))

router = APIRouter()

# Load knowledge base once at startup
_knowledge_base = ""
_kb_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "knowledge_base.txt")
if os.path.exists(_kb_path):
    with open(_kb_path, "r", encoding="utf-8") as f:
        _knowledge_base = f.read()
    print(f"[Chatbot] Knowledge base loaded ({len(_knowledge_base)} chars)")
else:
    print(f"[Chatbot] Warning: knowledge_base.txt not found at {_kb_path}")

# Mistral AI API configuration
MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY", "")
MISTRAL_API_URL = "https://api.mistral.ai/v1/chat/completions"
MISTRAL_MODEL = os.getenv("MISTRAL_MODEL", "mistral-small-latest")


class ChatRequest(BaseModel):
    messages: List[dict]


@router.post("/api/chat")
async def chat(request: ChatRequest):
    """Eco-Assistant chatbot endpoint using Mistral AI API + RAG knowledge base."""
    if not MISTRAL_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="MISTRAL_API_KEY non configurée. Définissez la variable d'environnement MISTRAL_API_KEY."
        )

    try:
        messages = list(request.messages)

        # Inject knowledge base into system prompt
        if messages and messages[0].get("role") == "system":
            original_system = messages[0]["content"]
            if "BASE DE CONNAISSANCES" not in original_system:
                messages[0] = {
                    "role": "system",
                    "content": f"{original_system}\n\n--- BASE DE CONNAISSANCES ---\n{_knowledge_base}"
                }
        elif _knowledge_base:
            messages.insert(0, {
                "role": "system",
                "content": f"Tu es l'Eco-Assistant SmartTrash.\n\n--- BASE DE CONNAISSANCES ---\n{_knowledge_base}"
            })

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                MISTRAL_API_URL,
                headers={
                    "Authorization": f"Bearer {MISTRAL_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": MISTRAL_MODEL,
                    "messages": messages,
                },
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"Mistral API error (status {response.status_code}): {response.text}"
            )

        data = response.json()
        choices = data.get("choices", [])
        if choices:
            reply = choices[0].get("message", {}).get("content", "")
            if reply:
                return {"reply": reply}

        raise HTTPException(status_code=502, detail="Réponse vide de Mistral AI.")

    except HTTPException:
        raise
    except httpx.ConnectError:
        raise HTTPException(
            status_code=503,
            detail="Impossible de contacter l'API Mistral. Vérifiez votre connexion internet."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chatbot error: {str(e)}")
