import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';
import '../services/local_db_service.dart';

class PlannerController extends GetxController {
  final LocalDbService _dbService = LocalDbService();

  // Observable states
  var isLoading = false.obs;
  var plannedMeals = <Meal>[].obs;
  var selectedDay = DateTime.now().obs;
  var focusedDay = DateTime.now().obs;
  var searchQuery = "".obs;
  var selectedCategory = "All".obs;

  @override
  void onInit() {
    super.onInit();
    fetchMealsForDate(selectedDay.value);
  }

  // --- Database Methods ---

  Future<void> fetchMealsForDate(DateTime date) async {
    try {
      isLoading.value = true;
      String formattedDate = date.toIso8601String().split('T')[0];
      List<Meal> meals = await _dbService.getMealsByDate(formattedDate);

      // SORTING: Ensures Breakfast is always at the top, then Lunch, then Dinner
      final typeOrder = {'Breakfast': 0, 'Lunch': 1, 'Dinner': 2};
      meals.sort((a, b) => (typeOrder[a.type] ?? 99).compareTo(typeOrder[b.type] ?? 99));

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
    await _dbService.updateMeal(meal); // Ensure this exists in your LocalDbService
    await fetchMealsForDate(selectedDay.value);
  }

  // --- AI & Integration ---

  void addFromPost(PostModel post, String mealType) {
    final meal = Meal(
      id: DateTime.now().millisecondsSinceEpoch,
      title: post.title,
      type: mealType,
      kcal: 500,
      imageUrl: post.imageUrl ?? "https://loremflickr.com/800/600/food",
      ingredients: "Unstructured Content",
      steps: post.content ?? "No content available",
      date: selectedDay.value.toIso8601String().split('T')[0],
      isSocialPost: true, // <--- Crucial: Mark it as social!
    );

    addMeal(meal);
  }

  Future<void> resolveRecipe(Meal meal) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      final prompt = """
      Convert this community post into a clean JSON recipe.
      Title: ${meal.title}
      Content: ${meal.steps}

      Return ONLY JSON. Use this format:
      {"kcal": 500, "ingredients": "Item 1\\nItem 2", "steps": "Step 1\\nStep 2"}
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      String text = response.text ?? "";

      // Extract JSON (Cleaning the AI chatter)
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');

      if (start != -1 && end != -1) {
        final jsonString = text.substring(start, end + 1);
        final data = jsonDecode(jsonString);

        // --- THE PERMANENT SAVE ---
        final updatedMeal = Meal(
          id: meal.id, // KEEP THE SAME ID to overwrite the old one
          title: meal.title,
          type: meal.type,
          kcal: data['kcal'] is int ? data['kcal'] : 500,
          imageUrl: meal.imageUrl,
          ingredients: data['ingredients'] ?? "",
          steps: data['steps'] ?? "",
          date: meal.date,
          isSocialPost: false, // SET TO FALSE: This hides the "Fix" button forever
        );

        // This saves it to the SQLite 'meals' table
        await _dbService.updateMeal(updatedMeal);

        // This refreshes the UI list immediately
        await fetchMealsForDate(selectedDay.value);

        Get.snackbar("Saved!", "This post is now a permanent recipe in your plan.");
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
    // 1. ANTI-SPAM: If already working, ignore additional clicks
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      // Prepare date range
      int daysCount = end.difference(start).inDays + 1;
      List<String> rangeDates = List.generate(daysCount, (i) =>
      start.add(Duration(days: i)).toIso8601String().split('T')[0]);

      final prompt = """
      Generate a healthy meal plan for these dates: ${rangeDates.join(', ')}.
      For each date, generate these meal types: ${mealTypes.join(' and ')}.
      User Preference: ${craving ?? 'Healthy and balanced'}.

      Return ONLY a JSON array of objects. 
      Format: [{"date": "YYYY-MM-DD", "type": "Lunch", "title": "...", "kcal": 500, "ingredients": "...", "steps": "..."}]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String? text = response.text;

      if (text != null) {
        final jsonStart = text.indexOf('[');
        final jsonEnd = text.lastIndexOf(']');
        final cleanJson = text.substring(jsonStart, jsonEnd + 1);
        final List<dynamic> dataList = jsonDecode(cleanJson);

        for (var item in dataList) {
          final String foodTitle = item['title'] ?? "Healthy Food";
          final String query = Uri.encodeComponent(foodTitle);

          // Use LoremFlickr with a unique 'lock' ID so different meals get different photos
          final int seed = DateTime.now().millisecondsSinceEpoch + dataList.indexOf(item);
          final String stableImageUrl = "https://loremflickr.com/800/600/food,$query?lock=$seed";

          final meal = Meal(
            title: foodTitle,
            type: item['type'] ?? "Lunch",
            kcal: (item['kcal'] is int) ? item['kcal'] : (int.tryParse(item['kcal'].toString()) ?? 500),
            imageUrl: stableImageUrl, // Use this stable URL
            ingredients: item['ingredients'] ?? "",
            steps: item['steps'] ?? "",
            date: item['date'],
          );
          await _dbService.insertMeal(meal);
        }

        // 3. REFRESH UI: Fetch the current day's meals after everything is saved
        fetchMealsForDate(selectedDay.value);

        Get.back(); // Close the Bottom Sheet
        Get.snackbar(
          "Plan Ready",
          "Generated $daysCount days of customized meals.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Gemini 2.5 Error: $e");

      // 4. QUOTA HANDLING: Specific message for the 20-request daily limit
      if (e.toString().contains('429')) {
        Get.snackbar(
          "Daily Limit Reached",
          "You have used your 20 free requests for today. Please wait 24 hours.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar("Error", "AI generation failed. Please try again.");
      }
    } finally {
      isLoading.value = false;
    }
  }

  // This computed list handles both search and category filtering
  List<Meal> get filteredMeals {
    return plannedMeals.where((meal) {
      bool matchesSearch = meal.title.toLowerCase().contains(searchQuery.value.toLowerCase());
      bool matchesCategory = selectedCategory.value == "All" || meal.type == selectedCategory.value;
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