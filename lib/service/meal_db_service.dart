import 'dart:convert';
import 'package:http/http.dart' as http;

class MealRecipe {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String instructions;
  final List<String> ingredients;
  final String area;
  final String category;

  const MealRecipe({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.instructions,
    required this.ingredients,
    required this.area,
    required this.category,
  });

  factory MealRecipe.fromJson(Map<String, dynamic> json) {
    final ingredientList = <String>[];
    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'] as String?;
      final measure = json['strMeasure$i'] as String?;
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        final measureStr = (measure?.trim().isNotEmpty ?? false) ? '${measure!.trim()} ' : '';
        ingredientList.add('$measureStr${ingredient.trim()}');
      }
    }
    return MealRecipe(
      id: json['idMeal'] as String? ?? '',
      name: json['strMeal'] as String? ?? '',
      thumbnailUrl: json['strMealThumb'] as String? ?? '',
      instructions: json['strInstructions'] as String? ?? '',
      ingredients: ingredientList,
      area: json['strArea'] as String? ?? '',
      category: json['strCategory'] as String? ?? '',
    );
  }
}

class MealDbService {
  static const _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  MealDbService._();
  static final MealDbService instance = MealDbService._();

  /// Search for meals by name (returns top result).
  Future<MealRecipe?> searchMeal(String foodName) async {
    try {
      final uri = Uri.parse('$_baseUrl/search.php?s=${Uri.encodeComponent(foodName)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meals = data['meals'];
      if (meals == null || (meals as List).isEmpty) return null;

      return MealRecipe.fromJson(meals.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Lookup meal by ID for more detailed data.
  Future<MealRecipe?> lookupMeal(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/lookup.php?i=$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meals = data['meals'];
      if (meals == null || (meals as List).isEmpty) return null;

      return MealRecipe.fromJson(meals.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
