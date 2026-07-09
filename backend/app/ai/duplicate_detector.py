"""
KumbhSathi AI — Duplicate Cases Detector
Online (SentenceTransformers embeddings) + Offline (Fuzzy/TF-IDF) Description Similarity Search
"""
import re
from typing import List, Dict, Any
from app.core.config import settings


class DuplicateDetector:
    """
    Offline-first AI module for duplicate case detection.
    Matches descriptions of missing persons using semantic embeddings or Jaccard similarity.
    """

    def __init__(self):
        self.similarity_threshold = settings.DUPLICATE_SIMILARITY_THRESHOLD
        self._initialized = False
        self.model = None

    def _lazy_init(self):
        """Lazy load sentence transformers to save startup time/memory."""
        if self._initialized:
            return
        try:
            from sentence_transformers import SentenceTransformer
            self.model = SentenceTransformer(settings.EMBEDDING_MODEL_NAME)
            print("🚀 SentenceTransformer model loaded successfully.")
        except ImportError:
            print("⚠️ sentence-transformers library not installed. Falling back to local Jaccard/TF-IDF overlap matching.")
        self._initialized = True

    def calculate_similarity(self, desc_a: str, desc_b: str) -> float:
        """Calculate similarity between two descriptions (0.0 to 1.0)."""
        if not desc_a or not desc_b:
            return 0.0
        
        self._lazy_init()
        
        # Method 1: SentenceTransformers if loaded
        if self.model:
            try:
                embeddings = self.model.encode([desc_a, desc_b], convert_to_numpy=True)
                import numpy as np
                norm_a = np.linalg.norm(embeddings[0])
                norm_b = np.linalg.norm(embeddings[1])
                if norm_a == 0 or norm_b == 0:
                    return 0.0
                cosine_sim = np.dot(embeddings[0], embeddings[1]) / (norm_a * norm_b)
                return float(cosine_sim)
            except Exception as e:
                print(f"⚠️ Error computing embedding similarity: {str(e)}")

        # Method 2: Offline Fallback (Jaccard similarity of words)
        words_a = set(re.findall(r'\w+', desc_a.lower()))
        words_b = set(re.findall(r'\w+', desc_b.lower()))
        
        # Remove common stop words
        stop_words = {"he", "she", "was", "wearing", "is", "a", "in", "and", "the", "with", "on", "at", "his", "her", "of", "to"}
        words_a = words_a - stop_words
        words_b = words_b - stop_words
        
        if not words_a or not words_b:
            return 0.0
            
        intersection = words_a & words_b
        union = words_a | words_b
        return len(intersection) / len(union)

    def find_potential_duplicates(self, new_case: Dict[str, Any], existing_cases: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Compare a new case description with all existing cases to find potential duplicate reports.
        """
        new_desc = f"{new_case.get('physical_description', '')} {new_case.get('clothing_description', '')}".strip()
        if not new_desc:
            return []

        duplicates = []
        for case in existing_cases:
            # Skip comparing case to itself
            if case.get("id") == new_case.get("id") or case.get("case_id") == new_case.get("case_id"):
                continue
                
            case_desc = f"{case.get('physical_description', '')} {case.get('clothing_description', '')}".strip()
            if not case_desc:
                continue
                
            score = self.calculate_similarity(new_desc, case_desc)
            if score >= self.similarity_threshold:
                duplicates.append({
                    "case_id": case.get("case_id"),
                    "name": case.get("missing_person_name"),
                    "similarity_score": round(score, 2),
                    "status": case.get("status"),
                    "last_seen": case.get("last_seen_location")
                })
                
        # Sort by similarity score descending
        duplicates.sort(key=lambda x: x["similarity_score"], reverse=True)
        return duplicates
