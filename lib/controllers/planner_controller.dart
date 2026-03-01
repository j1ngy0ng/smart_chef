import 'dart:convert';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';
import '../services/local_db_service.dart';

class PlannerController extends GetxController {
  final LocalDbService _dbService = LocalDbService();

  var isLoading = false.obs;
  var plannedMeals = <Meal>[].obs;
  var selectedDay = DateTime.now().obs;
  var focusedDay = DateTime.now().obs;

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

  // --- AI & Integration ---
  void addFromPost(PostModel post) {
    final meal = Meal(
      title: post.title,
      type: "Lunch",
      kcal: 500,
      imageUrl: post.imageUrl ?? "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=500",
      ingredients: "Community Favorite",
      steps: post.content,
      date: selectedDay.value.toIso8601String().split('T')[0],
    );
    addMeal(meal);
  }

  // Inside your PlannerController
  Future<void> generateSmartPlan({
    required DateTime start,
    required DateTime end,
    required List<String> mealTypes, // e.g., ["Breakfast", "Lunch"]
    String? craving,                // e.g., "Something spicy"
  }) async {
    try {
      isLoading.value = true;

      // Switch to the stable 2.5 model
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      // Build a list of dates to show the AI
      int daysCount = end.difference(start).inDays + 1;
      List<String> rangeDates = List.generate(daysCount, (i) =>
      start.add(Duration(days: i)).toIso8601String().split('T')[0]);

      final prompt = """
    I need a meal plan for the following dates: ${rangeDates.join(', ')}.
    For each date, generate these meal types: ${mealTypes.join(' and ')}.
    Specific Preference: ${craving ?? 'Healthy and balanced'}.

    Return ONLY a JSON array of objects. 
    Format: [{"date": "YYYY-MM-DD", "type": "Lunch", "title": "...", "kcal": 500, "ingredients": "...", "steps": "..."}]
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      String? text = response.text;

      if (text != null) {
        // Find the JSON block
        final jsonStart = text.indexOf('[');
        final jsonEnd = text.lastIndexOf(']');
        final cleanJson = text.substring(jsonStart, jsonEnd + 1);

        final List<dynamic> dataList = jsonDecode(cleanJson);

        for (var item in dataList) {
          final meal = Meal(
            title: item['title'],
            type: item['type'],
            kcal: item['kcal'],
            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500",
            ingredients: item['ingredients'],
            steps: item['steps'],
            date: item['date'],
          );
          await _dbService.insertMeal(meal);
        }

        fetchMealsForDate(selectedDay.value);
        Get.back(); // Close your bottom sheet
        Get.snackbar("Plan Created", "Generated $daysCount days of meals!");
      }
    } catch (e) {
      print("Gemini 2.5 Error: $e");
      Get.snackbar("Error", "Could not reach the AI server.");
    } finally {
      isLoading.value = false;
    }
  }

  // --- Helpers ---
  int get totalKcal => plannedMeals.fold(0, (sum, item) => sum + item.kcal);

  void updateSelectedDay(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
    fetchMealsForDate(selected);
  }
}