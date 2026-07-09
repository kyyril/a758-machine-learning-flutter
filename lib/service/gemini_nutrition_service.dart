import 'package:google_generative_ai/google_generative_ai.dart';

class NutritionInfo {
  final double calories;
  final double carbs;
  final double fat;
  final double fiber;
  final double protein;
  final String description;

  const NutritionInfo({
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.protein,
    required this.description,
  });
}

class GeminiNutritionService {
  static const _defaultApiKey = 'AIzaSyD-PLACEHOLDER'; // Replace with actual key

  final GenerativeModel _model;

  GeminiNutritionService({String? apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: _defaultApiKey),
        );

  static final GeminiNutritionService instance = GeminiNutritionService();

  Future<NutritionInfo?> getNutrition(String foodName) async {
    final prompt = '''
You are a nutritionist. Provide approximate nutritional information per 100g serving for "$foodName".

Respond ONLY in this exact JSON format (no markdown, no extra text):
{
  "calories": <number>,
  "carbs": <number>,
  "fat": <number>,
  "fiber": <number>,
  "protein": <number>,
  "description": "<1-2 sentence description of the dish>"
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Extract JSON from the response
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = text.substring(jsonStart, jsonEnd + 1);

      // Parse manually to avoid dart:convert issues
      double parseNum(String key) {
        final regex = RegExp('"$key"\\s*:\\s*([0-9.]+)');
        final match = regex.firstMatch(jsonStr);
        return double.tryParse(match?.group(1) ?? '0') ?? 0;
      }

      String parseStr(String key) {
        final regex = RegExp('"$key"\\s*:\\s*"([^"]+)"');
        final match = regex.firstMatch(jsonStr);
        return match?.group(1) ?? '';
      }

      return NutritionInfo(
        calories: parseNum('calories'),
        carbs: parseNum('carbs'),
        fat: parseNum('fat'),
        fiber: parseNum('fiber'),
        protein: parseNum('protein'),
        description: parseStr('description'),
      );
    } catch (e) {
      return null;
    }
  }
}
