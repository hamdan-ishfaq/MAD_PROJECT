import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tripgenie/features/planner/models/itinerary_model.dart';

// ItineraryService powered by Groq Cloud
class ItineraryService {
  // Use getter so dotenv is read AFTER dotenv.load() runs in main.dart
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static String get _model =>
      dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

  static Map<String, dynamic>? _tryParseModelJson(String text) {
    final cleaned =
        text.trim().replaceAll('```json', '').replaceAll('```', '').trim();

    try {
      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      // Try extracting the largest object-like block.
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        var candidate = cleaned.substring(start, end + 1);
        // Handle common trailing-comma JSON mistakes.
        candidate = candidate.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
        try {
          return json.decode(candidate) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _repairJsonWithGroq(
      String malformedJson) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: json.encode({
              'model': _model,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You repair malformed JSON. Return ONLY a valid JSON object. No markdown or explanations.',
                },
                {
                  'role': 'user',
                  'content':
                      'Fix this malformed JSON so it becomes valid and complete JSON:\n$malformedJson',
                }
              ],
              'temperature': 0,
              'max_tokens': 3200,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        print(
            '[ItineraryService] JSON repair call failed: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final repairedText =
          (data['choices'][0]['message']['content'] as String?) ?? '';
      return _tryParseModelJson(repairedText);
    } catch (e) {
      print('[ItineraryService] JSON repair exception: $e');
      return null;
    }
  }

  static Future<Itinerary?> generateItinerary({
    required String destination,
    required int days,
    required double budget,
    required List<String> interests,
    List<String> secondaryInterests = const [],
  }) async {
    final interestsStr = interests.join(', ');
    final secondaryInterestsStr = secondaryInterests.join(', ');

    final prompt = '''
You are an expert travel planner. Generate a detailed $days-day itinerary for $destination.
Total budget: \$${budget.round()} USD.
Traveler interests: $interestsStr.
Secondary user profile interests (use only as optional suggestions if relevant): ${secondaryInterestsStr.isEmpty ? 'None' : secondaryInterestsStr}.

IMPORTANT: Respond ONLY with a valid JSON object. No explanation, no markdown, no code blocks.
Use exactly this structure:

{
  "destination": "$destination",
  "days": $days,
  "budget": $budget,
  "summary": "One sentence describing the overall trip vibe",
  "day_plans": [
    {
      "day": 1,
      "date": "Day 1",
      "activities": [
        {
          "time": "9:00 AM",
          "title": "Name of place or activity",
          "description": "2 sentence description with practical tips",
          "type": "culture"
        }
      ]
    }
  ]
}

Rules:
- Include 4-5 activities per day spread across morning, afternoon, evening
- "type" must be one of: food, culture, nature, shopping, adventure
- Keep descriptions practical (mention entry cost, how to get there, what to bring)
- Budget the activities realistically across the days
- JSON only, nothing else
''';

    try {
      // Debug: verify key is loaded
      if (_apiKey.isEmpty) {
        print(
            '[ItineraryService] ERROR: GROQ_API_KEY is empty! Make sure .env is loaded and contains GROQ_API_KEY');
        return null;
      }
      print(
          '[ItineraryService] API key loaded (${_apiKey.substring(0, 8)}...), calling Groq...');

      // Use a small retry loop to handle transient network errors (Connection
      // reset by peer, timeouts, etc.).
      http.Response? response;
      const int maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          response = await http
              .post(
                Uri.parse(_baseUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_apiKey',
                },
                body: json.encode({
                  'model': _model,
                  'response_format': {'type': 'json_object'},
                  'messages': [
                    {
                      'role': 'system',
                      'content':
                          'You are a travel planning assistant. Always respond with valid JSON only.',
                    },
                    {'role': 'user', 'content': prompt},
                  ],
                  'temperature': 0.7,
                  'max_tokens': 3000,
                }),
              )
              .timeout(const Duration(seconds: 60));

          print(
              '[ItineraryService] Response status: ${response.statusCode} (attempt $attempt)');
          break; // success or server error; exit retry loop and handle below
        } catch (e) {
          print('[ItineraryService] Request attempt $attempt failed: $e');
          if (attempt == maxAttempts) rethrow;
          // exponential backoff before retrying
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }

      if (response == null) {
        print('[ItineraryService] No response received from Groq API');
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawText = data['choices'][0]['message']['content'] as String;

        var itineraryJson = _tryParseModelJson(rawText);
        if (itineraryJson == null) {
          print(
              '[ItineraryService] Received malformed JSON, trying repair pass...');
          itineraryJson = await _repairJsonWithGroq(rawText);
        }

        if (itineraryJson == null) {
          print(
              '[ItineraryService] Could not parse or repair Groq JSON response');
          return null;
        }

        print(
            '[ItineraryService] Successfully parsed itinerary for $destination');
        return Itinerary.fromJson(itineraryJson);
      } else {
        print(
            '[ItineraryService] Groq API error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('[ItineraryService] Exception: $e');
      print('[ItineraryService] Stack: $stackTrace');
    }
    return null;
  }
}
