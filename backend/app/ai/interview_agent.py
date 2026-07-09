"""
KumbhSathi AI — AI Interview Agent
Online (Groq LLM) + Offline (Rule-based Regex/Keyword) Structured Extraction
"""
import httpx
import re
from typing import Dict, Any, Optional
from app.core.config import settings


class InterviewAgent:
    """
    AI Interview Agent that processes natural language input (voice transcription/chat)
    to extract structured missing person features.
    
    Operates in two modes:
      - Online: Calls Groq API with Llama-3-70b-8192 for high-fidelity extraction.
      - Offline: Uses local regex and keyword dictionaries as fallback.
    """

    def __init__(self):
        self.groq_api_key = settings.GROQ_API_KEY
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"  # Standard Groq API URL
        # Common names / features from CSV to help offline matching
        self.gender_keywords = {
            "male": ["male", "man", "boy", "he", "his", "him", "पुरुष", "लड़का", "आदमी"],
            "female": ["female", "woman", "girl", "she", "her", "महिला", "लड़की", "स्त्री"]
        }
        
    async def extract_features(self, text: str) -> Dict[str, Any]:
        """Extract structured features from raw text using Groq LLM with offline fallback."""
        if not text or not text.strip():
            return self._empty_response()

        # Try Online Groq mode first
        if self.groq_api_key and self.groq_api_key.startswith("gsk_"):
            try:
                return await self._extract_groq(text)
            except Exception as e:
                print(f"⚠️ Groq API extraction failed: {str(e)}. Falling back to offline mode.")
                
        # Offline fallback
        return self._extract_offline(text)

    async def _extract_groq(self, text: str) -> Dict[str, Any]:
        """Call Groq API to extract structured fields as JSON."""
        system_prompt = """
        You are a structured information extraction AI for "KumbhSathi AI", a missing persons incident platform.
        Extract the following fields from the user's description. Return JSON format only.
        If a field is missing, return null. Do not invent any facts.
        
        Fields:
        1. name: Full name of the missing person (if mentioned).
        2. gender: "Male" or "Female".
        3. age_band: Exactly one of: "0-12", "13-17", "18-40", "41-60", "61-70", "71-80", "80+". (Map age numbers into these bands, e.g. 72 -> "71-80").
        4. physical_description: Height, build, skin tone, hair, scars, tattoos, etc.
        5. clothing_description: Color and type of clothes, e.g. "yellow kurta and white dhoti".
        6. last_seen_location: Specific location mentioned, e.g. "Sector 4 Ghat", "Ramkund".
        
        Example Output:
        {
          "name": "Ramesh Kumar",
          "gender": "Male",
          "age_band": "71-80",
          "physical_description": "Thin build, gray hair, 5ft 8in, scar on left cheek",
          "clothing_description": "yellow kurta and white dhoti",
          "last_seen_location": "Sector 4 Ghat"
        }
        """

        headers = {
            "Authorization": f"Bearer {self.groq_api_key}",
            "Content-Type": "application/json"
        }
        
        # Using Llama 3 70B on Groq for high accuracy extraction
        data = {
            "model": "llama3-70b-8192",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text}
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"}
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(self.api_url, headers=headers, json=data)
            if response.status_code == 200:
                import json
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                return json.loads(content)
            else:
                raise Exception(f"HTTP {response.status_code}: {response.text}")

    def _extract_offline(self, text: str) -> Dict[str, Any]:
        """Offline fallback using regex and keyword rules."""
        text_lower = text.lower()
        extracted = self._empty_response()

        # 1. Gender check
        for g_val, keywords in self.gender_keywords.items():
            if any(k in text_lower for k in keywords):
                extracted["gender"] = g_val.capitalize()
                break

        # 2. Age parsing
        age_match = re.search(r'\b(\d{1,2})\b\s*(?:years|yr|age|साल|उम्र)', text_lower)
        if not age_match:
            age_match = re.search(r'(?:उम्र|साल)\s*(\d{1,2})', text_lower)
            
        if age_match:
            age = int(age_match.group(1))
            if age <= 12: extracted["age_band"] = "0-12"
            elif age <= 17: extracted["age_band"] = "13-17"
            elif age <= 40: extracted["age_band"] = "18-40"
            elif age <= 60: extracted["age_band"] = "41-60"
            elif age <= 70: extracted["age_band"] = "61-70"
            elif age <= 80: extracted["age_band"] = "71-80"
            else: extracted["age_band"] = "80+"

        # 3. Simple name heuristics (e.g. "name is Savita Desai", "my father Ramesh Kumar")
        name_patterns = [
            r'name\s+(?:is|was)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
            r'(?:father|mother|brother|sister|son|daughter)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
            r'नाम\s+([अ-ह\u200d]+(?:\s+[अ-ह\u200d]+)?)'
        ]
        for pattern in name_patterns:
            name_match = re.search(pattern, text)
            if name_match:
                extracted["name"] = name_match.group(1).strip()
                break

        # 4. Location extraction (e.g. "at Sector 4", "near Ramkund")
        loc_patterns = [
            r'(?:at|near|in|from|spotted at|last seen at)\s+([A-Z][a-zA-Z0-9\s]+(?:Ghat|Transit|Station|Parking|Bridge|Sector\s+\d+|Panchavati|Ramkund))',
            r'([A-Z][a-zA-Z0-9\s]+(?:Ghat|Transit|Station|Parking|Sector\s+\d+))\s+के पास'
        ]
        for pattern in loc_patterns:
            loc_match = re.search(pattern, text)
            if loc_match:
                extracted["last_seen_location"] = loc_match.group(1).strip()
                break

        # 5. Fallback descriptions
        extracted["physical_description"] = text  # Default fallback
        extracted["clothing_description"] = "Not specified"

        # Look for clothing keywords
        clothes_keywords = ["wearing", "kurta", "dhoti", "sari", "jeans", "shirt", "pant", "t-shirt", "पहन", "कुर्ता", "धोती", "साड़ी", "शर्ट"]
        if any(cw in text_lower for cw in clothes_keywords):
            # Extract sentence containing clothing
            sentences = text.split('.')
            for s in sentences:
                if any(cw in s.lower() for cw in clothes_keywords):
                    extracted["clothing_description"] = s.strip()
                    break

        return extracted

    def _empty_response(self) -> Dict[str, Any]:
        return {
            "name": None,
            "gender": None,
            "age_band": None,
            "physical_description": None,
            "clothing_description": None,
            "last_seen_location": None
        }
