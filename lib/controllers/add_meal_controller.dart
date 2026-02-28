// controllers/add_meal_controller.dart
// GetX controller for Add/Edit Meal screen.
// Follows the exact same pattern as your existing controllers.
// Uses NutritionController to refresh the dashboard after saving.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_model.dart';
import '../models/food_item_model.dart';
import 'nutrition_controller.dart';

class AddMealController extends GetxController {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── State ────────────────────────────────────────────────────────────────────
  final RxString selectedMealType = 'breakfast'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isScanning = false.obs;

  // Search results
  final RxList<FoodItem> searchResults = <FoodItem>[].obs;

  // Cart — items added to this meal session
  final RxList<MealCartItem> cartItems = <MealCartItem>[].obs;

  // Edit mode — if non-null, we're editing an existing log entry
  final Rx<NutritionLog?> editingLog = Rx<NutritionLog?>(null);

  // Text controller for search field
  final TextEditingController searchController = TextEditingController();

  // Debounce timer for search
  Worker? _searchDebounce;

  // ─── Computed ─────────────────────────────────────────────────────────────────
  double get totalCalories => cartItems.fold(0, (s, i) => s + i.calories);
  double get totalProtein  => cartItems.fold(0, (s, i) => s + i.protein);
  double get totalCarbs    => cartItems.fold(0, (s, i) => s + i.carbs);
  double get totalFat      => cartItems.fold(0, (s, i) => s + i.fat);
  bool   get cartIsEmpty   => cartItems.isEmpty;

  String get userId => _client.auth.currentUser?.id ?? '';

  // ─── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();

    // Debounce search: waits 400ms after last keystroke
    _searchDebounce = debounce(
      searchQuery,
          (_) => _runSearch(),
      time: const Duration(milliseconds: 400),
    );
  }

  @override
  void onClose() {
    searchController.dispose();
    _searchDebounce?.dispose();
    super.onClose();
  }

  // ─── Edit mode initialiser ────────────────────────────────────────────────────
  /// Call this when opening the screen to EDIT an existing NutritionLog
  void initEditMode(NutritionLog log) {
    editingLog.value = log;
    selectedMealType.value = log.mealType;

    // Pre-populate cart with the single item being edited
    final fakeFoodItem = FoodItem(
      id: log.id,
      name: log.foodName,
      caloriesPer100g: log.calories / (log.servingSize / 100),
      proteinPer100g:  log.protein  / (log.servingSize / 100),
      carbsPer100g:    log.carbs    / (log.servingSize / 100),
      fatPer100g:      log.fat      / (log.servingSize / 100),
      barcode: log.barcode,
    );

    cartItems.add(MealCartItem(
      cartId: 'edit_${log.id}',
      food: fakeFoodItem,
      servingGrams: log.servingSize,
    ));
  }

  // ─── Meal Type ────────────────────────────────────────────────────────────────
  void selectMealType(String type) => selectedMealType.value = type;

  // ─── Search ───────────────────────────────────────────────────────────────────
  void onSearchChanged(String query) => searchQuery.value = query;

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    searchResults.clear();
  }

  Future<void> _runSearch() async {
    final q = searchQuery.value.trim();
    if (q.isEmpty) {
      searchResults.clear();
      return;
    }

    isSearching.value = true;
    try {
      // Try Supabase food_items table first
      final data = await _client
          .from('food_items')
          .select()
          .ilike('name', '%$q%')
          .limit(20);

      searchResults.value =
          (data as List).map((e) => FoodItem.fromMap(e)).toList();

      // Fall back to mock data if table empty or missing
      if (searchResults.isEmpty) {
        searchResults.value = FoodItem.mockFoods()
            .where((f) =>
        f.name.toLowerCase().contains(q.toLowerCase()) ||
            f.brand.toLowerCase().contains(q.toLowerCase()))
            .toList();
      }
    } catch (_) {
      // DB not set up yet — use local mock
      searchResults.value = FoodItem.mockFoods()
          .where((f) =>
      f.name.toLowerCase().contains(q.toLowerCase()) ||
          f.brand.toLowerCase().contains(q.toLowerCase()))
          .toList();
    } finally {
      isSearching.value = false;
    }
  }

  // ─── Barcode Scanner ──────────────────────────────────────────────────────────
  Future<void> scanBarcode() async {
    // In production: integrate mobile_scanner package
    // mobile_scanner: ^3.5.5 in pubspec.yaml
    // Example real integration:
    //
    // final MobileScannerController scanCtrl = MobileScannerController();
    // final result = await Get.to(() => MobileScanner(
    //   controller: scanCtrl,
    //   onDetect: (capture) {
    //     final barcode = capture.barcodes.first.rawValue;
    //     Get.back(result: barcode);
    //   },
    // ));
    // if (result != null) await _lookupBarcode(result);

    // Stub: simulate a barcode scan result
    isScanning.value = true;
    await Future.delayed(const Duration(seconds: 1));
    isScanning.value = false;

    // Simulate finding a product
    final mockResult = FoodItem.mockFoods().firstWhere(
          (f) => f.name == 'Whey Protein Shake',
    );
    addToCart(mockResult);

    Get.snackbar(
      '📷 Barcode Scanned',
      '${mockResult.name} found! Added to meal.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF4CAF50),
      colorText: const Color(0xFFFFFFFF),
    );
  }

  Future<void> _lookupBarcode(String barcode) async {
    try {
      final data = await _client
          .from('food_items')
          .select()
          .eq('barcode', barcode)
          .maybeSingle();

      if (data != null) {
        addToCart(FoodItem.fromMap(data));
      } else {
        Get.snackbar('❌ Not Found',
            'No food found for barcode $barcode. Try searching manually.',
            snackPosition: SnackPosition.TOP);
      }
    } catch (e) {
      Get.snackbar('❌ Error', 'Barcode lookup failed.',
          snackPosition: SnackPosition.TOP);
    }
  }

  // ─── Cart Management ──────────────────────────────────────────────────────────
  void addToCart(FoodItem food) {
    // Check if already in cart
    final exists = cartItems.any((i) => i.food.id == food.id);
    if (exists) {
      Get.snackbar('Already Added', '${food.name} is already in this meal.',
          snackPosition: SnackPosition.TOP);
      return;
    }

    cartItems.add(MealCartItem(
      cartId: '${food.id}_${DateTime.now().millisecondsSinceEpoch}',
      food: food,
      servingGrams: 100,
    ));
    clearSearch();
  }

  void updateServing(String cartId, double grams) {
    final idx = cartItems.indexWhere((i) => i.cartId == cartId);
    if (idx == -1) return;
    cartItems[idx].servingGrams = grams.clamp(1, 9999);
    cartItems.refresh(); // force Obx rebuild
  }

  void removeFromCart(String cartId) {
    cartItems.removeWhere((i) => i.cartId == cartId);
  }

  void toggleEditing(String cartId) {
    final idx = cartItems.indexWhere((i) => i.cartId == cartId);
    if (idx == -1) return;
    // Close all others first
    for (var i = 0; i < cartItems.length; i++) {
      cartItems[i].isEditing = (i == idx) ? !cartItems[i].isEditing : false;
    }
    cartItems.refresh();
  }

  // ─── Save / Update ────────────────────────────────────────────────────────────
  Future<void> saveMeal() async {
    if (cartItems.isEmpty) {
      Get.snackbar('⚠️ Empty', 'Add at least one food item before saving.',
          snackPosition: SnackPosition.TOP);
      return;
    }

    isSaving.value = true;
    try {
      if (editingLog.value != null) {
        // UPDATE — single item edit mode
        await _updateLog();
      } else {
        // INSERT — new meal with all cart items
        await _insertAllCartItems();
      }

      // Refresh dashboard totals
      if (Get.isRegistered<NutritionController>()) {
        await Get.find<NutritionController>().loadDashboard();
      }

      Get.back(); // Close screen
      Get.snackbar(
        '✅ Meal Saved',
        '${cartItems.length} item(s) logged to ${_mealLabel(selectedMealType.value)}.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: const Color(0xFFFFFFFF),
      );
    } catch (e) {
      Get.snackbar('❌ Error', 'Failed to save: $e',
          snackPosition: SnackPosition.TOP);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _insertAllCartItems() async {
    final rows = cartItems
        .map((item) => item
        .toNutritionLog(userId: userId, mealType: selectedMealType.value)
        .toMap())
        .toList();
    await _client.from('nutrition_logs').insert(rows);
  }

  Future<void> _updateLog() async {
    final log = editingLog.value!;
    final item = cartItems.first;
    await _client.from('nutrition_logs').update({
      'meal_type': selectedMealType.value,
      'food_name': item.food.name,
      'calories': item.calories,
      'protein': item.protein,
      'carbs': item.carbs,
      'fat': item.fat,
      'serving_size': item.servingGrams,
    }).eq('id', log.id);
  }

  // ─── Delete from DB (called from dashboard) ───────────────────────────────────
  Future<void> deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      if (Get.isRegistered<NutritionController>()) {
        final nc = Get.find<NutritionController>();
        nc.todayLogs.removeWhere((l) => l.id == logId);
        nc.loadDashboard();
      }
      Get.snackbar('🗑️ Deleted', 'Food item removed.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar('❌ Error', 'Delete failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  String _mealLabel(String type) {
    return const {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'snack': 'Snack',
    }[type] ??
        type;
  }
}