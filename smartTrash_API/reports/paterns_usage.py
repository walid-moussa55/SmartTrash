import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.cluster import KMeans, DBSCAN
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score
from tslearn.clustering import TimeSeriesKMeans
from tslearn.preprocessing import TimeSeriesScalerMeanVariance
from hmmlearn import hmm
import warnings
warnings.filterwarnings('ignore')

class SmartTrashPatternAnalyzer:
    def __init__(self, raw_data):
        """
        Analyseur de patterns d'usage pour poubelles intelligentes
        """
        self.data = self.load_data(raw_data)
        self.processed_data = None
        self.time_series_data = None
        self.clusters = None
        self.hmm_model = None

    def load_data(self, raw_data):
        """Charger et préprocesser les données JSON"""
        try:
            
            # Convertir en DataFrame
            df = pd.DataFrame(raw_data)

            # Traitement des colonnes MongoDB
            if '_id' in df.columns:
                df['id'] = df['_id'].apply(lambda x: x.get('$oid', x) if isinstance(x, dict) else x)
                df.drop('_id', axis=1, inplace=True)

            if 'timestamp' in df.columns:
                df['timestamp'] = df['timestamp'].apply(
                    lambda x: pd.to_datetime(x.get('$date', x) if isinstance(x, dict) else x)
                )

            # Trier par timestamp
            df = df.sort_values('timestamp').reset_index(drop=True)

            print(f"Données chargées: {len(df)} enregistrements")
            print(f"Période: {df['timestamp'].min()} à {df['timestamp'].max()}")
            print(f"Poubelles uniques: {df['bin_id'].nunique()}")

            return df

        except Exception as e:
            print(f"Erreur lors du chargement: {e}")
            return None

    def feature_engineering(self):
        """Ingénierie des caractéristiques temporelles"""
        df = self.data.copy()

        # Caractéristiques temporelles
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['day_of_month'] = df['timestamp'].dt.day
        df['month'] = df['timestamp'].dt.month
        df['is_weekend'] = df['day_of_week'].isin([5, 6]).astype(int)

        # Catégorisation des périodes
        def categorize_time(hour):
            if 6 <= hour < 12:
                return 'morning'
            elif 12 <= hour < 18:
                return 'afternoon'
            elif 18 <= hour < 22:
                return 'evening'
            else:
                return 'night'

        df['time_period'] = df['hour'].apply(categorize_time)

        # Calcul des changements de level
        df = df.sort_values(['bin_id', 'timestamp'])
        df['trash_level_change'] = df.groupby('bin_id')['trash_level'].diff().fillna(0)
        df['usage_intensity'] = df['trash_level_change'].apply(lambda x: max(0, x))

        # Indicateurs d'activité
        df['is_active'] = (df['usage_intensity'] > 5).astype(int)
        df['high_usage'] = (df['usage_intensity'] > 20).astype(int)

        self.processed_data = df
        # print("Ingénierie des caractéristiques terminée")
        return df

    def create_time_series_profiles(self):
        """Créer des profils de séries temporelles pour chaque poubelle"""
        if self.processed_data is None:
            self.feature_engineering()

        profiles = {}

        for bin_id in self.processed_data['bin_id'].unique():
            bin_data = self.processed_data[self.processed_data['bin_id'] == bin_id].copy()

            # Profil horaire moyen
            hourly_profile = bin_data.groupby('hour').agg({
                'usage_intensity': 'mean',
                'trash_level': 'mean',
                'is_active': 'mean'
            }).values

            # Profil hebdomadaire
            weekly_profile = bin_data.groupby('day_of_week').agg({
                'usage_intensity': 'mean',
                'trash_level': 'mean',
                'is_active': 'mean'
            }).values

            # Profil par période
            period_profile = bin_data.groupby('time_period').agg({
                'usage_intensity': 'mean',
                'trash_level': 'mean',
                'is_active': 'mean'
            }).values

            # Extract latitude and longitude from the 'location' dictionary
            location_data = bin_data['location'].iloc[0]
            latitude = location_data.get('latitude', None)
            longitude = location_data.get('longitude', None)


            profiles[bin_id] = {
                'hourly': hourly_profile,
                'weekly': weekly_profile,
                'period': period_profile,
                'location': [latitude, longitude],
                'name': bin_data['name'].iloc[0],
                'trash_type': bin_data['trash_type'].iloc[0]
            }

        return profiles

    def time_series_clustering(self, n_clusters=5):
        """Clustering des séries temporelles"""
        profiles = self.create_time_series_profiles()

        # Préparer les données pour le clustering
        hourly_series = []
        bin_ids = []

        for bin_id, profile in profiles.items():
            hourly_series.append(profile['hourly'][:, 0])  # usage_intensity
            bin_ids.append(bin_id)

        # Normalisation
        scaler = TimeSeriesScalerMeanVariance()
        hourly_series_scaled = scaler.fit_transform(hourly_series)

        # Clustering avec TimeSeriesKMeans
        model = TimeSeriesKMeans(n_clusters=n_clusters, metric="euclidean", random_state=42)
        cluster_labels = model.fit_predict(hourly_series_scaled)

        # Résultats
        results = pd.DataFrame({
            'bin_id': bin_ids,
            'cluster': cluster_labels
        })

        # Ajouter les informations des poubelles
        for i, (bin_id, profile) in enumerate(profiles.items()):
            results.loc[results['bin_id'] == bin_id, 'name'] = profile['name']
            results.loc[results['bin_id'] == bin_id, 'trash_type'] = profile['trash_type']
            results.loc[results['bin_id'] == bin_id, 'latitude'] = profile['location'][0]
            results.loc[results['bin_id'] == bin_id, 'longitude'] = profile['location'][1]


        self.clusters = results
        self.time_series_data = {
            'profiles': profiles,
            'series': hourly_series_scaled,
            'model': model,
            'scaler': scaler
        }

        return results

    def hidden_markov_analysis(self, n_states=4):
        """Analyse avec modèles de Markov cachés"""
        if self.processed_data is None:
            self.feature_engineering()

        # Préparer les séquences d'états pour chaque poubelle
        hmm_results = {}

        for bin_id in self.processed_data['bin_id'].unique():
            bin_data = self.processed_data[self.processed_data['bin_id'] == bin_id].copy()

            # Créer des états basés sur l'intensité d'usage
            features = bin_data[['usage_intensity', 'trash_level', 'is_active']].values

            # Normalisation
            scaler = StandardScaler()
            features_scaled = scaler.fit_transform(features)

            # Modèle HMM
            model = hmm.GaussianHMM(n_components=n_states, random_state=42)

            try:
                model.fit(features_scaled)
                states = model.predict(features_scaled)

                # Analyse des états
                state_analysis = {}
                for state in range(n_states):
                    state_mask = states == state
                    if state_mask.sum() > 0:
                        state_analysis[f'state_{state}'] = {
                            'frequency': state_mask.mean(),
                            'avg_usage': bin_data.loc[state_mask, 'usage_intensity'].mean(),
                            'avg_level': bin_data.loc[state_mask, 'trash_level'].mean(),
                            'most_common_period': bin_data.loc[state_mask, 'time_period'].mode().iloc[0] if len(bin_data.loc[state_mask, 'time_period'].mode()) > 0 else 'unknown'
                        }

                hmm_results[bin_id] = {
                    'model': model,
                    'states': states,
                    'state_analysis': state_analysis,
                    'scaler': scaler
                }

            except Exception as e:
                print(f"Erreur HMM pour {bin_id}: {e}")
                continue

        self.hmm_model = hmm_results
        return hmm_results

    def analyze_usage_patterns(self):
        """Analyse complète des patterns d'usage"""
        print("🔍 Analyse des Patterns d'Usage - Poubelles Intelligentes")
        # print("=" * 60)

        # 1. Clustering des séries temporelles
        # print("\n1. Clustering des profils temporels...")
        clusters = self.time_series_clustering()

        # 2. Analyse HMM
        # print("\n2. Analyse des états cachés (HMM)...")
        hmm_results = self.hidden_markov_analysis()

        # 3. Analyse des patterns
        # print("\n3. Résumé des patterns identifiés:")
        # print("-" * 40)

        # Patterns par cluster
        for cluster_id in clusters['cluster'].unique():
            cluster_bins = clusters[clusters['cluster'] == cluster_id]
            # print(f"\n📊 Cluster {cluster_id} ({len(cluster_bins)} poubelles):")
            # print(f"   Types de déchets: {cluster_bins['trash_type'].value_counts().to_dict()}")
            # print(f"   Poubelles: {', '.join(cluster_bins['name'].tolist())}")

        # Patterns temporels globaux
        # print(f"\n🕐 Patterns temporels globaux:")
        hourly_usage = self.processed_data.groupby('hour')['usage_intensity'].mean()
        peak_hour = hourly_usage.idxmax()
        # print(f"   Heure de pic: {peak_hour}h (intensité: {hourly_usage[peak_hour]:.1f})")

        daily_usage = self.processed_data.groupby('day_of_week')['usage_intensity'].mean()
        days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
        peak_day = daily_usage.idxmax()
        # print(f"   Jour de pic: {days[peak_day]} (intensité: {daily_usage[peak_day]:.1f})")

        weekend_vs_weekday = self.processed_data.groupby('is_weekend')['usage_intensity'].mean()
        # print(f"   Usage weekend vs semaine: {weekend_vs_weekday[1]:.1f} vs {weekend_vs_weekday[0]:.1f}")

        return {
            'clusters': clusters,
            'hmm_results': hmm_results,
            'temporal_patterns': {
                'hourly': hourly_usage.to_dict(),
                'daily': daily_usage.to_dict(),
                'weekend_vs_weekday': weekend_vs_weekday.to_dict()
            }
        }

    def generate_insights(self):
        """Générer des insights pour les politiques environnementales"""
        results = self.analyze_usage_patterns()

        insights = {
            'operational_insights': [],
            'environmental_policies': [],
            'optimization_opportunities': []
        }

        # Insights opérationnels
        clusters = results['clusters']
        for cluster_id in clusters['cluster'].unique():
            cluster_bins = clusters[clusters['cluster'] == cluster_id]
            if len(cluster_bins) > 1:
                insights['operational_insights'].append(
                    f"Cluster {cluster_id}: {len(cluster_bins)} poubelles avec des patterns similaires - "
                    f"optimisation possible des tournées de collecte"
                )

        # Insights environnementaux
        temporal = results['temporal_patterns']
        peak_hour = max(temporal['hourly'], key=temporal['hourly'].get)
        insights['environmental_policies'].append(
            f"Pic d'usage à {peak_hour}h - sensibilisation ciblée possible"
        )

        # Différences types de déchets
        type_usage = self.processed_data.groupby('trash_type')['usage_intensity'].mean()
        if len(type_usage) > 1:
            max_type = type_usage.idxmax()
            min_type = type_usage.idxmin()
            insights['environmental_policies'].append(
                f"Type '{max_type}' le plus utilisé ({type_usage[max_type]:.1f}) vs "
                f"'{min_type}' ({type_usage[min_type]:.1f}) - campagne de sensibilisation ciblée"
            )

        # Opportunités d'optimisation
        if temporal['weekend_vs_weekday'][1] > temporal['weekend_vs_weekday'][0]:
            insights['optimization_opportunities'].append(
                "Usage plus intense le weekend - ajuster la fréquence de collecte"
            )
        else:
            insights['optimization_opportunities'].append(
                "Usage plus faible le weekend - réduire la fréquence de collecte weekend"
            )

        return insights


    def generate_dynamic_report(self):
        """Générer un rapport complet adapté aux données spécifiques"""
        # Analyser les données
        results = self.analyze_usage_patterns()

        # Générer des insights basés sur les résultats de l'analyse
        insights = self.generate_insights()

        # Statistiques de base
        stats = self.get_basic_statistics()

        # Construire le rapport dynamique
        report = self.build_adaptive_report(results, insights, stats)

        return report


    def get_basic_statistics(self):
        """Calculer les statistiques de base des données"""
        if self.processed_data is None:
            self.feature_engineering()

        # Extract latitude and longitude from the 'location' dictionary before grouping
        self.data['latitude'] = self.data['location'].apply(lambda x: x.get('latitude', None))
        self.data['longitude'] = self.data['location'].apply(lambda x: x.get('longitude', None))


        stats = {
            'total_records': len(self.data),
            'total_bins': self.data['bin_id'].nunique(),
            'date_range': {
                'start': self.data['timestamp'].min(),
                'end': self.data['timestamp'].max(),
                'days': (self.data['timestamp'].max() - self.data['timestamp'].min()).days
            },
            'trash_types': self.data['trash_type'].value_counts().to_dict(),
            'locations': self.data.groupby('bin_id').agg({
                'name': 'first',
                'latitude': 'first',
                'longitude': 'first',
                'trash_type': 'first'
            }).to_dict('index'),
            'usage_stats': {
                'max_intensity': self.processed_data['usage_intensity'].max(),
                'avg_intensity': self.processed_data['usage_intensity'].mean(),
                'total_usage_events': (self.processed_data['usage_intensity'] > 0).sum()
            }
        }

        return stats

    def build_adaptive_report(self, results, insights, stats):
        """Construire un rapport adapté aux résultats spécifiques"""

        # En-tête du rapport
        report = f"""# 🌍 Rapport d'Analyse des Patterns d'Usage - Poubelles Intelligentes

## **Vue d'Ensemble des Données**

**Période d'analyse**: {stats['date_range']['start'].strftime('%d/%m/%Y')} au {stats['date_range']['end'].strftime('%d/%m/%Y')} ({stats['date_range']['days']} jours)
**Nombre d'enregistrements**: {stats['total_records']:,}
**Poubelles analysées**: {stats['total_bins']}
**Événements d'usage détectés**: {stats['usage_stats']['total_usage_events']:,}

### **Répartition par Type de Déchets**
"""

        # Ajout dynamique des types de déchets
        for trash_type, count in stats['trash_types'].items():
            percentage = (count / stats['total_bins']) * 100
            report += f"- **{trash_type.capitalize()}**: {count} poubelles ({percentage:.1f}%)\n"

        # Analyse des patterns temporels
        temporal = results['temporal_patterns']
        peak_hour = max(temporal['hourly'], key=temporal['hourly'].get)
        peak_intensity = temporal['hourly'][peak_hour]

        days_fr = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
        peak_day_idx = max(temporal['daily'], key=temporal['daily'].get)
        peak_day = days_fr[peak_day_idx]
        peak_day_intensity = temporal['daily'][peak_day_idx]

        weekend_intensity = temporal['weekend_vs_weekday'][1]
        weekday_intensity = temporal['weekend_vs_weekday'][0]

        report += f"""
## **Patterns Temporels Identifiés**

### **Rythmes de Consommation Détectés**

| Pattern Détecté | Valeur | Impact Comportemental |
|-----------------|--------|----------------------|
| **Heure de pic** | {peak_hour}h (intensité: {peak_intensity:.1f}) | Pause matinale généralisée |
| **Jour de pic** | {peak_day} (intensité: {peak_day_intensity:.1f}) | {"Préparation weekend" if peak_day_idx == 3 else "Activité hebdomadaire spécifique"} |
| **Weekend vs Semaine** | {weekend_intensity:.1f} vs {weekday_intensity:.1f} | {"Réduction activité weekend" if weekend_intensity < weekday_intensity else "Intensification weekend"} |

"""

        # Analyse des clusters - Adaptation dynamique
        clusters = results['clusters']
        unique_clusters = clusters['cluster'].nunique()

        report += f"""## **Analyse des Profils d'Usage ({unique_clusters} clusters identifiés)**

"""

        for cluster_id in sorted(clusters['cluster'].unique()):
            cluster_bins = clusters[clusters['cluster'] == cluster_id]
            cluster_size = len(cluster_bins)
            trash_types_in_cluster = cluster_bins['trash_type'].value_counts().to_dict()

            # Déterminer le profil du cluster
            if cluster_size == 1:
                profile_type = "**Profil Unique**"
                behavioral_insight = "Comportement spécialisé nécessitant une approche individualisée"
            elif cluster_size <= 3:
                profile_type = "**Profil Minoritaire**"
                behavioral_insight = "Groupe restreint avec des habitudes spécifiques"
            else:
                profile_type = "**Profil Majoritaire**"
                behavioral_insight = "Comportement collectif synchronisé - levier de changement important"

            report += f"""### **Cluster {cluster_id}** - {profile_type}

**Composition**: {cluster_size} poubelles
**Types de déchets**: {', '.join([f"{k}({v})" for k, v in trash_types_in_cluster.items()])}
**Insight comportemental**: {behavioral_insight}

**Poubelles concernées**:
"""
            for _, bin_info in cluster_bins.iterrows():
                report += f"- {bin_info['name']} ({bin_info['trash_type']})\n"

            report += "\n"

        # Politiques recommandes - Adaptation aux résultats
        report += """## **Politiques Environnementales Recommandées**

### **A. Sensibilisation Ciblée Temporelle**

"""

        # Stratégie basee sur l'heure de pic
        if 8 <= peak_hour <= 11:
            strategy_name = "Pause Verte Matinale"
            strategy_action = "Promotion des contenants réutilisables pendant les pauses café"
            strategy_target = "Réduction des déchets d'emballage matinaux"
        elif 12 <= peak_hour <= 14:
            strategy_name = "Déjeuner Responsable"
            strategy_action = "Incitation aux repas sans emballage jetable"
            strategy_target = "Diminution des déchets alimentaires"
        elif 17 <= peak_hour <= 19:
            strategy_name = "Fin de Journée Éco"
            strategy_action = "Sensibilisation anti-gaspillage en fin d'activité"
            strategy_target = "Réduction de l'accumulation de déchets"
        else:
            strategy_name = "Intervention Horaire Ciblée"
            strategy_action = "Campagne spécifique à l'heure de pic identifiée"
            strategy_target = "Optimisation du moment d'impact maximal"

        report += f"""#### **Stratégie "{strategy_name}"**
- **Objectif**: {strategy_target}
- **Action**: {strategy_action}
- **Horaire ciblé**: {peak_hour-1}h-{peak_hour+1}h
- **KPI**: Réduction de 20% de l'intensité d'usage pendant cette période

"""

        # Stratégie basée sur le jour de pic
        if peak_day_idx == 3:  # Jeudi
            day_strategy = """#### **Stratégie "Jeudi Vert"**
- **Objectif**: Réduire le pic de consommation pré-weekend
- **Action**: Campagne "Préparez votre weekend responsable"
- **Mesure**: Ateliers de sensibilisation le mercredi
- **KPI**: Réduction de 15% du pic du jeudi
"""
        elif peak_day_idx in [5, 6]:  # Weekend
            day_strategy = """#### **Stratégie "Weekend Durable"**
- **Objectif**: Optimiser l'usage weekend
- **Action**: Promotion d'activités éco-responsables
- **Mesure**: Partenariats avec commerces locaux durables
- **KPI**: Maintien de l'engagement environnemental hors période de travail
"""
        else:
            day_strategy = f"""#### **Stratégie "Optimisation {peak_day}"**
- **Objectif**: Comprendre et réduire le pic du {peak_day.lower()}
- **Action**: Étude comportementale ciblée
- **Mesure**: Intervention personnalisée selon les causes identifiées
- **KPI**: Lissage de la courbe d'usage hebdomadaire
"""

        report += day_strategy

        # Politiques par type de déchet - Adaptation dynamique
        type_usage = self.processed_data.groupby('trash_type')['usage_intensity'].mean().sort_values(ascending=False)
        max_type = type_usage.index[0]
        max_value = type_usage.iloc[0]

        if len(type_usage) > 1:
            min_type = type_usage.index[-1]
            min_value = type_usage.iloc[-1]
        else:
            min_type = "aucun autre"
            min_value = 0

        report += f"""### **B. Politiques de Réduction par Type de Déchet**

#### **Focus Anti-{max_type.capitalize()}**
**Constat**: {max_type.capitalize()} = type le plus problématique (intensité: {max_value:.1f})

- **Politique**: {"Taxe sur emballages plastique" if max_type == "plastic" else f"Réduction incitative des déchets {max_type}"}
- **Alternative**: {"Emballages biodégradables" if max_type == "plastic" else f"Solutions réutilisables pour {max_type}"}
- **Éducation**: "Défi sans {max_type}" pendant les heures de pic

"""

        # Optimisation logistique basee sur les patterns
        if weekend_intensity < weekday_intensity:
            logistics_strategy = """### **C. Optimisation Logistique**

#### **Collecte Intelligente Adaptée**
- **Lundi-Mercredi**: Collecte standard
- **Jeudi-Vendredi**: Collecte renforcée (anticipation weekend)
- **Weekend**: Collecte réduite (usage plus faible détecté)
- **Économie attendue**: 25-30% de réduction des trajets inutiles
"""
        else:
            logistics_strategy = """### **C. Optimisation Logistique**

#### **Collecte Weekend Renforcée**
- **Semaine**: Collecte standard
- **Weekend**: Collecte renforcée (usage intensifié détecté)
- **Adaptation**: Équipes weekend spécialisées
- **Optimisation**: Couverture adaptée aux patterns d'usage weekend
"""

        report += logistics_strategy


        # Plan d'implementation adapte
        cluster_count = unique_clusters
        bin_count = stats['total_bins']

        if cluster_count <= 2:
            implementation_complexity = "Simple"
            timeline = "3-4 mois"
        elif cluster_count <= 4:
            implementation_complexity = "Modérée"
            timeline = "4-6 mois"
        else:
            implementation_complexity = "Complexe"
            timeline = "6-8 mois"


        report += f"""## **Plan d'Implémentation ({implementation_complexity})**

**Durée estimée**: {timeline}
**Complexité**: {implementation_complexity} ({cluster_count} profils comportementaux identifiés)

### **Phase 1 - Sensibilisation (Mois 1-2)**
- Campagnes ciblées aux heures de pic ({peak_hour}h) et jour de pic ({peak_day})
- Installation signalétique adaptée aux {cluster_count} profils identifiés
- Lancement application mobile avec recommandations personnalisées

### **Phase 2 - Infrastructure (Mois 3-4)**
- Optimisation placement des {bin_count} poubelles selon les clusters
- Installation d'alternatives éco-responsables (fontaines, stations de tri)
- Mise en place de la collecte intelligente adaptée aux patterns

### **Phase 3 - Gamification et Suivi (Mois 5-6)**
- Challenges collectifs anti-{max_type}
- Système de récompenses basé sur les améliorations mesurées
- Tableaux de bord communautaires temps réel

## **Indicateurs de Performance Adaptés**

| Objectif | Valeur Actuelle | Cible {timeline.split('-')[0]} mois | Impact Attendu |
|----------|-----------------|------------|----------------|
| Réduction pic {peak_day} | {peak_day_intensity:.1f} intensité | {peak_day_intensity*0.85:.1f} intensité | -15% |
| Réduction {max_type} | {max_value:.1f} usage | {max_value*0.7:.1f} usage | -30% |
| Optimisation collecte | 7j/7 | {"5j/7" if weekend_intensity < weekday_intensity else "Collecte adaptée"} | -25% trajets |
| Efficacité par cluster | {cluster_count} profils | Harmonisation | +40% ciblage |


## **Impact Environnemental Projeté**

### **Court terme (6 mois)**
- **Réduction déchets**: -20% grâce aux interventions ciblées
- **Optimisation logistique**: -25% émissions transport
- **Engagement citoyen**: +60% participation aux programmes

### **Moyen terme (1-2 ans)**
- **Changement comportemental durable**: -35% déchets totaux
- **Économie circulaire**: +50% taux de recyclage
- **Réplication modèle**: Extension à d'autres zones urbaines

---

**Rapport généré automatiquement le {datetime.now().strftime('%d/%m/%Y à %H:%M')}**
*Basé sur l'analyse de {stats['total_records']:,} enregistrements de {stats['total_bins']} poubelles intelligentes*
"""

        return report

    def visualize_patterns(self):
        """Visualisation des patterns identifiés"""
        if self.processed_data is None:
            self.feature_engineering()

        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('Analyse des Patterns d\'Usage - Poubelles Intelligentes', fontsize=16)

        # 1. Heatmap usage par heure et jour
        pivot_data = self.processed_data.groupby(['hour', 'day_of_week'])['usage_intensity'].mean().unstack()
        sns.heatmap(pivot_data, ax=axes[0,0], cmap='YlOrRd', cbar_kws={'label': 'Intensité d\'usage'})
        axes[0,0].set_title('Heatmap: Usage par Heure et Jour')
        axes[0,0].set_xlabel('Jour de la semaine')
        axes[0,0].set_ylabel('Heure')

        # 2. Patterns par type de déchet
        type_hourly = self.processed_data.groupby(['trash_type', 'hour'])['usage_intensity'].mean().unstack()
        type_hourly.T.plot(ax=axes[0,1], marker='o')
        axes[0,1].set_title('Patterns d\'Usage par Type de Déchet')
        axes[0,1].set_xlabel('Heure')
        axes[0,1].set_ylabel('Intensité d\'usage moyenne')
        axes[0,1].legend(title='Type de déchet')

        # 3. Distribution des niveaux par période
        self.processed_data.boxplot(column='trash_level', by='time_period', ax=axes[1,0])
        axes[1,0].set_title('Distribution des Niveaux par Période')
        axes[1,0].set_xlabel('Période de la journée')
        axes[1,0].set_ylabel('Niveau de remplissage (%)')

        # 4. Clusters si disponibles
        if self.clusters is not None:
            cluster_summary = self.clusters.groupby('cluster').size()
            axes[1,1].pie(cluster_summary.values, labels=[f'Cluster {i}' for i in cluster_summary.index], autopct='%1.1f%%')
            axes[1,1].set_title('Répartition des Poubelles par Cluster')
        else:
            axes[1,1].text(0.5, 0.5, 'Clustering non effectué', ha='center', va='center', transform=axes[1,1].transAxes)
            axes[1,1].set_title('Clusters')


        plt.tight_layout()
        plt.show()

        return fig

from others.database import MongoDB

def generate_patern_usage(raw_data):
    """Fonction principale pour générer les patterns d'usage"""
    
    # Création de l'analyseur de patterns
    analyzer = SmartTrashPatternAnalyzer(raw_data)

    # Analyse complète
    results = analyzer.analyze_usage_patterns()

    # Génération d'insights
    insights = analyzer.generate_insights()

    # Générer le rapport adapté aux données spécifiques
    detailed_report = analyzer.generate_dynamic_report()

    # Sauvegarder le rapport
    report_filename = f"rapport_patterns_usage_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    report_filename = os.path.join('generated_files', report_filename)
    with open(report_filename, 'w', encoding='utf-8') as f:
        f.write(detailed_report)

    print(f"✅ Rapport détaillé généré: {report_filename}")
    return report_filename

