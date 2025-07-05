import os
import tempfile
from fastapi import APIRouter, HTTPException, Request
from typing import Optional
from utils.helper import to_python_type

# Import prediction state from the new module
from others.prediction_state import last_level_prediction
from predictions.prediction_type import TypePredictionmodel

router = APIRouter()

@router.get("/prediction")
async def get_prediction(bin_id: Optional[str] = None):
    if last_level_prediction is None:
        raise HTTPException(status_code=404, detail="No prediction available yet")
    
    if bin_id:
        if bin_id not in last_level_prediction:
            raise HTTPException(status_code=404, detail=f"No prediction found for bin ID {bin_id}")
        return last_level_prediction[bin_id]
    
    return last_level_prediction

# Initialize TypePredictionmodel
predictor = TypePredictionmodel(file_path="weights_pth/densenet201_garbage.pth")
# --- trash image prediction endpoint ---
@router.post("/predict/trash_type")
async def predict_trash_type(request: Request):
    try:
        form = await request.form()
        file = form.get("file")
        
        if not file:
            raise HTTPException(status_code=400, detail="No file provided")
        
        # Save the uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            tmp_file.write(file.file.read())
            tmp_file_path = tmp_file.name
        
        # Perform prediction
        predicted_class = predictor.predict(tmp_file_path)
        
        # Clean up temporary file
        os.remove(tmp_file_path)
        
        return {"predicted_class": predicted_class}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during prediction: {str(e)}")