"""
KumbhSathi AI — Priority Predictor
Online/Offline Priority Classification Model Trained on CSV Case Metadata
"""
import joblib
import os
from typing import Dict, Any
from app.core.config import settings


class PriorityPredictor:
    """
    Predicts missing person priority level (Critical, High, Medium, Low).
    Falls back to CSV-aligned rule-based heuristics if the model file is not found (offline).
    """

    def __init__(self):
        self.model_path = settings.PRIORITY_MODEL_PATH
        self.model = None
        self._load_model()

    def _load_model(self):
        """Load trained scikit-learn model if it exists."""
        if os.path.exists(self.model_path):
            try:
                self.model = joblib.load(self.model_path)
                print(f"🚀 Priority prediction model loaded from {self.model_path}")
            except Exception as e:
                print(f"⚠️ Failed to load priority prediction model: {str(e)}")

    def predict_priority(self, case_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Predict case priority based on features: age_band, gender, health/medical issues, time delay.
        """
        age_band = case_data.get("age_band")
        physical_desc = case_data.get("physical_description", "").lower()
        
        # Rule-based calculation (used as baseline or offline fallback)
        priority = "Medium"
        score = 0.5
        
        # 1. Age factor (Children & Elderly have highest priority per CSV statistics)
        if age_band in ("0-12", "80+"):
            priority = "Critical"
            score = 0.95
        elif age_band in ("13-17", "71-80"):
            priority = "High"
            score = 0.80
        elif age_band in ("61-70",):
            priority = "Medium"
            score = 0.60
        else:
            priority = "Low"
            score = 0.35

        # 2. Medical conditions check (e.g. dementia, diabetic, heart, asthma)
        medical_keywords = ["diabetic", "sugar", "dementia", "alzheimer", "heart", "bp", "asthma", "ill", "sick", "injured", "दवा", "बीमार", "मधुमेह"]
        if any(keyword in physical_desc for keyword in medical_keywords):
            # Escalate priority
            if priority == "Low":
                priority = "Medium"
                score = 0.55
            elif priority == "Medium":
                priority = "High"
                score = 0.85
            elif priority == "High":
                priority = "Critical"
                score = 0.98

        # 3. Model inference (if offline scikit-learn model is available)
        if self.model:
            try:
                # Features list matching model: [age_code, gender_code, has_medical, has_phone]
                gender = case_data.get("gender", "Unknown")
                gender_code = 1 if gender == "Male" else (2 if gender == "Female" else 0)
                
                age_map = {"0-12": 1, "13-17": 2, "18-40": 3, "41-60": 4, "61-70": 5, "71-80": 6, "80+": 7}
                age_code = age_map.get(age_band, 0)
                
                has_medical = 1 if any(kw in physical_desc for kw in medical_keywords) else 0
                has_phone = 1 if case_data.get("reporter_mobile") else 0
                
                features = [[age_code, gender_code, has_medical, has_phone]]
                pred_label = self.model.predict(features)[0]
                pred_proba = self.model.predict_proba(features)[0]
                
                labels_map = {0: "Low", 1: "Medium", 2: "High", 3: "Critical"}
                priority = labels_map.get(pred_label, priority)
                score = float(max(pred_proba))
            except Exception as e:
                print(f"⚠️ Model inference failed, fallback to rules: {str(e)}")

        return {
            "priority": priority,
            "confidence": round(score, 2),
            "is_critical": priority == "Critical"
        }
