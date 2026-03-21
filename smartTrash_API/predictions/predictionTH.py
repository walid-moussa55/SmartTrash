import torch
import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler
from torch import nn
import joblib
from others.database import MongoDB
from collections import deque

class WeatherLSTMPredictor(nn.Module):
    def __init__(self, sequence_length=24):
        super(WeatherLSTMPredictor, self).__init__()
        self.sequence_length = sequence_length
        self.scaler_temp = MinMaxScaler()
        self.scaler_rhum = MinMaxScaler()
        
        # Model architecture
        self.lstm1 = nn.LSTM(input_size=8, hidden_size=128, batch_first=True)
        self.dropout1 = nn.Dropout(0.2)
        self.lstm2 = nn.LSTM(input_size=128, hidden_size=64, batch_first=True)
        self.dropout2 = nn.Dropout(0.2)
        self.lstm3 = nn.LSTM(input_size=64, hidden_size=32, batch_first=True)
        self.dropout3 = nn.Dropout(0.2)
        self.dense1 = nn.Linear(32, 16)
        self.dropout4 = nn.Dropout(0.1)
        self.dense2 = nn.Linear(16, 2)

    def forward(self, x):
        x, _ = self.lstm1(x)
        x = self.dropout1(x)
        x, _ = self.lstm2(x)
        x = self.dropout2(x)
        x, _ = self.lstm3(x)
        x = self.dropout3(x)
        x = x[:, -1, :]  # Use last timestep only
        x = torch.relu(self.dense1(x))
        x = self.dropout4(x)
        x = self.dense2(x)
        return x

    def add_time_features(self, df):
        df = df.copy()
        df['hour'] = df['time'].dt.hour
        df['day_of_week'] = df['time'].dt.dayofweek
        df['month'] = df['time'].dt.month
        
        # Cyclical time features
        df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
        df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
        df['day_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
        df['day_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
        df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
        df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)
        return df

    def prepare_features(self, df):
        df = self.add_time_features(df)
        feature_columns = ['temp', 'rhum', 'hour_sin', 'hour_cos', 
                          'day_sin', 'day_cos', 'month_sin', 'month_cos']
        data = df[feature_columns].values
        
        # Normalize (scalers should be pre-fit during training)
        temp_norm = self.scaler_temp.transform(data[:, 0].reshape(-1, 1))
        rhum_norm = self.scaler_rhum.transform(data[:, 1].reshape(-1, 1))
        
        data_normalized = np.column_stack([
            temp_norm.flatten(),
            rhum_norm.flatten(),
            data[:, 2:]
        ])
        return data_normalized

    def predict(self, X):
        self.eval()
        with torch.no_grad():
            X_tensor = torch.FloatTensor(X).to(DEVICE)
            predictions = self(X_tensor).cpu().numpy()
        
        # Denormalize
        temp_pred = self.scaler_temp.inverse_transform(predictions[:, 0].reshape(-1, 1)).flatten()
        rhum_pred = self.scaler_rhum.inverse_transform(predictions[:, 1].reshape(-1, 1)).flatten()
        return np.column_stack([temp_pred, rhum_pred])
    
    def predict_next_days(self, df, n_days=7):
        """Prédire les prochains jours"""
        # Préparer les données
        data_normalized = self.prepare_features(df)
        
        # Prendre les dernières séquences
        last_sequence = data_normalized[-self.sequence_length:]
        
        predictions = []
        current_sequence = last_sequence.copy()
        
        # Prédire heure par heure pour n_days
        for i in range(n_days * 24):  # 24 heures par jour
            # Prédire la prochaine valeur
            with torch.no_grad():
                input_tensor = torch.FloatTensor(current_sequence).unsqueeze(0).to(DEVICE)
                pred = self(input_tensor).cpu().numpy()[0]
            
            # Dénormaliser la prédiction
            temp_pred = self.scaler_temp.inverse_transform(pred[0].reshape(-1, 1))[0, 0]
            rhum_pred = self.scaler_rhum.inverse_transform(pred[1].reshape(-1, 1))[0, 0]
            
            predictions.append([temp_pred, rhum_pred])
            
            # Mettre à jour la séquence pour la prochaine prédiction
            # On garde les prédictions normalisées pour la cohérence
            next_hour = (df['time'].iloc[-1] + pd.Timedelta(hours=i+1))
            
            # Calculer les nouvelles features temporelles
            hour_sin = np.sin(2 * np.pi * next_hour.hour / 24)
            hour_cos = np.cos(2 * np.pi * next_hour.hour / 24)
            day_sin = np.sin(2 * np.pi * next_hour.dayofweek / 7)
            day_cos = np.cos(2 * np.pi * next_hour.dayofweek / 7)
            month_sin = np.sin(2 * np.pi * next_hour.month / 12)
            month_cos = np.cos(2 * np.pi * next_hour.month / 12)
            
            # Créer la nouvelle ligne avec prédictions normalisées
            new_row = np.array([pred[0], pred[1], 
                               hour_sin, hour_cos, day_sin, day_cos, 
                               month_sin, month_cos])
            
            # Mettre à jour la séquence (glisser d'une position)
            current_sequence = np.vstack([current_sequence[1:], new_row])
        
        return np.array(predictions)

import torch
import pandas as pd
import numpy as np
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

class HTPredictor:
    def __init__(self):
        self.model = None
        self.sequence_length = 7  # 7 records (days or hours, as you wish)
        self.init_model()
        self.db = MongoDB()
        self.bin_sequences = {}  # {bin_id: deque([dict, ...], maxlen=7)}
        self._load_initial_sequences()

    def init_model(self):
        """Initialize the model and load saved weights."""
        self.model = WeatherLSTMPredictor(sequence_length=self.sequence_length)
        self.model.load_state_dict(torch.load('./weights_pth/best_model.pth', map_location=DEVICE))
        self.model.scaler_rhum = joblib.load('./weights_pth/scaler_rhum.pkl')
        self.model.scaler_temp = joblib.load('./weights_pth/scaler_temp.pkl')
        self.model.to(DEVICE)
        self.model.eval()

    def _load_initial_sequences(self):
        """Load last 7 records for each bin from the database into deques."""
        data = self.db.get_last_7_temp_humidity_per_bin()
        print("Loading initial sequences for bins...")
        if not data:
            print("No data found for bins.")
        for bin_id, df in data.items():
            if not df.empty:
                records = df.to_dict('records')
                self.bin_sequences[bin_id] = deque(records, maxlen=self.sequence_length)
            else:
                self.bin_sequences[bin_id] = deque(maxlen=self.sequence_length)

    def add_current_state(self, current_state_dict):
        """
        Add the current state for each bin to its deque.
        current_state_dict: {bin_id: {"time": ..., "temp": ..., "rhum": ...}, ...}
        """
        for bin_id, state in current_state_dict.items():
            if bin_id not in self.bin_sequences:
                self.bin_sequences[bin_id] = deque(maxlen=self.sequence_length)
            self.bin_sequences[bin_id].append(state)

    def predict_next_7_days_all_bins(self):
        """
        Predict the next 7 days for each bin using the current deque (last 7 + current).
        Returns: {bin_id: prediction}
        """
        predictions = {}
        for bin_id, seq in self.bin_sequences.items():
            if len(seq) < self.sequence_length:
                continue  # Not enough data
            df = pd.DataFrame(seq)
            df['time'] = pd.to_datetime(df['time'])
            df = df.sort_values(by='time')
            # Save df for use in predict_next_7_for_bin
            pred = self.predict_next_7_for_bin(df)
            predictions[bin_id] = pred
        return predictions

    def predict_next_7_for_bin(self, df):
        """Predict the next 7 days of temperature and humidity for a specific bin."""
        future_predictions = self.model.predict_next_days(df, n_days=7)
        HT_predictions = {"avg_temp": [], "avg_rhum": [], "min_temp": [], "max_temp": []}
        avg_temps = []
        avg_rhums = []
        min_temps = []
        max_temps = []
        for day in range(7):
            day_data = future_predictions[day*24:(day+1)*24]
            avg_temps.append(np.mean(day_data[:, 0]))
            avg_rhums.append(np.mean(day_data[:, 1]))
            min_temps.append(np.min(day_data[:, 0]))
            max_temps.append(np.max(day_data[:, 0]))
        HT_predictions["avg_temp"] = avg_temps
        HT_predictions["avg_rhum"] = avg_rhums
        HT_predictions["min_temp"] = min_temps
        HT_predictions["max_temp"] = max_temps
        return HT_predictions

    def predict(self, current_state_dict):
        """
        Main method to run the prediction.
        current_state_dict: {bin_id: {"time": ..., "temp": ..., "rhum": ...}, ...}
        """
        self.add_current_state(current_state_dict)
        return self.predict_next_7_days_all_bins()

