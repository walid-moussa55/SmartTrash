import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image

class TypePredictionmodel:
    def __init__(self, file_path):
        self.model = self.get_densenet201(num_classes=10)
        self.model.load_state_dict(torch.load(file_path, map_location=torch.device('cpu')))
        self.model.eval()
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.5]*3, [0.5]*3)
        ])
        self.class_names = ['battery','organic','cardboard','clothes','glass','metal','paper','plastic','shoes','trash']

    def get_densenet201(self, num_classes):
        model = models.densenet201(pretrained=False)
        in_features = model.classifier.in_features
        model.classifier = nn.Linear(in_features, num_classes)
        return model
    
    def prepare_image(self, image_path):
        image = Image.open(image_path).convert("RGB")
        image = self.transform(image).unsqueeze(0)  # Add batch dimension
        return image
    
    def predict(self, image_path):
        image = self.prepare_image(image_path)
        with torch.no_grad():
            outputs = self.model(image)
            predicted_indice = outputs.argmax(1).item()
        predicted_class = self.class_names[predicted_indice]
        return predicted_class
