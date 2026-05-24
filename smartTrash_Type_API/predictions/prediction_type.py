import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import time

class TypePredictionmodel:
    def __init__(self, file_path, use_fp16=True, compile_model=True):
        """
        Initialize the prediction model with optimization options.
        
        Args:
            file_path: Path to the model weights
            use_fp16: Use float16 precision (faster on modern GPUs)
            compile_model: Use torch.compile for faster inference (PyTorch 2.0+ with CUDA >= 7.0)
        """
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.use_fp16 = use_fp16 and torch.cuda.is_available()
        
        # Create and load model
        self.model = self.get_densenet201(num_classes=10)
        self.model.to(self.device)
        self.model.load_state_dict(torch.load(file_path, map_location=self.device))
        self.model.eval()
        
        # Convert to half precision for faster inference if GPU available
        if self.use_fp16:
            self.model.half()
        
        # Compile model only if GPU supports it (CUDA Capability >= 7.0)
        if compile_model and torch.cuda.is_available():
            cuda_capability = torch.cuda.get_device_capability(0)
            cuda_version = cuda_capability[0] + cuda_capability[1] / 10
            
            if cuda_version >= 7.0:
                try:
                    self.model = torch.compile(self.model, mode="reduce-overhead")
                    print("[Prediction] Model compiled with torch.compile")
                except Exception as e:
                    print(f"[Prediction] torch.compile failed: {e}")
            else:
                print(f"[Prediction] CUDA Capability {cuda_version} < 7.0, skipping torch.compile")
        
        # Image transformation
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.5]*3, [0.5]*3)
        ])
        self.class_names = ['battery','organic','cardboard','clothes','glass','metal','paper','plastic','shoes','trash']
        
        # Log device info
        device_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
        print(f"[Prediction] Device: {device_name}")
        if torch.cuda.is_available():
            total_mem = torch.cuda.get_device_properties(0).total_memory / 1e9
            print(f"[Prediction] GPU Memory: {total_mem:.2f} GB")
            print(f"[Prediction] Mixed Precision (FP16): {self.use_fp16}")
        
        # Warm up model with dummy input for GPU memory allocation
        self._warmup()

    def _warmup(self):
        """Warm up the model to allocate GPU memory and optimize performance."""
        try:
            dummy_input = torch.randn(1, 3, 224, 224, device=self.device)
            if self.use_fp16:
                dummy_input = dummy_input.half()
            
            with torch.inference_mode():
                self.model(dummy_input)
            print("[Prediction] Model warm-up completed")
        except Exception as e:
            print(f"[Prediction] Warm-up encountered issue (non-critical): {e}")

    def get_densenet201(self, num_classes):
        # Use weights=None instead of deprecated pretrained parameter
        model = models.densenet201(weights=None)
        in_features = model.classifier.in_features
        model.classifier = nn.Linear(in_features, num_classes)
        return model
    
    def prepare_image(self, image_path):
        """Prepare image for inference."""
        image = Image.open(image_path).convert("RGB")
        image = self.transform(image).unsqueeze(0)  # Add batch dimension
        image = image.to(self.device)
        
        # Convert to half precision if using FP16
        if self.use_fp16:
            image = image.half()
        
        return image
    
    def predict(self, image_path):
        """
        Predict trash type from image.
        
        Returns:
            Dictionary with predicted_class, confidence, and inference_time_ms
        """
        start_time = time.time()
        
        image = self.prepare_image(image_path)
        
        # Use torch.inference_mode for faster inference (replaces no_grad)
        with torch.inference_mode():
            outputs = self.model(image)
            probabilities = torch.softmax(outputs, dim=1)
            confidence, predicted_indice = torch.max(probabilities, 1)
            predicted_indice = predicted_indice.item()
            confidence = confidence.item()
        
        predicted_class = self.class_names[predicted_indice]
        inference_time = (time.time() - start_time) * 1000  # Convert to milliseconds
        
        return {
            "predicted_class": predicted_class,
            "confidence": round(confidence, 4),
            "inference_time_ms": round(inference_time, 2)
        }
