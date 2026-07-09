"""
KumbhSathi AI — Face Recognizer Service
Offline-first wrapper around dlib face_recognition library
"""
import os
from typing import Dict, Any, List, Optional
from app.core.config import settings

class FaceRecognizer:
    """
    Handles face detection and encoding generation.
    Supports offline execution on CPU (HOG) or GPU (CNN).
    """
    
    def __init__(self):
        self.model = settings.FACE_RECOGNITION_MODEL
        self.threshold = settings.FACE_RECOGNITION_THRESHOLD
        
    def detect_and_encode(self, image_path: str) -> Optional[List[float]]:
        """
        Detect face and return its 128-d encoding vector.
        Returns None if no face is detected.
        """
        try:
            import face_recognition
            if not os.path.exists(image_path):
                return None
                
            image = face_recognition.load_image_file(image_path)
            face_locations = face_recognition.face_locations(image, model=self.model)
            if not face_locations:
                return None
                
            encodings = face_recognition.face_encodings(image, face_locations)
            if not encodings:
                return None
                
            # Return first face embedding as list of floats
            return encodings[0].tolist()
        except ImportError:
            print("⚠️ face_recognition library not available. Face detection skipped.")
            return None
        except Exception as e:
            print(f"⚠️ Face encoding failed: {str(e)}")
            return None
            
    def verify_match(self, encoding_a: List[float], encoding_b: List[float]) -> float:
        """
        Compare two 128-d encodings and return similarity score (0.0 to 1.0).
        """
        if len(encoding_a) != 128 or len(encoding_b) != 128:
            return 0.0
            
        try:
            import numpy as np
            vec_a = np.array(encoding_a)
            vec_b = np.array(encoding_b)
            
            # cosine distance = 1 - cosine similarity
            norm_a = np.linalg.norm(vec_a)
            norm_b = np.linalg.norm(vec_b)
            if norm_a == 0 or norm_b == 0:
                return 0.0
                
            cosine_sim = np.dot(vec_a, vec_b) / (norm_a * norm_b)
            # Map cosine similarity (-1 to 1) to (0 to 1)
            similarity = (cosine_sim + 1) / 2
            return float(similarity)
        except Exception as e:
            print(f"⚠️ Error verifying face match: {str(e)}")
            return 0.0
