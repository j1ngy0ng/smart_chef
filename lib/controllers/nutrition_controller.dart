// controllers/nutrition_controller.dart
// Follows exact same GetX pattern as your existing:
// auth_controller.dart / post_controller.dart / profile_controller.dart

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_model.dart';

class NutritionController extends GetxController {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── Observable State ───────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Today's nutrition data
  final RxDouble totalCalories = 0.0.obs;
  final RxDouble totalProtein = 0.0.obs;
  final RxDouble totalCarbs = 0.0.obs;
  final RxDouble totalFat = 0.0.obs;

  // Goals
  final Rx<UserGoals?> goals = Rx<UserGoals?>(null);

  // Health data (steps, burned, water)
  final Rx<DailyHealthData?> healthData = Rx<DailyHealthData?>(null);

  // Today's individual meal logs
  final RxList<NutritionLog> todayLogs = <NutritionLog>[].obs;

  // AI insights
  final RxList<NutritionInsight> insights = <NutritionInsight>[].obs;

  // Water intake (reactive for real-time tap updates)
  final RxInt waterGlasses = 0.obs;

  // ─── Computed getters ────────────────────────────────────────────────────────
  final RxDouble calorieGoal = 2000.0.obs;
  final RxDouble proteinGoal = 150.0.obs;
  final RxDouble carbsGoal   = 250.0.obs;
  final RxDouble fatGoal     = 65.0.obs;
  final RxInt    waterGoal   = 8.obs;

  double get calorieProgress => (totalCalories.value / calorieGoal.value).clamp(0.0, 1.0);
  double get proteinProgress => (totalProtein.value / proteinGoal.value).clamp(0.0, 1.0);
  double get carbsProgress => (totalCarbs.value / carbsGoal.value).clamp(0.0, 1.0);
  double get fatProgress => (totalFat.value / fatGoal.value).clamp(0.0, 1.0);
  double get waterProgress => (waterGlasses.value / waterGoal.value).clamp(0.0, 1.0);
  double get caloriesRemaining => calorieGoal.value - totalCalories.value;

  String get userId => _client.auth.currentUser?.id ?? '';

  // ─── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  // ─── Main Loader ─────────────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    if (userId.isEmpty) return;
    isLoading.value = true;
    try {
      await Future.wait([
        _loadGoals(),
        _loadTodayLogs(),
        _loadHealthData(),
        _loadInsights(),
      ]);
    } catch (e) {
      _handleError('loadDashboard', e);
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Goals ───────────────────────────────────────────────────────────────────
  Future<void> _loadGoals() async {
    try {
      final data = await _client
          .from('user_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final g = data != null
          ? UserGoals.fromMap(data)
          : UserGoals.defaults(userId);

      goals.value      = g;
      calorieGoal.value = g.calorieGoal;
      proteinGoal.value = g.proteinGoal;
      carbsGoal.value   = g.carbsGoal;
      fatGoal.value     = g.fatGoal;
      waterGoal.value   = g.waterGoal;
    } catch (e) {
      final g = UserGoals.defaults(userId);
      goals.value       = g;
      calorieGoal.value = g.calorieGoal;
      proteinGoal.value = g.proteinGoal;
      carbsGoal.value   = g.carbsGoal;
      fatGoal.value     = g.fatGoal;
      waterGoal.value   = g.waterGoal;
    }
  }

  Future<void> saveGoals(UserGoals newGoals) async {
    isSaving.value = true;
    try {
      await _client.from('user_goals').upsert(
        newGoals.toMap(),
        onConflict: 'user_id',
      );
      goals.value       = newGoals;
      calorieGoal.value = newGoals.calorieGoal;
      proteinGoal.value = newGoals.proteinGoal;
      carbsGoal.value   = newGoals.carbsGoal;
      fatGoal.value     = newGoals.fatGoal;
      waterGoal.value   = newGoals.waterGoal;
    } catch (e) {
      _handleError('saveGoals', e);
    } finally {
      isSaving.value = false;
    }
  }

  // ─── Today's Logs ────────────────────────────────────────────────────────────
  Future<void> _loadTodayLogs() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _client
          .from('nutrition_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: false);

      final logs = (data as List).map((e) => NutritionLog.fromMap(e)).toList();
      todayLogs.value = logs;
      _recalcTotals(logs);
    } catch (e) {
      // Use mock data for development when DB isn't set up yet
      _useMockNutritionData();
    }
  }

  void _recalcTotals(List<NutritionLog> logs) {
    totalCalories.value = logs.fold(0, (sum, l) => sum + l.calories);
    totalProtein.value = logs.fold(0, (sum, l) => sum + l.protein);
    totalCarbs.value = logs.fold(0, (sum, l) => sum + l.carbs);
    totalFat.value = logs.fold(0, (sum, l) => sum + l.fat);
  }

  void _useMockNutritionData() {
    totalCalories.value = 1450;
    totalProtein.value = 98;
    totalCarbs.value = 165;
    totalFat.value = 52;
  }

  Future<void> logMeal({
    required String mealType,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double servingSize = 100,
    String? barcode,
  }) async {
    isSaving.value = true;
    try {
      final log = NutritionLog(
        id: '',
        userId: userId,
        mealType: mealType,
        foodName: foodName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        servingSize: servingSize,
        barcode: barcode,
        loggedAt: DateTime.now(),
      );

      await _client.from('nutrition_logs').insert(log.toMap());
      await _loadTodayLogs(); // Refresh
      Get.snackbar('✅ Logged', '$foodName added to $mealType.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      _handleError('logMeal', e);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      todayLogs.removeWhere((l) => l.id == logId);
      _recalcTotals(todayLogs);
    } catch (e) {
      _handleError('deleteLog', e);
    }
  }

  // ─── Health Data ─────────────────────────────────────────────────────────────
  Future<void> _loadHealthData() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final data = await _client
          .from('health_data')
          .select()
          .eq('user_id', userId)
          .gte('recorded_at', startOfDay.toIso8601String())
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        healthData.value = DailyHealthData.fromMap(data);
        waterGlasses.value = healthData.value!.waterIntake;
      } else {
        healthData.value = DailyHealthData.empty(userId);
        waterGlasses.value = healthData.value!.waterIntake;
      }
    } catch (e) {
      healthData.value = DailyHealthData.empty(userId);
      waterGlasses.value = 5;
    }
  }

  Future<void> setWaterGlasses(int count) async {
    waterGlasses.value = count;
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      await _client.from('health_data').upsert({
        'user_id': userId,
        'water_intake': count,
        'steps': healthData.value?.steps ?? 0,
        'calories_burned': healthData.value?.caloriesBurned ?? 0,
        'recorded_at': startOfDay.toIso8601String(),
      });
    } catch (e) {
      // Silent fail — UI already updated optimistically
    }
  }

  // ─── Insights ────────────────────────────────────────────────────────────────
  Future<void> _loadInsights() async {
    try {
      final data = await _client
          .from('smart_insights')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(5);

      insights.value = (data as List).map((e) => NutritionInsight.fromMap(e)).toList();

      if (insights.isEmpty) {
        insights.value = NutritionInsight.mockInsights();
      }
    } catch (e) {
      insights.value = NutritionInsight.mockInsights();
    }
  }

  Future<void> markInsightRead(String insightId) async {
    insights.removeWhere((i) => i.id == insightId);
    try {
      await _client
          .from('smart_insights')
          .update({'is_read': true})
          .eq('id', insightId);
    } catch (_) {}
  }

  // ─── Weekly data for charts ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWeeklyCalories() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6));

      final data = await _client
          .from('nutrition_logs')
          .select('calories, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', startDate.toIso8601String())
          .lte('logged_at', endDate.toIso8601String())
          .order('logged_at', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── Error handler (same pattern as other controllers) ───────────────────────
  void _handleError(String context, dynamic e) {
    print('NutritionController.$context error: $e');
    Get.snackbar(
      '❌ Error',
      e.toString(),
      snackPosition: SnackPosition.TOP,
    );
  }
}