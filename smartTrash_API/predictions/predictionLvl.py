import torch
import torch.nn as nn
import joblib
import numpy as np
import pandas as pd

# Re-define the model class (must match exactly)
class LSTMModel(nn.Module):
    def __init__(self, input_size=1, hidden_layer_size=100, output_size=1):
        super().__init__()
        self.hidden_layer_size = hidden_layer_size
        self.lstm = nn.LSTM(input_size, hidden_layer_size)
        self.linear = nn.Linear(hidden_layer_size, output_size)
        self.hidden_cell = (torch.zeros(1, 1, self.hidden_layer_size),
                            torch.zeros(1, 1, self.hidden_layer_size))

    def forward(self, input_seq):
        input_seq = input_seq.permute(1, 0, 2)
        lstm_out, self.hidden_cell = self.lstm(input_seq, self.hidden_cell)
        predictions = self.linear(lstm_out.view(len(input_seq), -1))
        return predictions[-1]

# Load the model
model = LSTMModel()
model.load_state_dict(torch.load('weights_pth/model.pth'))
model.eval()  # Set to evaluation mode
scaler = joblib.load('weights_pth/scaler.pkl')

n_input = 14  # Same as before
from collections import deque

last_heights = deque([32., 29., 27., 25., 23., 24., 24., 23., 20., 20., 20., 20., 18., 15.], maxlen=n_input)

def predict_next_height(latest_heights, model, scaler, n_input=14):
    """
    latest_heights: list or array of the last 14 height values (not scaled)
    model: your loaded PyTorch model
    scaler: your loaded scaler
    """
    if len(latest_heights) != n_input:
        raise ValueError(f"Expected {n_input} input values, got {len(latest_heights)}")

    # Scale and reshape the input with proper feature names
    df = pd.DataFrame(np.array(latest_heights).reshape(-1, 1), columns=['height'])
    scaled_input = scaler.transform(df)
    input_tensor = torch.FloatTensor(scaled_input).view(1, -1, 1)

    # Predict
    model.eval()
    with torch.no_grad():
        model.hidden_cell = (torch.zeros(1, 1, model.hidden_layer_size),
                             torch.zeros(1, 1, model.hidden_layer_size))
        prediction = model(input_tensor)

    predicted_height = prediction.numpy().reshape(-1, 1)[0][0] * 100.0
    return predicted_height

def next_level(next_real_level = None):
    if next_real_level is not None:
        next_real_height = scaler.inverse_transform(np.array(next_real_level/100.0).reshape(-1, 1))[0][0]
        last_heights.append(next_real_height)
    prediction = predict_next_height(list(last_heights), model, scaler)
    return prediction

