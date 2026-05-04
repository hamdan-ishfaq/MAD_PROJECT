# TripGenie Authentication & Features Guide

## 🔐 Authentication System (NEW)

### Demo Account
```
Email: demo@example.com
Password: password123
```

### How It Works
1. **Register**: New users can create an account with name, email, and password
2. **Login**: Users login with email/password to get a JWT token
3. **Token Storage**: Token is saved locally in SharedPreferences
4. **API Calls**: All authenticated requests include the token

### Backend Endpoints

#### Register
```bash
POST http://localhost:8000/auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepassword123"
}

Response:
{
  "id": "user_2",
  "name": "John Doe",
  "email": "john@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### Login
```bash
POST http://localhost:8000/auth/login
Content-Type: application/json

{
  "email": "demo@example.com",
  "password": "password123"
}

Response:
{
  "id": "user_1",
  "name": "Demo User",
  "email": "demo@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

## 💬 Chat Persistence (NEW)

- Messages are now saved to device storage using SharedPreferences
- When you send a message, it's saved locally immediately
- When you open a chat room again, all previous messages load
- Each trip has its own separate message storage

**Storage Key Format**: `chat_messages_{trip_id}`

---

## 🤖 Groq AI API (FIXED)

### What Changed
- ✅ Fixed endpoint from `api.x.ai` → `api.groq.com`
- ✅ Model: `mixtral-8x7b-32768`
- ✅ API Key loaded from `.env` file

### Testing
```bash
# Generate an itinerary
POST http://localhost:8000/generate-itinerary
Content-Type: application/json

{
  "destination": "Istanbul",
  "days": 5,
  "budget": 3000,
  "interests": ["History", "Food", "Culture"]
}
```

---

## 🚀 Backend Setup

### Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### Run Server
```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server will be available at: `http://localhost:8000`

### Health Check
```bash
curl http://localhost:8000/health
# Response: {"status": "ok", "service": "TripGenie Backend"}
```

---

## 📱 Frontend Setup

### Install Dependencies
```bash
flutter pub get
```

### Update Flutter Dotenv Config
Make sure `.env` file is in your pubspec.yaml (already configured):
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

### Run on Emulator/Web
```bash
# Android Emulator
flutter run

# Web Browser
flutter run -d chrome

# Specific Device
flutter run -d <device-id>
```

---

## ✨ Features Status

| Feature | Status | Notes |
|---------|--------|-------|
| **User Registration** | ✅ Complete | Creates account, returns JWT token |
| **User Login** | ✅ Complete | Validates email/password, returns JWT |
| **Auth Tokens** | ✅ Complete | JWT tokens (30-day expiry) |
| **Chat Persistence** | ✅ Complete | Messages saved to SharedPreferences |
| **Trip Posts** | ✅ Complete | Create & browse trips |
| **AI Itineraries** | ✅ Complete | Groq Cloud API working |
| **Weather API** | ✅ Complete | OpenWeatherMap integration |
| **Maps** | ✅ Complete | OpenStreetMap (free tier) |
| **Real-time Chat** | ⏳ Planned | WebSocket/Firebase (Phase 9) |
| **Real Database** | ⏳ Planned | PostgreSQL/MongoDB (Phase 9) |

---

## 🔒 Security Notes

### Current (Development)
- Passwords hashed with SHA256
- JWT tokens valid for 30 days
- CORS enabled for all origins (change in production)

### Production TODO
- Use bcrypt for password hashing instead of SHA256
- Store secrets in environment variables
- Restrict CORS origins
- Migrate to real database (PostgreSQL/MongoDB)
- Add rate limiting on auth endpoints
- Add email verification for registration
- Add password reset functionality

---

## 📍 API Base URL

**Local Development:**
```
http://localhost:8000
```

**Update in**: `lib/core/services/auth_api_service.dart`
```dart
static const String _baseUrl = 'http://localhost:8000';
```

Change this when deploying to production server.

---

## 🧪 Quick Test

1. **Start Backend:**
   ```bash
   cd backend
   python -m uvicorn main:app --reload
   ```

2. **Run Frontend:**
   ```bash
   flutter run -d chrome
   ```

3. **Test Login:**
   - Email: `demo@example.com`
   - Password: `password123`

4. **Test Chat:**
   - Join a trip → Click "Join & Chat"
   - Type a message → Refresh page → Message still there ✅

---

Generated: 2026-05-04
Phase: 7 (Auth + Chat Persistence)
Next: Phase 9 (Real Database + Real-time Chat)
