from datetime import datetime, timedelta
from typing import List, Dict, Optional
from pydantic import BaseModel

# --- Data Models ---
class Location(BaseModel):
    latitude: float
    longitude: float

class TrashData(BaseModel):
    bin_id: str
    gaz_level: float
    humidity: float
    temperature: float
    location: Location
    name: str
    trash_level: float
    trash_type: str
    weight: float
    volume: Optional[float] = None
    water_level: Optional[float] = None

class BinLocation(BaseModel):
    latitude: float
    longitude: float

class Bin(BaseModel):
    name: str
    location: BinLocation
    capacity: float
    volume: float
    weight: float

class Container(BaseModel):
    name: str
    location: BinLocation
    volume: float
    weight: float

class WasteCollectionRequest(BaseModel):
    container: Container
    bins: List[Bin]

class WasteCollectionResponse(BaseModel):
    ordered_bins: List[Dict]
    total_volume: float
    total_weight: float

# Structure for storing gas information
class GazInfo(BaseModel):
    nom: str
    sources: str
    effets: str
    precaution: str

# Define a structure to hold a bin's information
class GasLevelBin(BaseModel):
    min_niveau: int
    max_niveau: int
    message: str
    gases_detected: List[GazInfo]
    recommendation: Optional[str] = None # Optional field for additional recommendations
    recommendation_1: Optional[str] = None # For critical level messages
    recommendation_2: Optional[str] = None # For critical level messages

# Define the gas data organized by bins/ranges of 'niveau'
# The 'niveau' variable is mapped from valeurGaz (0-1200) to (0-20).
# For precise mapping of original thresholds:
# SEUIL_FAIBLE (300) -> 300 * (20/1200) = 5
# SEUIL_MODERE (600) -> 600 * (20/1200) = 10
# SEUIL_ELEVE (800)  -> 800 * (20/1200) = 13.33 -> let's use 14 as the start for 'eleve'
# SEUIL_CRITIQUE (1000) -> 1000 * (20/1200) = 16.66 -> let's use 17 as the start for 'critique'

GAS_LEVEL_BINS: List[GasLevelBin] = [
    GasLevelBin(
        min_niveau=0,
        max_niveau=4, # niveau < 5 (equivalent to valeurGaz < 300)
        message="✅ Environnement sécuritaire",
        gases_detected=[
            GazInfo(nom="Air pur", sources="Environnement normal", effets="Aucun effet nocif", precaution="Aucune précaution nécessaire")
        ]
    ),
    GasLevelBin(
        min_niveau=5,
        max_niveau=9, # niveau < 10 (equivalent to valeurGaz < 600)
        message="⚠ Alerte niveau 1 - Concentration faible",
        gases_detected=[
            GazInfo(nom="Alcool (éthanol)", sources="Désinfectants, boissons, industrie", effets="Irritation yeux/voies respiratoires", precaution="Ventilation recommandée"),
            GazInfo(nom="LPG (GPL)", sources="Bouteilles de gaz, cuisinières", effets="Risque d'explosion à haute concentration", precaution="Vérifier les fuites"),
            GazInfo(nom="Fumée légère", sources="Combustion incomplète", effets="Irritation pulmonaire", precaution="Identifier la source")
        ]
    ),
    GasLevelBin(
        min_niveau=10,
        max_niveau=13, # niveau < 14 (equivalent to valeurGaz < 800)
        message="🚨 Alerte niveau 2 - Concentration modérée",
        gases_detected=[
            GazInfo(nom="Méthane (CH4)", sources="Gaz naturel, décomposition", effets="Asphyxie, explosif", precaution="Couper source si possible"),
            GazInfo(nom="Propane (C3H8)", sources="Gaz de pétrole liquéfié", effets="Explosif, narcotique à haute dose", precaution="Éviter les flammes"),
            GazInfo(nom="CO (Monoxyde de carbone)", sources="Chauffages défectueux", effets="Mortel >1000ppm", precaution="Évacuation immédiate")
        ]
    ),
    GasLevelBin(
        min_niveau=14,
        max_niveau=16, # niveau < 17 (equivalent to valeurGaz < 1000)
        message="🔥 Alerte niveau 3 - Concentration élevée!",
        gases_detected=[
            GazInfo(nom="Butane (C4H10)", sources="Briquets, carburant", effets="Perte de conscience", precaution="Pas d'étincelles"),
            GazInfo(nom="Hydrogène (H2)", sources="Batteries, industrie", effets="Explosif à 4-75% vol.", precaution="Équipement antidéflagrant"),
            GazInfo(nom="Fumée dense", sources="Incendie, combustion", effets="Détresse respiratoire", precaution="Masque à gaz requis")
        ],
        recommendation="🆘 Ventilation forcée recommandée!"
    ),
    GasLevelBin(
        min_niveau=17,
        max_niveau=20, # niveau >= 17 (equivalent to valeurGaz >= 1000)
        message="💀 ALERTE MAXIMUM - DANGER IMMÉDIAT!",
        gases_detected=[], # No specific gases listed here, as it's general danger
        recommendation_1="🚨 Évacuez la zone immédiatement!",
        recommendation_2="📞 Appelez les services d'urgence (18/112)"
    )
]