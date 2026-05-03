import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:Wanderland/features/planner/models/itinerary_model.dart';

// ItineraryService powered by Grok (xAI)

class ItineraryService {
  static const String _apiKey = 'YOUR_API_KEY';
  static const String _baseUrl = 'https://api.x.ai/v1/chat/completions';
  static const String _model = 'grok-3-mini';

  static Future<Itinerary?> generateItinerary({
    required String destination,
    required int days,
    required double budget,
    required List<String> interests,
  }) async {
    final interestsStr = interests.join(', ');

    final prompt = '''
You are an expert travel planner. Generate a detailed $days-day itinerary for $destination.
Total budget: \$${budget.round()} USD.
Traveler interests: $interestsStr.

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
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: json.encode({
              'model': _model,
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
          .timeout(const Duration(seconds: 30)); // Grok is fast, 30s is plenty

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String rawText = data['choices'][0]['message']['content'] as String;

        // Clean up in case Grok wraps in markdown fences
        rawText = rawText
            .trim()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final Map<String, dynamic> itineraryJson = json.decode(rawText);
        return Itinerary.fromJson(itineraryJson);
      } else {
        print('Grok API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('ItineraryService error: $e');
    }
    return null;
  }
}
