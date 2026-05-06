import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static String get _model => dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

  static Future<String> _getCompletion(String prompt, {double temperature = 0.7}) async {
    if (_apiKey.isEmpty) return "AI Service not configured. Please add GROQ_API_KEY to .env";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': 'You are a helpful travel assistant for the WanderLand app.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': temperature,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'] ?? "No response from AI";
      } else {
        return "AI Error: ${response.statusCode}";
      }
    } catch (e) {
      return "AI connection failed: $e";
    }
  }

  /// 1. AI Attraction Summarizer
  static Future<String> summarizeAttraction(String name, String description) async {
    final prompt = """
Summarize the following attraction in exactly 3 short, exciting bullet points for a traveler. 
Attraction: $name
Description: $description
Format: Only bullet points, no introduction.
""";
    return await _getCompletion(prompt);
  }

  /// 2. Packing List Generator
  static Future<String> generatePackingList({
    required String destination,
    required String activities,
    required int days,
    String weather = "unknown",
  }) async {
    final prompt = """
Generate a smart packing list for a $days-day trip to $destination.
Activities planned: $activities
Weather: $weather
Format: Categorized list (e.g., Essentials, Clothing, Gear). 
Keep it concise and practical.
""";
    return await _getCompletion(prompt);
  }

  /// 3. Predictive AI (Crowd Forecaster)
  static Future<String> predictCrowdLevel({
    required String placeName,
    required String category,
    required DateTime time,
  }) async {
    final day = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][time.weekday - 1];
    final hour = "${time.hour}:00";
    
    final prompt = """
Predict the crowd level for $placeName ($category) on a $day at $hour.
Explain why based on general patterns (e.g., "Peak lunch time", "Weekend rush", "Morning quiet").
Keep it to one sentence.
Format: "Prediction: [Level]. Reason: [Reason]."
""";
    return await _getCompletion(prompt, temperature: 0.5);
  }

  /// 4. AI Language "Survival Kit"
  static Future<String> generateLanguageKit(String destination) async {
    final prompt = """
Generate the top 10 most useful survival phrases for a traveler visiting $destination.
Include the phrase in the local language, the pronunciation, and the English meaning.
Format: A clean, easy-to-read list.
""";
    return await _getCompletion(prompt);
  }

  /// 5. AI Budget Advisor
  static Future<String> getBudgetAdvice({
    required String destination,
    required double remainingBudget,
  }) async {
    final prompt = """
I am a traveler in $destination and I have exactly \$$remainingBudget USD left for today.
Suggest a creative, cheap, and safe evening plan that fits this budget.
Format: 1 short paragraph of advice, followed by 3 bullet points of specific ideas.
""";
    return await _getCompletion(prompt, temperature: 0.8);
  }

  /// 6. Travel Diary Summarizer (Trip Story)
  static Future<String> summarizeDiary(String destination, List<String> notes) async {
    final allNotes = notes.join('\n- ');
    final prompt = """
I am writing a travel diary for my trip to $destination. Here are my raw notes:
- $allNotes

Turn these notes into a beautifully written, engaging "Trip Story" (about 2 paragraphs) that I can share with friends.
Capture the mood and highlights.
""";
    return await _getCompletion(prompt, temperature: 0.7);
  }

  /// 7. "Best Time to Visit" Insight
  static Future<String> getBestTimeToVisit(String placeName, String category) async {
    final prompt = """
What is the absolute best time of day to visit $placeName ($category) for the best experience (e.g., lighting, fewer crowds, vibe)?
Format: Keep it to one concise sentence starting with "💡 AI suggests:"
""";
    return await _getCompletion(prompt, temperature: 0.4);
  }
}
