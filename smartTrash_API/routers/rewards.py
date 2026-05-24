from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import db, messaging
from datetime import datetime, timezone
import asyncio

router = APIRouter(prefix="/reward", tags=["Rewards"])

# ── Trash-type coefficients ───────────────────────────────────────────────────
TYPE_COEFFICIENTS: dict[str, float] = {
    "paper":    1.0,
    "cardboard": 1.0,
    "plastic":  2.0,
    "glass":    3.0,
    "metal":    4.0,
    "organic":  0.5,
    "food":     0.5,
}
DEFAULT_COEFFICIENT = 1.0

DEFAULT_SCORE_THRESHOLD = 100


def get_coefficient(trash_type: str) -> float:
    return TYPE_COEFFICIENTS.get(trash_type.lower().strip(), DEFAULT_COEFFICIENT)


def compute_bonus(base_bonus: int, weight_added: float, trash_type: str) -> int:
    coeff = get_coefficient(trash_type)
    raw = base_bonus + weight_added * coeff
    return max(-1, round(raw))


# ── Request / Response models ─────────────────────────────────────────────────

class DepositRequest(BaseModel):
    user_id: str
    bin_id: str
    trash_type_predicted: str
    weight_before: float


class DepositResponse(BaseModel):
    bonus: int
    total_score: int
    type_match: bool
    weight_added: float
    type_coefficient: float
    ticket_won: bool
    message: str


# ── Helper: write deposit + update score ─────────────────────────────────────

def _process_deposit(
    user_id: str,
    bin_id: str,
    bin_type: str,
    trash_type_predicted: str,
    weight_before: float,
    weight_after: float,
) -> DepositResponse:
    weight_added = max(0.0, weight_after - weight_before)
    type_match = trash_type_predicted.lower().strip() == bin_type.lower().strip()
    base_bonus = 1 if type_match else -1
    bonus = compute_bonus(base_bonus, weight_added, trash_type_predicted)
    coeff = get_coefficient(trash_type_predicted)

    # Read current score
    user_ref = db.reference(f"users/{user_id}")
    user_data = user_ref.get() or {}
    current_score: int = int(user_data.get("score", 0))
    score_threshold: int = int(user_data.get("score_threshold", DEFAULT_SCORE_THRESHOLD))

    new_score = current_score + bonus

    # Write deposit record
    deposits_ref = db.reference(f"users/{user_id}/deposits")
    deposits_ref.push({
        "bin_id": bin_id,
        "bin_type": bin_type,
        "trash_type": trash_type_predicted,
        "match": type_match,
        "bonus": bonus,
        "weight_added": round(weight_added, 3),
        "type_coefficient": coeff,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })

    # Update score
    user_ref.update({"score": new_score})

    # Check threshold → award ticket
    ticket_won = False
    if new_score >= score_threshold:
        db.reference(f"users/{user_id}/rewards").push({
            "type": "ticket",
            "awarded_at": datetime.now(timezone.utc).isoformat(),
            "score_at_award": new_score,
        })
        # Reset score after winning
        user_ref.update({"score": 0})
        new_score = 0
        ticket_won = True

        # Send FCM to user's token if available
        fcm_token = user_data.get("fcm_token")
        if fcm_token:
            try:
                msg = messaging.Message(
                    notification=messaging.Notification(
                        title="🎉 You won a ticket!",
                        body=f"Congratulations! You reached {score_threshold} recycling points and earned a reward ticket!",
                    ),
                    data={
                        "screen": "gamification",
                        "event": "ticket_won",
                    },
                    token=fcm_token,
                )
                messaging.send(msg)
            except Exception as e:
                print(f"FCM ticket notification failed for {user_id}: {e}")

    msg_text = (
        f"🎉 Ticket won! Keep recycling!" if ticket_won
        else (f"+{bonus} pts — Great recycling! ({trash_type_predicted} matched {bin_type})" if type_match
              else f"{bonus} pt — Wrong bin ({trash_type_predicted} ≠ {bin_type})")
    )

    return DepositResponse(
        bonus=bonus,
        total_score=new_score,
        type_match=type_match,
        weight_added=round(weight_added, 3),
        type_coefficient=coeff,
        ticket_won=ticket_won,
        message=msg_text,
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/deposit", response_model=DepositResponse)
async def reward_deposit(req: DepositRequest):
    """
    Called by the Flutter app after a deposit.
    Reads current bin weight from Firebase, waits up to 15 s for the
    weight to change (servo close), then computes reward.
    """
    try:
        bin_ref = db.reference(f"trash_bins/{req.bin_id}")
        bin_data = bin_ref.get()
        if not bin_data:
            raise HTTPException(status_code=404, detail=f"Bin '{req.bin_id}' not found in Firebase.")

        bin_type: str = bin_data.get("trash_type", "unknown")
        weight_before = req.weight_before

        # ── Poll up to 15 s for weight to update after servo closes ──────────
        weight_after = weight_before
        for _ in range(15):
            await asyncio.sleep(1)
            fresh = bin_ref.get() or {}
            w = float(fresh.get("weight", weight_before))
            if abs(w - weight_before) >= 0.01:   # detected change
                weight_after = w
                break
        else:
            # No change detected — use whatever is currently in Firebase
            fresh = bin_ref.get() or {}
            weight_after = float(fresh.get("weight", weight_before))

        return _process_deposit(
            user_id=req.user_id,
            bin_id=req.bin_id,
            bin_type=bin_type,
            trash_type_predicted=req.trash_type_predicted,
            weight_before=weight_before,
            weight_after=weight_after,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/score/{user_id}")
async def get_user_score(user_id: str):
    """Returns the user's current score, threshold, and recent deposit history."""
    try:
        user_ref = db.reference(f"users/{user_id}")
        user_data = user_ref.get()
        if not user_data:
            return {"user_id": user_id, "score": 0, "score_threshold": DEFAULT_SCORE_THRESHOLD, "deposits": []}

        score = int(user_data.get("score", 0))
        threshold = int(user_data.get("score_threshold", DEFAULT_SCORE_THRESHOLD))

        raw_deposits = user_data.get("deposits", {}) or {}
        deposits = sorted(
            [{"id": k, **v} for k, v in raw_deposits.items()],
            key=lambda d: d.get("timestamp", ""),
            reverse=True,
        )[:20]

        raw_rewards = user_data.get("rewards", {}) or {}
        rewards = sorted(
            [{"id": k, **v} for k, v in raw_rewards.items()],
            key=lambda r: r.get("awarded_at", ""),
            reverse=True,
        )[:10]

        return {
            "user_id": user_id,
            "score": score,
            "score_threshold": threshold,
            "deposits": deposits,
            "rewards": rewards,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
