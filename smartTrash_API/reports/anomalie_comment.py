import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import numpy as np
from datetime import datetime

class AnomalieComment:
    def __init__(self, data: pd.DataFrame):
        self.data = data
        self.model = IsolationForest(contamination=0.03, random_state=42)  # Ajusté à 3% pour réduire les faux positifs
        self.scaler = StandardScaler()

    def train_model(self):
        # Extraire les variables pertinentes
        features = ['gaz_level', 'humidity', 'temperature', 'trash_level', 'water_level', 'weight']
        X = self.data[features]

        # Normaliser les données
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        # Entraîner le modèle Isolation Forest
        model = IsolationForest(contamination=0.03, random_state=42)  # Ajusté à 3% pour réduire les faux positifs
        model.fit(X_scaled)

        # Prédire les anomalies (-1 pour anomalie, 1 pour normal)
        self.data['anomaly_score'] = model.predict(X_scaled)

    def get_anomalies(self):
        # Identifier les anomalies
        anomalies = self.data[self.data['anomaly_score'] == -1].copy()

        # Ajouter des règles basées sur domaine pour valider les anomalies
        anomalies['weight_anomaly'] = (anomalies['trash_level'] > 80) & (anomalies['weight'] < 0.1)
        anomalies['water_anomaly'] = (anomalies['trash_type'] == 'plastic') & (anomalies['water_level'] > 5)
        anomalies['temp_anomaly'] = (anomalies['temperature'] == 0) | (anomalies['temperature'] > 40)
        return anomalies

    def generate_recommendation(self):
        # Générer des recommandations pour chaque anomalie
        recommendations = []
        anomalies = self.get_anomalies()
        for index, row in anomalies.iterrows():
            rec = f"Date : {row['timestamp']}\n"
            if row['weight_anomaly']:
                rec += " - Problème urgent : Le capteur de poids semble défectueux (poubelle pleine mais poids = 0). Vérifiez et remplacez le capteur de trash_1 (Lobby) dès que possible.\n"
            if row['water_anomaly']:
                rec += " - Attention : Détection d'eau dans une poubelle pour plastique. Vérifiez s'il y a une fuite ou un capteur défectueux.\n"
            if row['temp_anomaly']:
                rec += " - Alerte : La température est anormale (0°C ou >40°C). Inspectez le capteur de température de trash_1.\n"
            if not (row['weight_anomaly'] or row['water_anomaly'] or row['temp_anomaly']):
                rec += " - Anomalie détectée, mais non spécifique. Surveillez cette poubelle et contactez un technicien si ça persiste.\n"
            rec += f"Données : Niveau de remplissage = {row['trash_level']}%, Poids = {row['weight']}kg, Température = {row['temperature']}°C\n"
            rec += "----------------------------------------\n"
            recommendations.append(rec)

        # Combiner toutes les recommandations
        recommendations_text = "".join(recommendations)

        # Ajouter un résumé général
        summary = (
            "Résumé pour l'équipe :\n"
            f"- {len(anomalies)} anomalies détectées entre le 12/06/2025 et le 15/06/2025 pour trash_1.\n"
            "- Action prioritaire : Inspecter le capteur de poids (souvent à 0 kg malgré un niveau élevé).\n"
            "- Suggestion : Planifiez une maintenance avant le 30/06/2025 pour éviter des interruptions.\n"
            "- Contactez un technicien si des fuites ou températures anormales sont confirmées.\n"
            "----------------------------------------\n"
        )
        final_text = summary + recommendations_text
        return final_text