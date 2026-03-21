import json
from fastapi import APIRouter, HTTPException
from bson.json_util import dumps
from pymongo.errors import AutoReconnect


from others.models import WasteCollectionRequest, WasteCollectionResponse
from others.population_stats import get_bin_usage_by_region, get_fill_rate_by_bin, get_population_by_bin, get_trash_weight_correlation
from services.rotage import optimize_waste_collection
from others.database import MongoDB

router = APIRouter()
db_mongo = MongoDB()

@router.post("/optimize", response_model=WasteCollectionResponse)
async def optimize_route(request: WasteCollectionRequest):
    try:
        ordered_bins, total_volume, total_weight = optimize_waste_collection(request.model_dump())
        return {
            "ordered_bins": ordered_bins,
            "total_volume": total_volume,
            "total_weight": total_weight
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/resource-management")
def get_resource_management_data():
    """Endpoint pour la gestion des ressources (utilise bin_data2)"""
    try:
        data = list(db_mongo.bins_current.find({}, {'_id': 0}))
        return json.loads(dumps(data))
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/bin-analytics")
def get_bin_analytics_data():
    """Endpoint pour les analyses de poubelles (utilise bin_data)"""
    try:
        data = list(db_mongo.get_all_data())
        return json.loads(dumps(data))
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/api/population-by-bin")
def population_by_bin_endpoint():
    """Provides the number of users per bin."""
    try:
        return get_population_by_bin(db_mongo.get_all_data())
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/api/usage-by-region")
def usage_by_region_endpoint():
    """Provides the usage counts for bins, grouped by region."""
    try:
        return get_bin_usage_by_region(db_mongo.get_all_data())
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/api/trash-weight-correlation")
def trash_weight_correlation_endpoint():
    """Provides data points for the correlation scatter plot."""
    try:
        return get_trash_weight_correlation(db_mongo.get_all_data())
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/api/fill-rate-by-bin")
def fill_rate_by_bin_endpoint():
    """Provides the average fill rate (% per hour) for each bin."""
    try:
        return get_fill_rate_by_bin(db_mongo.get_all_data())
    except AutoReconnect:
        raise HTTPException(status_code=503, detail="MongoDB connection lost. Please try again later.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))