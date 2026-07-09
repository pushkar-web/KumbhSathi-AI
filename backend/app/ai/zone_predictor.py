"""
KumbhSathi AI — Search Zone Predictor
Predicts search zones using spatial distance and zone coordinates from CSV boundaries
"""
import math
from typing import Dict, Any, List


class ZonePredictor:
    """
    Predicts the search zone probability based on the missing person last seen location
    and zone centroids/CCTV density. Works fully offline.
    """

    def __init__(self):
        # We will populate zones dynamically from database, but keep Nashik defaults from CSV
        self.default_zones = [
            {"name": "Sector 1 (Ramkund)", "lat": 19.9978, "lng": 73.7898},
            {"name": "Sector 2 (Panchavati)", "lat": 19.9992, "lng": 73.7924},
            {"name": "Sector 3 (Triveni)", "lat": 19.9921, "lng": 73.7845},
            {"name": "Sector 4 (Madsangvi)", "lat": 20.0041, "lng": 73.8150},
            {"name": "Sector 5 (Tapovan)", "lat": 19.9880, "lng": 73.8050}
        ]

    def _haversine_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate distance in kilometers between two points."""
        R = 6371.0 # Earth radius
        
        d_lat = math.radians(lat2 - lat1)
        d_lng = math.radians(lng2 - lng1)
        
        a = math.sin(d_lat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c

    def predict_zones(self, lat: float, lng: float, zones_db: List[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """
        Calculate probability distribution for each zone based on distance to last seen coordinate.
        """
        zones = zones_db or self.default_zones
        if not zones:
            return []

        scored_zones = []
        total_inverse_dist = 0.0

        for zone in zones:
            z_lat = zone.get("centroid_lat") or zone.get("lat")
            z_lng = zone.get("centroid_lng") or zone.get("lng")
            z_name = zone.get("zone_name") or zone.get("name")
            z_id = zone.get("id")

            if z_lat is None or z_lng is None:
                continue

            dist = self._haversine_distance(lat, lng, z_lat, z_lng)
            
            # Use inverse distance weighting (avoid division by zero)
            weight = 1.0 / (dist + 0.1)
            total_inverse_dist += weight
            
            scored_zones.append({
                "id": str(z_id) if z_id else None,
                "zone_name": z_name,
                "distance_km": round(dist, 2),
                "weight": weight
            })

        # Calculate probabilities
        predictions = []
        if total_inverse_dist > 0:
            for sz in scored_zones:
                prob = sz["weight"] / total_inverse_dist
                predictions.append({
                    "id": sz["id"],
                    "zone_name": sz["zone_name"],
                    "distance_km": sz["distance_km"],
                    "probability": round(prob, 2)
                })

        # Sort by probability descending
        predictions.sort(key=lambda x: x["probability"], reverse=True)
        return predictions
