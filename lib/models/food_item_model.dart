// models/food_item_model.dart
// ADD THESE TWO CLASSES to your existing models/nutrition_model.dart

import 'package:get/get.dart';
import 'nutrition_model.dart';

/// Represents a food item from the search database or barcode scan.
/// Used to populate the search results list in AddMealScreen.
class FoodItem {
  final String id;
  final String name;
  final String brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? barcode;
  final String? imageUrl;

  FoodItem({
    required this.id,
    required this.name,
    this.brand = '',
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.barcode,
    this.imageUrl,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      caloriesPer100g: (map['calories_per_100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (map['fat_per_100g'] as num?)?.toDouble() ?? 0,
      barcode: map['barcode'],
      imageUrl: map['image_url'],
    );
  }

  /// Scale nutrition values by serving size (grams)
  Map<String, double> nutritionForServing(double grams) {
    final ratio = grams / 100.0;
    return {
      'calories': caloriesPer100g * ratio,
      'protein': proteinPer100g * ratio,
      'carbs': carbsPer100g * ratio,
      'fat': fatPer100g * ratio,
    };
  }

  // ── Static mock food database for development ──────────────────────────────
  static List<FoodItem> mockFoods() => [
    FoodItem(id: 'f1', name: 'Chicken Breast', brand: 'Generic', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
    FoodItem(id: 'f2', name: 'Brown Rice', brand: 'Generic', caloriesPer100g: 216, proteinPer100g: 4.5, carbsPer100g: 44.8, fatPer100g: 1.8),
    FoodItem(id: 'f3', name: 'Oatmeal', brand: 'Quaker', caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9),
    FoodItem(id: 'f4', name: 'Greek Yogurt', brand: 'Chobani', caloriesPer100g: 97, proteinPer100g: 9, carbsPer100g: 3.6, fatPer100g: 5),
    FoodItem(id: 'f5', name: 'Banana', brand: 'Fresh', caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 22.8, fatPer100g: 0.3),
    FoodItem(id: 'f6', name: 'Salmon Fillet', brand: 'Fresh', caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
    FoodItem(id: 'f7', name: 'Whole Egg', brand: 'Generic', caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11),
    FoodItem(id: 'f8', name: 'Avocado', brand: 'Fresh', caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 8.5, fatPer100g: 14.7),
    FoodItem(id: 'f9', name: 'Sweet Potato', brand: 'Fresh', caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1),
    FoodItem(id: 'f10', name: 'Almonds', brand: 'Generic', caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 49.9),
    FoodItem(id: 'f11', name: 'Whey Protein Shake', brand: 'Optimum Nutrition', caloriesPer100g: 400, proteinPer100g: 80, carbsPer100g: 7, fatPer100g: 4),
    FoodItem(id: 'f12', name: 'Broccoli', brand: 'Fresh', caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 6.6, fatPer100g: 0.4),
    FoodItem(id: 'f13', name: 'White Rice', brand: 'Generic', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
    FoodItem(id: 'f14', name: 'Peanut Butter', brand: 'Skippy', caloriesPer100g: 588, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50),
    FoodItem(id: 'f15', name: 'Milk (Full Cream)', brand: 'Generic', caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3),
  ];
}

/// A cart item = FoodItem + chosen serving size, used in AddMealScreen session
class MealCartItem {
  final String cartId;
  final FoodItem food;
  // Rx fields so Obx() in the UI rebuilds when these change
  final RxDouble servingGrams;
  final RxBool isEditing;

  MealCartItem({
    required this.cartId,
    required this.food,
    double initialServing = 100,
    bool initialEditing = false,
  })  : servingGrams = initialServing.obs,
        isEditing = initialEditing.obs;

  double get calories => food.caloriesPer100g * servingGrams.value / 100;
  double get protein  => food.proteinPer100g  * servingGrams.value / 100;
  double get carbs    => food.carbsPer100g    * servingGrams.value / 100;
  double get fat      => food.fatPer100g      * servingGrams.value / 100;

  /// Convert to NutritionLog for saving to Supabase
  NutritionLog toNutritionLog({
    required String userId,
    required String mealType,
  }) {
    return NutritionLog(
      id: '',
      userId: userId,
      mealType: mealType,
      foodName: food.name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingSize: servingGrams.value,
      barcode: food.barcode,
      loggedAt: DateTime.now(),
    );
  }
}