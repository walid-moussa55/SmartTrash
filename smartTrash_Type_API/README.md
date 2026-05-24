# API SmartTrash - Prédiction du Type de Déchet

Une API FastAPI simple et performante pour prédire le type de déchet à partir d'images en utilisant un modèle DenseNet201 pré-entraîné.

## Fonctionnalités

### Prédictions de Déchet
- **Classification 10 catégories**: Classifiez les images de déchets en 10 catégories:
  - batterie, organique, carton, vêtements, verre, métal, papier, plastique, chaussures, autre
- **Téléchargement d'images**: Endpoint simple POST pour télécharger des images et obtenir des prédictions
- **Score de confiance**: Retourne le niveau de confiance (probabilité) de la prédiction
- **Temps d'inférence**: Mesure et retourne le temps d'inférence en millisecondes

### Optimisations Avancées
- **Support GPU/CUDA**: Détection automatique de GPU avec accélération CUDA
- **Précision Mixte (FP16)**: Utilise la précision float16 pour des inférences plus rapides sur GPUs modernes
- **torch.compile**: Compilation du modèle pour optimiser les performances (PyTorch 2.0+, CUDA >= 7.0)
- **Mode d'inférence optimisé**: Utilise `torch.inference_mode` pour accélérer les prédictions
- **Préchauffage du modèle**: Allocation préalable de la mémoire GPU pour des performances optimales
- **Informations matérielles détaillées**: Retourne le nom du GPU, la mémoire disponible et l'état des optimisations

### Autres Fonctionnalités
- **Architecture DenseNet201**: Modèle d'apprentissage profond pré-entraîné pour une classification précise
- **Support CORS**: Activé pour les requêtes inter-origines
- **API RESTful**: Design d'API propre et simple
- **Gestion d'erreurs robuste**: Gestion appropriée des erreurs avec codes de statut HTTP

## Structure du Projet

- `run.py` : Point d'entrée principal de FastAPI
- `routers/` : Définition des endpoints API
- `predictions/` : Modèles de prédiction
- `weights_pth/` : Poids du modèle pré-entraîné
- `requirements.txt` : Dépendances Python

## Endpoints Principaux de l'API

- `GET /` : Informations sur l'API et informations matérielles disponibles
- `GET /status` : État de l'API et détails du matériel (GPU, mémoire, optimisations)
- `POST /predict/trash_type` : Prédire le type de déchet à partir d'un fichier image

## Guide de Démarrage Rapide

1. **Installer les dépendances**:
   ```sh
   pip install -r requirements.txt
   ```

2. **Lancer l'API**:
   ```sh
   python run.py
   ```

3. **Faire une prédiction**:
   ```bash
   curl -X POST "http://localhost:8000/predict/trash_type" \
     -F "file=@chemin/vers/votre/image.jpg"
   ```

## Exemples d'Utilisation

### Python
```python
import requests

with open('image.jpg', 'rb') as f:
    files = {'file': f}
    response = requests.post('http://localhost:8000/predict/trash_type', files=files)
    print(response.json())
```

### Réponse
```json
{
  "predicted_class": "plastique",
  "confidence": 0.9856,
  "inference_time_ms": 45.32
}
```

### Vérifier l'État de l'API
```bash
curl "http://localhost:8000/status"
```

### Réponse d'État
```json
{
  "status": "running",
  "device": "cuda",
  "cuda_available": true,
  "gpu_name": "NVIDIA GeForce RTX 3090",
  "gpu_memory_gb": 24.0,
  "gpu_memory_cached_mb": 512.5,
  "gpu_memory_allocated_mb": 256.2,
  "optimization": {
    "mixed_precision_fp16": true,
    "torch_compile": true,
    "inference_mode": true,
    "warm_up": true
  }
}
```

## Exigences

- Python 3.8+
- FastAPI
- uvicorn
- PyTorch & TorchVision
- Pillow pour le traitement d'images
- CUDA 11.0+ (optionnel mais recommandé pour GPU)

## Informations sur le Modèle

Le modèle est une architecture DenseNet201 fine-tunée entraînée sur un ensemble de données de classification de déchets.
- **Entrée**: Fichier image (JPG, PNG, etc.)
- **Sortie**: Catégorie de déchet prédite avec score de confiance
- **Poids du modèle**: `weights_pth/densenet201_garbage.pth`
- **Optimisations**: FP16, torch.compile, préchauffage du modèle

## Détails des Performances

- **Inférence rapide**: ~40-100ms par image (selon le GPU)
- **Gestion GPU optimisée**: Allocation mémoire intelligente et préchauffage
- **Compatibilité matérielle**: Détection automatique des capacités CUDA
