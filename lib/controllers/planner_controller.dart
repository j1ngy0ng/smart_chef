import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/grocery_item.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';
import '../services/local_db_service.dart';
import 'package:http/http.dart' as http;

class PlannerController extends GetxController {
  final LocalDbService _dbService = LocalDbService();

  // Observable states
  var isLoading = false.obs;
  var plannedMeals = <Meal>[].obs;
  var selectedDay = DateTime.now().obs;
  var focusedDay = DateTime.now().obs;
  var searchQuery = "".obs;
  var selectedCategory = "All".obs;
  // State for Grocery
  var groceryList = <GroceryItem>[].obs; // Use your new GroceryItem model
  var priceCache = <String, double>{}.obs; // The "Smart" memory
  // Calculated Totals
  double get totalGroceryPrice => groceryList.fold(0, (sum, item) => sum + item.price);

  @override
  void onInit() {
    super.onInit();
    fetchMealsForDate(selectedDay.value);
    loadGroceryList();
  }

  // --- Grocery List Logic ---

  // 1. Initial Load: Call this in onInit()
  Future<void> loadGroceryList() async {
    final List<Map<String, dynamic>> items = await _dbService.getAllGroceryItems();

    // Clean! Uses the factory you just made
    groceryList.assignAll(items.map((map) => GroceryItem.fromMap(map)).toList());
  }

  // 2. The "Add/Remove" Toggle
  Future<void> toggleGroceryItem(GroceryItem item) async {
    if (groceryList.any((i) => i.name == item.name)) {
      // Remove from list and DB
      groceryList.removeWhere((i) => i.name == item.name);
      await _dbService.removeGroceryItem(item.name);
    } else {
      // Add to list and DB
      groceryList.add(item);
      await _dbService.upsertGroceryItem(item.name, item.price, item.category);
    }
  }

  // 3. Update Price (The "Live Editor")
  Future<void> updateGroceryPrice(GroceryItem item, double newPrice) async {
    item.price = newPrice;
    // Pass the category here so the DB doesn't lose it or throw an error!
    await _dbService.upsertGroceryItem(item.name, newPrice, item.category ?? "General");
    groceryList.refresh();
  }

  Future<void> editGroceryItem({
    required String oldName,
    required String newName,
    required double newPrice,
    required String newCategory,
  }) async {
    // 1. Remove old entry if the name changed
    if (oldName != newName) {
      await _dbService.removeGroceryItem(oldName);
    }

    // 2. Update/Insert new entry
    await _dbService.upsertGroceryItem(newName, newPrice, newCategory);

    // 3. Refresh list
    await loadGroceryList();
  }

  Map<String, double> get categoryTotals {
    Map<String, double> totals = {};
    for (var item in groceryList) {
      // We use the category stored in the item, or default to 'General'
      String cat = item.category ?? "General";
      totals[cat] = (totals[cat] ?? 0) + item.price;
    }
    return totals;
  }

  // --- Database Methods ---

  Future<void> fetchMealsForDate(DateTime date) async {
    try {
      isLoading.value = true;
      String formattedDate = date.toIso8601String().split('T')[0];
      List<Meal> meals = await _dbService.getMealsByDate(formattedDate);

      // SORTING: Ensures Breakfast is always at the top, then Lunch, then Dinner
      final typeOrder = {'Breakfast': 0, 'Lunch': 1, 'Dinner': 2};
      meals.sort(
        (a, b) => (typeOrder[a.type] ?? 99).compareTo(typeOrder[b.type] ?? 99),
      );

      plannedMeals.assignAll(meals);
    } catch (e) {
      Get.snackbar("Error", "Could not load plan");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addMeal(Meal meal) async {
    await _dbService.insertMeal(meal);
    await fetchMealsForDate(selectedDay.value);
    Get.snackbar("Success", "${meal.title} added!");
  }

  Future<void> deleteMeal(int id) async {
    await _dbService.deleteMeal(id);
    await fetchMealsForDate(selectedDay.value);
    Get.snackbar("Deleted", "Meal removed");
  }

  Future<void> updateMeal(Meal meal) async {
    await _dbService.updateMeal(
      meal,
    ); // Ensure this exists in your LocalDbService
    await fetchMealsForDate(selectedDay.value);
  }

  // --- AI & Integration ---

  void addFromPost(PostModel post, String mealType) {
    final meal = Meal(
      id: null, // Let SQLite handle the ID
      title: post.title,
      type: mealType,
      kcal: 500,
      // Use the REAL image from Supabase.
      // Only use the fallback if the post literally has no image.
      imageUrl: post.imageUrl ?? "https://loremflickr.com/800/600/food,recipe",
      ingredients: "Unstructured Content",
      // Fix "Dead Code": if post.content is already a String,
      // the compiler warns that '??' is useless.
      steps: post.content,
      date: selectedDay.value.toIso8601String().split('T')[0],
      isSocialPost: true,
    );

    addMeal(meal);
  }

  Future<void> resolveRecipe(Meal meal) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Use 1.5-flash for stability
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      final prompt =
          """
      Convert this community post into a clean JSON recipe.
      Title: ${meal.title}
      Content: ${meal.steps}

      Return ONLY JSON. Use this format:
      {"kcal": 500, "ingredients": "Item 1\\nItem 2", "steps": "Step 1\\nStep 2"}
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      String text = response.text ?? "";

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');

      if (start != -1 && end != -1) {
        final jsonString = text.substring(start, end + 1);
        final Map<String, dynamic> data = jsonDecode(jsonString);

        // --- THE GLOBAL SAVE ---
        // Instead of just updating 'meal.id', we update EVERY meal with this title
        await _dbService.updateAllMealsWithTitle(
          title: meal.title,
          ingredients: data['ingredients'] ?? "",
          steps: data['steps'] ?? "",
          kcal: data['kcal'] is int ? data['kcal'] : 500,
        );

        // Refresh the current view
        await fetchMealsForDate(selectedDay.value);

        Get.snackbar(
          "Success!",
          "All instances of '${meal.title}' have been organized.",
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      Get.snackbar("Error", "Could not save the AI version.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> generateSmartPlan({
    required DateTime start,
    required DateTime end,
    required List<String> mealTypes,
    String? craving,
  }) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      int daysCount = end.difference(start).inDays + 1;
      List<String> rangeDates = List.generate(
        daysCount,
        (i) => start.add(Duration(days: i)).toIso8601String().split('T')[0],
      );

      String requestedTypes = mealTypes.join(', ');

      // Added "image_query" to the prompt instructions
      final prompt = """
      Generate a healthy meal plan for these dates: ${rangeDates.join(', ')}.
      ONLY generate these meal types: $requestedTypes. 
      If the user only asks for Breakfast, return ONLY Breakfast objects.
      
      User Preference: ${craving ?? 'Healthy and balanced'}.
      
      Return ONLY a JSON array. 
      For "image_query", provide 1-2 words of the MAIN VISUAL element (e.g., 'Omelette', 'Pancakes').
      
      Format: [{"date": "YYYY-MM-DD", "type": "$requestedTypes", "title": "...", "image_query": "...", "kcal": 500, "ingredients": "...", "steps": "..."}]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String? text = response.text;

      if (text != null) {
        final jsonStart = text.indexOf('[');
        final jsonEnd = text.lastIndexOf(']');
        final cleanJson = text.substring(jsonStart, jsonEnd + 1);
        final List<dynamic> dataList = jsonDecode(cleanJson);

        for (int i = 0; i < dataList.length; i++) {
          final item = dataList[i];
          String imageUrl = await fetchMealImage(
            item['image_query'] ?? item['title'],
            i,
          );

          final meal = Meal(
            title: item['title'] ?? "Healthy Food",
            type: item['type'] ?? "Lunch",
            kcal: (item['kcal'] is int)
                ? item['kcal']
                : (int.tryParse(item['kcal'].toString()) ?? 500),
            imageUrl: imageUrl,
            ingredients: item['ingredients'] ?? "",
            steps: item['steps'] ?? "",
            date: item['date'],
            isSocialPost: false,
          );
          await _dbService.insertMeal(meal);
        }

        fetchMealsForDate(selectedDay.value);
        Get.back();
        Get.snackbar("Plan Ready", "Generated $daysCount days of meals.");
      }
    } catch (e) {
      debugPrint("Gemini Error: $e");
      Get.snackbar("Error", "AI generation failed.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> fetchMealImage(String query, int index) async {
    final String cleanQuery = Uri.encodeComponent(query);

    // 1. Try TheMealDB (Dedicated food database - 100% Accurate)
    // It only contains photos of finished recipes.
    final mealDbUrl = "https://www.themealdb.com/api/json/v1/1/search.php?s=$cleanQuery";

    try {
      final response = await http.get(Uri.parse(mealDbUrl)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['meals'] != null && data['meals'].isNotEmpty) {
          return data['meals'][0]['strMealThumb']; // Real recipe photo
        }
      }
    } catch (e) {
      debugPrint("MealDB failed: $e");
    }

    // 2. BACKUP: Pexels (Better than Pixabay/Unsplash Source)
    // We use the Pexels "Search" URL structure.
    // Note: Pexels is highly curated for "Artistic Food" shots.
    return "https://images.pexels.com/photos/search/$cleanQuery/?orientation=landscape";

    // 3. ULTIMATE FALLBACK: LoremFlickr (Reliable placeholder)
    // return "https://loremflickr.com/800/600/$cleanQuery,dish?lock=$index";
  }

  // This computed list handles both search and category filtering
  List<Meal> get filteredMeals {
    return plannedMeals.where((meal) {
      bool matchesSearch = meal.title.toLowerCase().contains(
        searchQuery.value.toLowerCase(),
      );
      bool matchesCategory =
          selectedCategory.value == "All" ||
          meal.type == selectedCategory.value;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // --- Helpers ---

  int get totalKcal => plannedMeals.fold(0, (sum, item) => sum + item.kcal);

  void updateSelectedDay(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
    fetchMealsForDate(selected);
  }
}
