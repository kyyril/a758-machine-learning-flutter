import 'dart:io';
import 'package:flutter/material.dart';
import 'package:submission/service/food_classifier_service.dart';
import 'package:submission/service/meal_db_service.dart';
import 'package:submission/service/gemini_nutrition_service.dart';

class ResultController extends ChangeNotifier {
  List<FoodClassification> classifications = [];
  MealRecipe? recipe;
  NutritionInfo? nutrition;

  bool isClassifying = false;
  bool isLoadingRecipe = false;
  bool isLoadingNutrition = false;
  String? error;

  String? get topFoodName =>
      classifications.isNotEmpty ? classifications.first.label : null;

  Future<void> runAll(File imageFile) async {
    error = null;
    await _classify(imageFile);
    if (topFoodName != null) {
      await Future.wait([
        _loadRecipe(topFoodName!),
        _loadNutrition(topFoodName!),
      ]);
    }
  }

  Future<void> _classify(File imageFile) async {
    isClassifying = true;
    notifyListeners();
    try {
      classifications = await FoodClassifierService.instance.classify(imageFile.path);
    } catch (e) {
      error = 'Gagal melakukan klasifikasi: $e';
    } finally {
      isClassifying = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecipe(String foodName) async {
    isLoadingRecipe = true;
    notifyListeners();
    try {
      recipe = await MealDbService.instance.searchMeal(foodName);
    } catch (_) {
      recipe = null;
    } finally {
      isLoadingRecipe = false;
      notifyListeners();
    }
  }

  Future<void> _loadNutrition(String foodName) async {
    isLoadingNutrition = true;
    notifyListeners();
    try {
      nutrition = await GeminiNutritionService.instance.getNutrition(foodName);
    } catch (_) {
      nutrition = null;
    } finally {
      isLoadingNutrition = false;
      notifyListeners();
    }
  }
}
