import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:submission/controller/result_controller.dart';
import 'package:submission/service/food_classifier_service.dart';
import 'package:submission/service/meal_db_service.dart';
import 'package:submission/service/gemini_nutrition_service.dart';

class ResultPage extends StatelessWidget {
  final File imageFile;
  const ResultPage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResultController(),
      child: _ResultPageBody(imageFile: imageFile),
    );
  }
}

class _ResultPageBody extends StatefulWidget {
  final File imageFile;
  const _ResultPageBody({required this.imageFile});

  @override
  State<_ResultPageBody> createState() => _ResultPageBodyState();
}

class _ResultPageBodyState extends State<_ResultPageBody> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ResultController>().runAll(widget.imageFile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ResultController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D7D46),
        foregroundColor: Colors.white,
        title: const Text('Hasil Analisis', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Food Photo ──────────────────────────────────────────────
            _FoodImageCard(imageFile: widget.imageFile),
            const SizedBox(height: 16),

            // ── Classification Results ───────────────────────────────────
            if (controller.isClassifying)
              const _LoadingCard(label: 'Mengidentifikasi makanan...')
            else if (controller.error != null)
              _ErrorCard(message: controller.error!)
            else if (controller.classifications.isNotEmpty)
              _ClassificationCard(classifications: controller.classifications),

            const SizedBox(height: 16),

            // ── Nutrition (Gemini) ────────────────────────────────────────
            if (controller.isLoadingNutrition)
              const _LoadingCard(label: 'Memuat informasi nutrisi...')
            else if (controller.nutrition != null)
              _NutritionCard(nutrition: controller.nutrition!),

            const SizedBox(height: 16),

            // ── Recipe (MealDB) ───────────────────────────────────────────
            if (controller.isLoadingRecipe)
              const _LoadingCard(label: 'Mencari resep...')
            else if (controller.recipe != null)
              _RecipeCard(recipe: controller.recipe!),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _FoodImageCard extends StatelessWidget {
  final File imageFile;
  const _FoodImageCard({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Image.file(imageFile, fit: BoxFit.cover),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  final List<FoodClassification> classifications;
  const _ClassificationCard({required this.classifications});

  @override
  Widget build(BuildContext context) {
    final top = classifications.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fastfood_rounded, color: Color(0xFF2D7D46), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Hasil Prediksi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 20),
          // Top prediction
          Row(
            children: [
              Expanded(
                child: Text(
                  top.label,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7D46),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(top.confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (classifications.length > 1) ...[
            const SizedBox(height: 12),
            Text('Prediksi Lain:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 6),
            ...classifications.skip(1).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c.label, style: const TextStyle(fontSize: 13)),
                        ),
                        Text(
                          '${(c.confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final NutritionInfo nutrition;
  const _NutritionCard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Informasi Nutrisi (per 100g)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 20),
          if (nutrition.description.isNotEmpty) ...[
            Text(nutrition.description, style: TextStyle(color: Colors.grey[700], height: 1.5)),
            const SizedBox(height: 12),
          ],
          _NutritionRow(label: 'Kalori', value: '${nutrition.calories.toStringAsFixed(0)} kcal', icon: Icons.local_fire_department_rounded, color: Colors.orange),
          _NutritionRow(label: 'Karbohidrat', value: '${nutrition.carbs.toStringAsFixed(1)} g', icon: Icons.grain_rounded, color: Colors.amber),
          _NutritionRow(label: 'Lemak', value: '${nutrition.fat.toStringAsFixed(1)} g', icon: Icons.opacity_rounded, color: Colors.yellow[700]!),
          _NutritionRow(label: 'Serat', value: '${nutrition.fiber.toStringAsFixed(1)} g', icon: Icons.eco_rounded, color: Colors.green),
          _NutritionRow(label: 'Protein', value: '${nutrition.protein.toStringAsFixed(1)} g', icon: Icons.fitness_center_rounded, color: Colors.blue),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _NutritionRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final MealRecipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF6A1B9A), size: 22),
              const SizedBox(width: 8),
              const Text('Resep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 20),
          // Meal thumb
          if (recipe.thumbnailUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                recipe.thumbnailUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            recipe.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (recipe.area.isNotEmpty || recipe.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [if (recipe.area.isNotEmpty) recipe.area, if (recipe.category.isNotEmpty) recipe.category].join(' · '),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          // Ingredients
          const Text('Bahan-bahan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          ...recipe.ingredients.map(
            (ing) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF2D7D46), fontSize: 16)),
                  Expanded(child: Text(ing, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Instructions
          const Text('Cara Membuat:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            recipe.instructions,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
