from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import json
import os
from dotenv import load_dotenv
 
load_dotenv()  # loading .env file
 
app = FastAPI(title="Wanderland Backend")
 
# Connection to Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
 
GROK_KEY    = os.getenv("YOUR_API_KEY", "")
WEATHER_KEY = os.getenv("YOUR_API_KEY", "")
 
# Testing route - opening in browser to check server
@app.get("/")
def root():
    return {"status": "Wanderland backend is running"}
 
 
# Places route
@app.get("/places")
def get_places():
    return [
        {"name": "Badshahi Mosque",     "lat": 31.5881, "lng": 74.3098, "category": "Attraction", "color": 0xFF6366F1, "rating": 4.9},
        {"name": "Lahore Fort",         "lat": 31.5882, "lng": 74.3155, "category": "Attraction", "color": 0xFF6366F1, "rating": 4.8},
        {"name": "Food Street",         "lat": 31.5744, "lng": 74.3149, "category": "Food",       "color": 0xFFF59E0B, "rating": 4.6},
        {"name": "Packages Mall",       "lat": 31.4686, "lng": 74.2698, "category": "Shopping",   "color": 0xFFEC4899, "rating": 4.2},
        {"name": "Jilani Park",         "lat": 31.5131, "lng": 74.3408, "category": "Park",       "color": 0xFF10B981, "rating": 4.4},
        {"name": "Coffee Tea & Company","lat": 31.5120, "lng": 74.3310, "category": "Cafe",       "color": 0xFF8B5CF6, "rating": 4.5},
    ]
 
 
# AI Itinerary Generator 
class ItineraryRequest(BaseModel):
    destination: str
    days: int
    budget: float
    interests: list[str]
 
@app.post("/generate-itinerary")
async def generate_itinerary(req: ItineraryRequest):
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
            "https://api.x.ai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {GROK_KEY}",
                "Content-Type":  "application/json",
            },
            json={
                "model":       "grok-3-mini",
                "messages":    [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens":  3000,
            },
        )
 
    raw = response.json()["choices"][0]["message"]["content"]
    raw = raw.strip().lstrip("```json").rstrip("```").strip()
    return json.loads(raw)
 
 
# Weather
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
 
 
# Trip Posts 
# Replace with a real database in Phase 9
trips_db = []   # list that resets when server restarts
 
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
    new["id"]              = str(len(trips_db) + 1)
    new["current_members"] = 1
    new["posted_ago"]      = "Just now"
    trips_db.append(new)
    return new
 