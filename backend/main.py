from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect
from typing import Optional, List as TypingList
import uuid
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
import httpx
import json
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
import jwt
import hashlib
from pathlib import Path
 
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

app = FastAPI(title="TripGenie Backend")

# Connection to Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
 
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
WEATHER_KEY = os.getenv("WEATHER_API_KEY", "")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")

# ============ USER AUTHENTICATION SYSTEM ============

# In-memory user database (replace with real DB in Phase 9)
users_db = {
    "demo@example.com": {
        "id": "user_1",
        "name": "Demo User",
        "email": "demo@example.com",
        "password_hash": hashlib.sha256("password123".encode()).hexdigest(),
    }
}

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    token: str

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def create_token(email: str) -> str:
    payload = {
        "email": email,
        "exp": datetime.utcnow() + timedelta(days=30)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

@app.post("/auth/register", response_model=UserResponse)
def register(req: RegisterRequest):
    if req.email in users_db:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_id = f"user_{len(users_db) + 1}"
    password_hash = hash_password(req.password)
    
    users_db[req.email] = {
        "id": user_id,
        "name": req.name,
        "email": req.email,
        "password_hash": password_hash,
    }
    
    token = create_token(req.email)
    return UserResponse(
        id=user_id,
        name=req.name,
        email=req.email,
        token=token,
    )

@app.post("/auth/login", response_model=UserResponse)
def login(req: LoginRequest):
    if req.email not in users_db:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    user = users_db[req.email]
    password_hash = hash_password(req.password)
    
    if user["password_hash"] != password_hash:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    token = create_token(req.email)
    return UserResponse(
        id=user["id"],
        name=user["name"],
        email=user["email"],
        token=token,
    )

# ============ ITINERARY GENERATOR (Groq AI) ============

class ItineraryRequest(BaseModel):
    destination: str
    days: int
    budget: float
    interests: list[str]
 
@app.post("/generate-itinerary")
async def generate_itinerary(req: ItineraryRequest):
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY is not configured")

    interests_str = ", ".join(req.interests)
 
    prompt = f"""
You are an expert travel planner.
Generate a detailed {req.days}-day itinerary for {req.destination}.
Total budget: ${req.budget:.0f} USD.
Interests: {interests_str}.
 
Respond ONLY with valid JSON (no markdown, no explanation):
{{
  "destination": "{req.destination}",
  "days": {req.days},
  "budget": {req.budget},
  "summary": "One sentence describing the trip vibe",
  "day_plans": [
    {{
      "day": 1,
      "date": "Day 1",
      "activities": [
        {{
          "time": "9:00 AM",
          "title": "Place or activity name",
          "description": "2 sentence practical description",
          "type": "culture"
        }}
      ]
    }}
  ]
}}
 
Rules:
- 4-5 activities per day (morning, lunch, afternoon, evening, night)
- type must be one of: food, culture, nature, shopping, adventure
- JSON only, nothing else
"""
 
    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": GROQ_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 3000,
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Groq API error {response.status_code}: {response.text}",
        )
 
    raw = response.json()["choices"][0]["message"]["content"]
    raw = raw.strip().lstrip("```json").rstrip("```").strip()
    return json.loads(raw)
 
# ============ WEATHER API ============

@app.get("/weather/{city}")
async def get_weather(city: str):
    async with httpx.AsyncClient(timeout=10) as client:
        res = await client.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "units": "metric", "appid": WEATHER_KEY},
        )
    if res.status_code == 200:
        return res.json()
    return {"error": "City not found", "status": res.status_code}
 
# ============ TRIP POSTS (Social Matching) ============

trips_db = []   # In-memory list (replace with real database in Phase 9)
 
class TripPost(BaseModel):
    destination: str
    start_date: str
    end_date: str
    group_size: int
    interests: list[str]
    description: str
    user_name: str
 
@app.get("/trips")
def get_trips(destination: str = ""):
    if destination:
        return [t for t in trips_db
                if destination.lower() in t["destination"].lower()]
    return trips_db
 
@app.post("/trips")
def post_trip(trip: TripPost):
    new = trip.dict()
    new["id"] = str(len(trips_db) + 1)
    new["current_members"] = 1
    new["posted_ago"] = "Just now"
    trips_db.append(new)
    return new

# ============ PLACES & DISCOVERY (Phase 8) ============

OPENTRIPMAP_KEY = os.getenv("OPENTRIPMAP_KEY", "")

# Sample places data for discovery hub + map
SAMPLE_PLACES = [
    {"id": "p1", "name": "Faisal Mosque", "category": "Culture", "lat": 33.7295, "lng": 73.0372, "rating": 4.8, "crowdLevel": 0.7, "color": 0xFF6366F1},
    {"id": "p2", "name": "Daman-e-Koh", "category": "Parks", "lat": 33.7384, "lng": 73.0586, "rating": 4.5, "crowdLevel": 0.4, "color": 0xFF10B981},
    {"id": "p3", "name": "Monal Restaurant", "category": "Food", "lat": 33.7440, "lng": 73.0640, "rating": 4.3, "crowdLevel": 0.8, "color": 0xFFF59E0B},
    {"id": "p4", "name": "Centaurus Mall", "category": "Shopping", "lat": 33.7085, "lng": 73.0508, "rating": 4.1, "crowdLevel": 0.9, "color": 0xFFEC4899},
    {"id": "p5", "name": "Pakistan Monument", "category": "Culture", "lat": 33.6932, "lng": 73.0688, "rating": 4.7, "crowdLevel": 0.3, "color": 0xFF6366F1},
    {"id": "p6", "name": "Trail 3 (Margalla)", "category": "Parks", "lat": 33.7500, "lng": 73.0650, "rating": 4.6, "crowdLevel": 0.5, "color": 0xFF10B981},
    {"id": "p7", "name": "Lok Virsa Museum", "category": "Culture", "lat": 33.6967, "lng": 73.0715, "rating": 4.2, "crowdLevel": 0.2, "color": 0xFF6366F1},
    {"id": "p8", "name": "Saidpur Village", "category": "Food", "lat": 33.7397, "lng": 73.0667, "rating": 4.4, "crowdLevel": 0.6, "color": 0xFFF59E0B},
    {"id": "p9", "name": "Serena Hotel", "category": "Hotels", "lat": 33.7118, "lng": 73.0901, "rating": 4.9, "crowdLevel": 0.4, "color": 0xFF8B5CF6},
    {"id": "p10", "name": "F-7 Jinnah Super", "category": "Shopping", "lat": 33.7136, "lng": 73.0575, "rating": 4.0, "crowdLevel": 0.7, "color": 0xFFEC4899},
    {"id": "p11", "name": "Lake View Park", "category": "Parks", "lat": 33.7064, "lng": 73.1192, "rating": 4.3, "crowdLevel": 0.5, "color": 0xFF10B981},
    {"id": "p12", "name": "Islamabad Zoo", "category": "Parks", "lat": 33.7300, "lng": 73.0585, "rating": 3.8, "crowdLevel": 0.3, "color": 0xFF10B981},
    {"id": "p13", "name": "NUST Cafe", "category": "Food", "lat": 33.6420, "lng": 72.9850, "rating": 4.5, "crowdLevel": 0.6, "color": 0xFFF59E0B},
    {"id": "p14", "name": "G-12 Markaz", "category": "Shopping", "lat": 33.6480, "lng": 72.9920, "rating": 4.2, "crowdLevel": 0.8, "color": 0xFFEC4899},
    {"id": "p15", "name": "NUST Lake", "category": "Parks", "lat": 33.6390, "lng": 72.9890, "rating": 4.7, "crowdLevel": 0.3, "color": 0xFF10B981},
    {"id": "p16", "name": "NUST Hostel", "category": "Hotels", "lat": 33.6400, "lng": 72.9800, "rating": 4.0, "crowdLevel": 0.5, "color": 0xFF8B5CF6},
    {"id": "p17", "name": "Savour Foods", "category": "Food", "lat": 33.6520, "lng": 72.9950, "rating": 4.8, "crowdLevel": 0.9, "color": 0xFFF59E0B},
]

@app.get("/places")
def list_places(category: str = ""):
    """Get all sample places, optionally filtered by category"""
    if category:
        return [p for p in SAMPLE_PLACES if p["category"].lower() == category.lower()]
    return SAMPLE_PLACES

@app.get("/places/{place_id}")
async def get_place(place_id: str):
    """Get detailed place information"""
    try:
        # We would typically fetch from OpenTripMap here on the backend too if needed,
        # but right now Flutter is also configured to hit OpenTripMap directly.
        # This endpoint can act as a proxy or just return our custom data (crowds, etc).
        # We'll just return crowd data mock for now
        crowd_level = calculate_crowd_score(place_id)
        return {"id": place_id, "crowd_level": crowd_level}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/places/nearby")
async def get_nearby_places(
    latitude: float,
    longitude: float,
    radius: int = 5000,
    category: str = None,
    limit: int = 100,
):
    """Get places within radius of location"""
    try:
        if not OPENTRIPMAP_KEY:
            if category:
                return [p for p in SAMPLE_PLACES if p["category"].lower() == category.lower()]
            return SAMPLE_PLACES

        kinds_map = {
            "food": "foods",
            "hotels": "accommodations",
            "parks": "natural",
            "culture": "cultural",
            "shopping": "shops"
        }

        kinds = "&kinds=interesting_places,foods,accommodations,natural,cultural,shops"
        if category and category.lower() in kinds_map:
            kinds = f"&kinds={kinds_map[category.lower()]}"

        url = f"https://api.opentripmap.com/0.1/en/places/radius?radius={radius}&lon={longitude}&lat={latitude}&apikey={OPENTRIPMAP_KEY}{kinds}&limit={limit}"
        
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(url)
            
            if res.status_code == 200:
                data = res.json()
                features = data.get("features", [])
                places = []
                for f in features:
                    props = f.get("properties", {})
                    geom = f.get("geometry", {}).get("coordinates", [0, 0])
                    if not props.get("name"):
                        continue
                        
                    raw_kinds = props.get("kinds", "")
                    cat = "Culture"
                    if "foods" in raw_kinds: cat = "Food"
                    elif "accommodations" in raw_kinds: cat = "Hotels"
                    elif "natural" in raw_kinds: cat = "Parks"
                    elif "shops" in raw_kinds: cat = "Shopping"
                    
                    color = 0xFF6366F1
                    if cat == "Food": color = 0xFFF59E0B
                    elif cat == "Hotels": color = 0xFF8B5CF6
                    elif cat == "Parks": color = 0xFF10B981
                    elif cat == "Shopping": color = 0xFFEC4899
                    
                    places.append({
                        "id": props.get("xid"),
                        "name": props.get("name"),
                        "category": cat,
                        "lat": geom[1],
                        "lng": geom[0],
                        "rating": props.get("rate", 4.0),
                        "crowdLevel": 0.5,
                        "color": color
                    })
                
                if not places and not category:
                    return SAMPLE_PLACES
                return places
            else:
                return SAMPLE_PLACES
    except Exception as e:
        print(f"Error fetching from OpenTripMap: {e}")
        return SAMPLE_PLACES

def calculate_crowd_score(place_id: str) -> int:
    # In a real app, this combines Google Popular Times + user reports
    # Mocking a dynamic crowd score based on hash of id + current hour
    current_hour = datetime.utcnow().hour
    hash_val = int(hashlib.md5(place_id.encode()).hexdigest(), 16)
    base = (hash_val % 100)
    # add some hour variation
    return (base + current_hour) % 100

@app.get("/places/{place_id}/crowds")
async def get_place_crowds(place_id: str):
    """Get crowd data for a place"""
    try:
        crowd_score = calculate_crowd_score(place_id)
        return {
            "place_id": place_id,
            "crowd_level": crowd_score,
            "timestamp": datetime.utcnow().isoformat(),
            "source": "combined",
            "peak_hours": ["12:00", "18:00"],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/places/{place_id}/crowds")
async def report_crowd_level(
    place_id: str,
    crowd_level: int,
    user_id: str,
):
    """User reports current crowd level"""
    if not 0 <= crowd_level <= 100:
        raise HTTPException(status_code=400, detail="Crowd level must be 0-100")
    
    # Normally save to DB here
    return {"success": True, "message": "Crowd level reported"}

@app.get("/discovery/trending")
async def get_trending_places(limit: int = 10):
    """Get trending places (most visited this week)"""
    sorted_places = sorted(SAMPLE_PLACES, key=lambda x: x.get("rating", 0), reverse=True)
    return sorted_places[:limit]

@app.get("/discovery/top-visited")
async def get_top_visited(limit: int = 10, city: str = None):
    """Get most visited places"""
    sorted_places = sorted(SAMPLE_PLACES, key=lambda x: x.get("rating", 0), reverse=True)
    return sorted_places[:limit]

# ============ PHASE 9: WEBSOCKET CHAT & COMMUNITY ============

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, list[dict]] = {}  # trip_id -> [{ws, user_id, user_name}]

    async def connect(self, websocket: WebSocket, trip_id: str, user_id: str, user_name: str):
        await websocket.accept()
        if trip_id not in self.active_connections:
            self.active_connections[trip_id] = []
        self.active_connections[trip_id].append({
            "ws": websocket, "user_id": user_id, "user_name": user_name
        })
        # Notify others
        await self.broadcast(trip_id, json.dumps({
            "type": "user_joined",
            "user_id": user_id,
            "user_name": user_name,
            "timestamp": datetime.utcnow().isoformat(),
        }), exclude_user=user_id)

    def disconnect(self, trip_id: str, user_id: str):
        if trip_id in self.active_connections:
            self.active_connections[trip_id] = [
                c for c in self.active_connections[trip_id] if c["user_id"] != user_id
            ]

    async def broadcast(self, trip_id: str, message: str, exclude_user: str = None):
        if trip_id not in self.active_connections:
            return
        for conn in self.active_connections[trip_id]:
            if exclude_user and conn["user_id"] == exclude_user:
                continue
            try:
                await conn["ws"].send_text(message)
            except Exception:
                pass

manager = ConnectionManager()

# In-memory message store (replace with DB in production)
messages_db: dict[str, list] = {}

@app.websocket("/ws/chat/{trip_id}")
async def websocket_chat(websocket: WebSocket, trip_id: str, user_id: str = "", user_name: str = "Guest"):
    await manager.connect(websocket, trip_id, user_id, user_name)
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            msg_type = payload.get("type", "message")

            if msg_type == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
                continue

            if msg_type == "typing":
                await manager.broadcast(trip_id, data, exclude_user=user_id)
                continue

            if msg_type == "message":
                # Preserve the client message ID when present so the sender can dedupe echoed messages.
                payload["id"] = payload.get("id") or str(uuid.uuid4())
                payload["timestamp"] = datetime.utcnow().isoformat()
                # Store message
                if trip_id not in messages_db:
                    messages_db[trip_id] = []
                messages_db[trip_id].append(payload)
                # Broadcast to all (including sender for confirmation)
                await manager.broadcast(trip_id, json.dumps(payload))

    except WebSocketDisconnect:
        manager.disconnect(trip_id, user_id)
        await manager.broadcast(trip_id, json.dumps({
            "type": "user_left",
            "user_id": user_id,
            "user_name": user_name,
            "timestamp": datetime.utcnow().isoformat(),
        }))

@app.get("/chat/{trip_id}/history")
async def get_chat_history(trip_id: str, limit: int = 50):
    """Get chat message history for a trip"""
    msgs = messages_db.get(trip_id, [])
    return msgs[-limit:]


# ── Community Updates ──

community_updates_db: dict[str, list] = {}  # place_id -> [updates]

class CommunityUpdateRequest(BaseModel):
    place_id: str
    user_id: str
    user_name: str
    user_initials: str
    text: str
    type: str  # 'tip', 'warning', 'review'

@app.get("/places/{place_id}/updates")
async def get_community_updates(place_id: str):
    """Get community updates for a place"""
    return community_updates_db.get(place_id, [])

@app.post("/places/{place_id}/updates")
async def post_community_update(place_id: str, req: CommunityUpdateRequest):
    """Post a new community update"""
    update = {
        "id": str(uuid.uuid4()),
        "place_id": place_id,
        "user_id": req.user_id,
        "user_name": req.user_name,
        "user_initials": req.user_initials,
        "text": req.text,
        "type": req.type,
        "likes": 0,
        "user_liked": False,
        "images": [],
        "timestamp": datetime.utcnow().isoformat(),
    }
    if place_id not in community_updates_db:
        community_updates_db[place_id] = []
    community_updates_db[place_id].insert(0, update)
    return update

@app.post("/places/{place_id}/updates/{update_id}/like")
async def like_update(place_id: str, update_id: str):
    """Toggle like on a community update"""
    updates = community_updates_db.get(place_id, [])
    for u in updates:
        if u["id"] == update_id:
            u["likes"] = u.get("likes", 0) + 1
            return {"success": True, "likes": u["likes"]}
    raise HTTPException(status_code=404, detail="Update not found")

@app.delete("/places/{place_id}/updates/{update_id}")
async def delete_update(place_id: str, update_id: str):
    """Delete a community update"""
    updates = community_updates_db.get(place_id, [])
    community_updates_db[place_id] = [u for u in updates if u["id"] != update_id]
    return {"success": True}


# ============ PHASE 10: DASHBOARD & FAVORITES ============

favorites_db: dict[str, list] = {}  # user_id -> [place_ids]
user_stats_db: dict[str, dict] = {}  # user_id -> stats

@app.get("/users/{user_id}/dashboard")
async def get_dashboard(user_id: str):
    """Get user dashboard data"""
    stats = user_stats_db.get(user_id, {
        "trips_completed": 0,
        "places_visited": 0,
        "reviews_contributed": 0,
        "total_days_traveled": 0,
        "cities_visited": 0,
        "total_budget_spent": 0.0,
    })
    fav_places = favorites_db.get(user_id, [])
    saved_count = len(saved_itineraries_db.get(user_id, []))
    return {
        "stats": stats,
        "favorite_place_ids": fav_places,
        "saved_itineraries_count": saved_count,
    }

@app.get("/users/{user_id}/favorites")
async def get_favorites(user_id: str):
    """Get user's favorite place IDs"""
    return favorites_db.get(user_id, [])

@app.post("/users/{user_id}/favorites/{place_id}")
async def add_favorite(user_id: str, place_id: str):
    """Add a place to user's favorites"""
    if user_id not in favorites_db:
        favorites_db[user_id] = []
    if place_id not in favorites_db[user_id]:
        favorites_db[user_id].append(place_id)
    return {"success": True}

@app.delete("/users/{user_id}/favorites/{place_id}")
async def remove_favorite(user_id: str, place_id: str):
    """Remove a place from user's favorites"""
    if user_id in favorites_db:
        favorites_db[user_id] = [p for p in favorites_db[user_id] if p != place_id]
    return {"success": True}


# ============ PHASE 11: SAVE & EXPORT ITINERARIES ============

saved_itineraries_db: dict[str, list] = {}  # user_id -> [itineraries]

class SaveItineraryRequest(BaseModel):
    destination: str
    days: int
    budget: float
    summary: str
    itinerary_json: dict  # The full itinerary payload
    status: str = "planned"  # 'planned', 'ongoing', 'completed'

@app.post("/itineraries/save")
async def save_itinerary(user_id: str, req: SaveItineraryRequest):
    """Save a generated itinerary"""
    entry = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "destination": req.destination,
        "days": req.days,
        "budget": req.budget,
        "summary": req.summary,
        "itinerary": req.itinerary_json,
        "status": req.status,
        "is_favorite": False,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    if user_id not in saved_itineraries_db:
        saved_itineraries_db[user_id] = []
    saved_itineraries_db[user_id].insert(0, entry)
    return entry

@app.get("/users/{user_id}/itineraries")
async def get_saved_itineraries(user_id: str):
    """Get all saved itineraries for a user"""
    return saved_itineraries_db.get(user_id, [])

@app.delete("/itineraries/{itinerary_id}")
async def delete_itinerary(itinerary_id: str, user_id: str):
    """Delete a saved itinerary"""
    if user_id in saved_itineraries_db:
        saved_itineraries_db[user_id] = [
            i for i in saved_itineraries_db[user_id] if i["id"] != itinerary_id
        ]
    return {"success": True}

@app.get("/users/{user_id}/trips-history")
async def get_trips_history(user_id: str):
    """Get past trips for a user"""
    itineraries = saved_itineraries_db.get(user_id, [])
    return [i for i in itineraries if i["status"] == "completed"]


# ============ HEALTH CHECK ============

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "TripGenie Backend", "version": "2.0", "phases": "7-12"}


@app.post("/debug/reset-state")
def reset_state():
    """Reset in-memory backend state for local development."""
    users_db.clear()
    users_db["demo@example.com"] = {
        "id": "user_1",
        "name": "Demo User",
        "email": "demo@example.com",
        "password_hash": hashlib.sha256("password123".encode()).hexdigest(),
    }
    messages_db.clear()
    community_updates_db.clear()
    favorites_db.clear()
    user_stats_db.clear()
    saved_itineraries_db.clear()
    manager.active_connections.clear()
    return {"success": True, "message": "Backend state reset"}
