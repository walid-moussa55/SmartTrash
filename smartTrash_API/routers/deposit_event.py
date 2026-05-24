from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import db
from datetime import datetime, timezone

router = APIRouter(prefix="/deposit", tags=["Deposit Event"])

# Shared in-memory session store: bin_id → pending session data
# Format: { bin_id: { user_id, trash_type_predicted, weight_before, created_at } }
_pending_sessions: dict = {}

class DepositCloseEvent(BaseModel):
    """
    Sent by the ESP32 after the servo closes or refuses to open.
    The ESP32 does NOT need to know the user_id — the Flutter app registers
    the session beforehand via POST /deposit/session.
    """
    bin_id: str
    weight_after: float
    deposit_event: bool = True  # must be True to trigger reward logic
    arduino_detected_type: str = None


class DepositSession(BaseModel):
    """
    Sent by the Flutter app BEFORE the bin opens, to register the user session.
    """
    bin_id: str
    user_id: str
    trash_type_predicted: str
    weight_before: float


@router.post("/session")
async def register_deposit_session(req: DepositSession):
    """
    Flutter calls this BEFORE scanning the QR / opening the bin.
    Stores user session so the close-event from ESP32 can find it.
    """
    _pending_sessions[req.bin_id] = {
        "user_id": req.user_id,
        "trash_type_predicted": req.trash_type_predicted,
        "weight_before": req.weight_before,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    return {"status": "session_registered", "bin_id": req.bin_id}


@router.post("/close")
async def deposit_close(req: DepositCloseEvent):
    """
    Called by the ESP32 after the servo closes (one-shot POST).
    Triggers reward calculation if a pending session exists for this bin.
    """
    if not req.deposit_event:
        return {"status": "ignored", "reason": "deposit_event flag not set"}

    session = _pending_sessions.pop(req.bin_id, None)
    if not session:
        return {
            "status": "no_session",
            "reason": f"No pending deposit session found for bin '{req.bin_id}'. "
                      "Make sure the Flutter app called POST /deposit/session first.",
        }

    try:
        # Lazy import to avoid circular dependency with rewards router
        from routers.rewards import _process_deposit

        # Fetch bin_type from Firebase
        bin_data = db.reference(f"trash_bins/{req.bin_id}").get() or {}
        bin_type: str = bin_data.get("trash_type", "unknown")

        # ── CHEAT PREVENTION ──────────────────────────────────────────────────
        # If the Arduino's local camera detected a mismatch and refused to open,
        # override the app's initial prediction so the user is penalized.
        actual_prediction = session["trash_type_predicted"]
        if req.arduino_detected_type and req.arduino_detected_type.lower() != "unknown":
            if req.arduino_detected_type.lower() != bin_type.lower():
                actual_prediction = req.arduino_detected_type

        result = _process_deposit(
            user_id=session["user_id"],
            bin_id=req.bin_id,
            bin_type=bin_type,
            trash_type_predicted=actual_prediction,
            weight_before=session["weight_before"],
            weight_after=req.weight_after,
        )

        return {
            "status": "processed",
            "bin_id": req.bin_id,
            "user_id": session["user_id"],
            "bonus": result.bonus,
            "total_score": result.total_score,
            "type_match": result.type_match,
            "weight_added": result.weight_added,
            "ticket_won": result.ticket_won,
            "message": result.message,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sessions")
async def list_sessions():
    """Debug endpoint — lists all pending deposit sessions."""
    return {"pending_sessions": _pending_sessions}
