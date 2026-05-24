from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import torch

# --- Import prediction endpoints router ---
from routers.prediction import router as prediction_router

# --- FastAPI App ---
app = FastAPI(title="Trash Type Prediction API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- API Routes ---
@app.get("/")
async def read_root():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    device_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    return {
        "message": "Trash Type Prediction API",
        "endpoint": "/predict/trash_type",
        "device": device_name,
        "cuda_available": torch.cuda.is_available()
    }

@app.get("/status")
async def get_status():
    """Get API status and hardware information."""
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    status = {
        "status": "running",
        "device": str(device),
        "cuda_available": torch.cuda.is_available(),
        "optimization": {
            "mixed_precision_fp16": torch.cuda.is_available(),
            "torch_compile": True,
            "inference_mode": True,
            "warm_up": True
        }
    }
    if torch.cuda.is_available():
        status["gpu_name"] = torch.cuda.get_device_name(0)
        status["gpu_memory_gb"] = torch.cuda.get_device_properties(0).total_memory / 1e9
        status["gpu_memory_cached_mb"] = torch.cuda.memory_reserved(0) / 1e6
        status["gpu_memory_allocated_mb"] = torch.cuda.memory_allocated(0) / 1e6
    return status


# --- Include prediction endpoints router ---
app.include_router(prediction_router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

