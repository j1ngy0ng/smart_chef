// screens/health/meal_history_screen.dart
// Shows all logged meals grouped by meal type for a selected date.
// Reads from nutrition_logs table in Supabase.
// Supports swipe-to-delete and date navigation.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/nutrition_model.dart';
import '../../controllers/nutrition_controller.dart';
import '../../theme/colors.dart';
import 'dart:convert';
import '../../services/local_db_service.dart';

typedef _C = C;

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen>
    with SingleTickerProviderStateMixin {
  String? _editingLogId;
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _servingControllers = {};
  final SupabaseClient _client = Supabase.instance.client;
  late AnimationController _fadeAnim;

  DateTime _selectedDate = DateTime.now();
  List<NutritionLog> _logs = [];
  bool _isLoading = false;

  // Meal type config
  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealEmojis = {
    'breakfast': '🌅',
    'lunch': '☀️',
    'dinner': '🌙',
    'snack': '🍎',
  };
  static const _mealColors = {
    'breakfast': Color(0xFFFF9800),
    'lunch': Color(0xFF00A676),
    'dinner': Color(0xFF3B82F6),
    'snack': Color(0xFFEC4899),
  };

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadLogs();
  }

  @override
  void dispose() {
    _fadeAnim.dispose();
    super.dispose();
  }

  String get _userId => _client.auth.currentUser?.id ?? '';

  Future<void> _loadLogs() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);
    _fadeAnim.reset();

    try {
      // ── Try Supabase first ──
      final startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _client
          .from('nutrition_logs')
          .select()
          .eq('user_id', _userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: true);

      final logs =
      (data as List).map((e) => NutritionLog.fromMap(e)).toList();

      for (final log in logs) {
        print('=== LOG: ${log.foodName} | path: ${log.imagePath} | url: ${log.imageUrl} ===');
      }

      // Save fresh data to local cache
      await _saveCacheLocally(logs);

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
      _fadeAnim.forward();
    } catch (e) {
      // ── Supabase failed — load from local cache ──
      print('=== OFFLINE: loading from cache ===');
      final cached = await _loadCacheLocally();

      setState(() {
        _logs = cached;
        _isLoading = false;
      });
      _fadeAnim.forward();

      // Show offline banner only if we got cached data
      if (cached.isNotEmpty) {
        Get.snackbar(
          '📵 Offline Mode',
          'Showing cached data. Connect to sync.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade400,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '📵 No Connection',
          'No cached data available for this date.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade400,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _updateLog(NutritionLog log, String newName, double newServing) async {
    try {
      // Recalculate nutrition based on new serving
      final ratio = newServing / log.servingSize;
      await _client.from('nutrition_logs').update({
        'food_name': newName,
        'serving_size': newServing,
        'calories': log.calories * ratio,
        'protein': log.protein * ratio,
        'carbs': log.carbs * ratio,
        'fat': log.fat * ratio,
      }).eq('id', log.id);

      Get.snackbar('✅ Updated', '$newName updated.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: _C.primary,
          colorText: Colors.white);

      _editingLogId = null;
      _loadLogs(); // Refresh

      if (Get.isRegistered<NutritionController>()) {
        Get.find<NutritionController>().loadDashboard();
      }
    } catch (e) {
      Get.snackbar('❌ Error', 'Update failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  Future<void> _deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      setState(() => _logs.removeWhere((l) => l.id == logId));

      // Refresh dashboard if open
      if (Get.isRegistered<NutritionController>()) {
        Get.find<NutritionController>().loadDashboard();
      }

      Get.snackbar('🗑️ Deleted', 'Food item removed.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade400,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar('❌ Error', 'Delete failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate =
        _selectedDate.subtract(const Duration(days: 1)));
    _loadLogs();
  }

  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(
              () => _selectedDate = _selectedDate.add(const Duration(days: 1)));
      _loadLogs();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _C.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadLogs();
    }
  }

  // ── Computed totals ──────────────────────────────────────────────────────────
  double get _totalCalories => _logs.fold(0, (s, l) => s + l.calories);
  double get _totalProtein => _logs.fold(0, (s, l) => s + l.protein);
  double get _totalCarbs => _logs.fold(0, (s, l) => s + l.carbs);
  double get _totalFat => _logs.fold(0, (s, l) => s + l.fat);

  Map<String, List<NutritionLog>> get _groupedLogs {
    final map = <String, List<NutritionLog>>{};
    for (final type in _mealOrder) {
      final items = _logs.where((l) => l.mealType == type).toList();
      if (items.isNotEmpty) map[type] = items;
    }
    return map;
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) return 'Yesterday';
    return '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildDateNavigator(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                        child: CircularProgressIndicator(color: _C.primary)),
                  )
                else if (_logs.isEmpty)
                  _buildEmptyState()
                else ...[
                    _buildDaySummaryCard(),
                    const SizedBox(height: 20),
                    ..._groupedLogs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildMealSection(entry.key, entry.value),
                    )),
                  ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: _C.text1, size: 20),
        ),
      ),
      title: const Text(
        'Meal History',
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.text1,
            letterSpacing: -0.3),
      ),
      actions: [
        GestureDetector(
          onTap: _loadLogs,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_C.primary, Color(0xFF007A57)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _C.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // ── Date Navigator ───────────────────────────────────────────────────────────
  Widget _buildDateNavigator() {
    final canGoForward = !_isToday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          // Previous day
          _navBtn(
              icon: Icons.chevron_left_rounded,
              onTap: _goToPreviousDay),
          // Date label (tappable)
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                children: [
                  Text(
                    _dateLabel,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.text1),
                  ),
                  if (!_isToday)
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 11, color: _C.text3),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: _C.primary),
                      const SizedBox(width: 4),
                      Text('Tap to pick date',
                          style: TextStyle(
                              fontSize: 10,
                              color: _C.primary.withOpacity(0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Next day
          _navBtn(
            icon: Icons.chevron_right_rounded,
            onTap: canGoForward ? _goToNextDay : null,
            disabled: !canGoForward,
          ),
        ],
      ),
    );
  }

  Widget _navBtn(
      {required IconData icon,
        required VoidCallback? onTap,
        bool disabled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : _C.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: disabled ? _C.text3 : _C.primary, size: 22),
      ),
    );
  }

  // ── Day Summary Card ─────────────────────────────────────────────────────────
  Widget _buildDaySummaryCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007A57), Color(0xFF00A676)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: _C.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Total',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_logs.length} item${_logs.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_totalCalories.toInt()} kcal',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _summaryMacro('Protein', _totalProtein, _C.protein),
                _summaryMacro('Carbs', _totalCarbs, _C.carbs),
                _summaryMacro('Fat', _totalFat, _C.fat),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMacro(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${value.toInt()}g',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ],
      ).paddingSymmetric(horizontal: 4),
    );
  }

  // ── Meal Section ─────────────────────────────────────────────────────────────
  Widget _buildMealSection(String mealType, List<NutritionLog> logs) {
    final color = _mealColors[mealType] ?? _C.primary;
    final emoji = _mealEmojis[mealType] ?? '🍽️';
    final totalCal = logs.fold(0.0, (s, l) => s + l.calories);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11)),
                    child:
                    Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.capitalizeFirst ?? mealType,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.text1),
                      ),
                      Text(
                        '${logs.length} item${logs.length == 1 ? '' : 's'}',
                        style:
                        const TextStyle(fontSize: 11, color: _C.text3),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${totalCal.toInt()} kcal',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            // Food items
            ...logs.map((log) => _buildFoodItem(log, color)),
          ],
        ),
      ),
    );
  }

  // ── Food Item Row ────────────────────────────────────────────────────────────
  Widget _buildFoodItem(NutritionLog log, Color mealColor) {
    final isEditing = _editingLogId == log.id;

    // Init controllers if needed
    _nameControllers.putIfAbsent(log.id, () => TextEditingController(text: log.foodName));
    _servingControllers.putIfAbsent(log.id, () => TextEditingController(text: log.servingSize.toInt().toString()));

    return Dismissible(
      key: Key('${log.id}_${log.foodName}_${log.loggedAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return await _showDeleteConfirm(log.foodName);
      },
      onDismissed: (_) => _deleteLog(log.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(color: Color(0xFFFFEBEE)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          ],
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          border: isEditing
              ? Border(top: BorderSide(color: _C.primary.withOpacity(0.15)))
              : const Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImageDialog(log),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: mealColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge, // ← ADD THIS so image respects border radius
                      child: () {
                        final hasLocalImage = log.imagePath != null && File(log.imagePath!).existsSync();
                        final hasRemoteImage = log.imageUrl != null && log.imageUrl!.isNotEmpty;
                        return hasLocalImage
                            ? Image.file(File(log.imagePath!), fit: BoxFit.cover)
                            : hasRemoteImage
                            ? Image.network(
                          log.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Icon(
                            Icons.restaurant_rounded,
                            color: mealColor.withOpacity(0.7),
                            size: 20,
                          ),
                        )
                            : Icon(
                          Icons.restaurant_rounded,
                          color: mealColor.withOpacity(0.7),
                          size: 20,
                        );
                      }(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.foodName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: _C.text1),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${log.servingSize.toInt()}g  ·  P: ${log.protein.toInt()}g  C: ${log.carbs.toInt()}g  F: ${log.fat.toInt()}g',
                          style: const TextStyle(fontSize: 11, color: _C.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${log.calories.toInt()}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _C.text1)),
                      const Text('kcal', style: TextStyle(fontSize: 10, color: _C.text3)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Edit toggle button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _editingLogId = isEditing ? null : log.id;
                        // Reset controllers to current values
                        _nameControllers[log.id]?.text = log.foodName;
                        _servingControllers[log.id]?.text = log.servingSize.toInt().toString();
                      });
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isEditing
                            ? _C.primary.withOpacity(0.15)
                            : _C.bg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        isEditing ? Icons.close_rounded : Icons.edit_rounded,
                        color: isEditing ? _C.primary : _C.text3,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Inline edit panel ──
            if (isEditing)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.primary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food name field
                    const Text('Food name',
                        style: TextStyle(fontSize: 12, color: _C.text2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameControllers[log.id],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.text1),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _C.primary.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Serving size field
                    const Text('Serving size (g)',
                        style: TextStyle(fontSize: 12, color: _C.text2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Minus button
                        GestureDetector(
                          onTap: () {
                            final current = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                            final newVal = (current - 25).clamp(25.0, 9999.0);
                            _servingControllers[log.id]!.text = newVal.toInt().toString();
                          },
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _C.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.remove_rounded, color: _C.primary, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _servingControllers[log.id],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.text1),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                              suffix: const Text('g', style: TextStyle(color: _C.text3)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _C.primary.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _C.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Plus button
                        GestureDetector(
                          onTap: () {
                            final current = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                            _servingControllers[log.id]!.text = (current + 25).toInt().toString();
                          },
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _C.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_rounded, color: _C.primary, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick presets
                    Row(
                      children: [50, 100, 150, 200, 250].map((g) =>
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: GestureDetector(
                                onTap: () => _servingControllers[log.id]!.text = g.toString(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (double.tryParse(_servingControllers[log.id]!.text) ?? 0).toInt() == g
                                        ? _C.primary : _C.bg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${g}g',
                                      style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w700,
                                        color: (double.tryParse(_servingControllers[log.id]!.text) ?? 0).toInt() == g
                                            ? Colors.white : _C.text2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Save button
                    GestureDetector(
                      onTap: () {
                        final newName = _nameControllers[log.id]!.text.trim();
                        final newServing = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                        if (newName.isEmpty) {
                          Get.snackbar('⚠️ Empty', 'Food name cannot be empty.',
                              snackPosition: SnackPosition.TOP);
                          return;
                        }
                        _updateLog(log, newName, newServing);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_C.primary, Color(0xFF007A57)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: _C.primary.withOpacity(0.35),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Save Changes',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: _C.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            _isToday ? 'No meals logged today' : 'No meals on this day',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _C.text1),
          ),
          const SizedBox(height: 8),
          Text(
            _isToday
                ? 'Tap "Add Meal" on the dashboard\nto log your first meal'
                : 'Nothing was logged on this date',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: _C.text2, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Delete Confirm Dialog ────────────────────────────────────────────────────
  Future<bool> _showDeleteConfirm(String foodName) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Remove "$foodName" from your log?',
            style: const TextStyle(color: _C.text2)),
        actions: [
          TextButton(
            //onTap: () => Navigator.pop(ctx, false),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showImageDialog(NutritionLog log) {
    final hasLocalImage = log.imagePath != null && File(log.imagePath!).existsSync();
    final hasRemoteImage = log.imageUrl != null && log.imageUrl!.isNotEmpty;
    final hasImage = hasLocalImage || hasRemoteImage;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image or placeholder
              hasLocalImage
                  ? Image.file(
                File(log.imagePath!),
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
              )
                  : hasRemoteImage
                  ? Image.network(
                log.imageUrl!,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: _C.primary)),
                errorBuilder: (ctx, _, __) => _noImagePlaceholder(),
              )
                  : _noImagePlaceholder(),

              // Food info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.foodName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _C.text1)),
                    const SizedBox(height: 4),
                    Text(
                      '${log.servingSize.toInt()}g  ·  ${log.calories.toInt()} kcal',
                      style: const TextStyle(
                          fontSize: 13, color: _C.text2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _dialogMacro('Protein', '${log.protein.toInt()}g', _C.protein),
                        _dialogMacro('Carbs', '${log.carbs.toInt()}g', _C.carbs),
                        _dialogMacro('Fat', '${log.fat.toInt()}g', _C.fat),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _C.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Close',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogMacro(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _C.text3)),
          ],
        ),
      ),
    );
  }

  final _localDb = LocalDbService();

  Future<void> _saveCacheLocally(List<NutritionLog> logs) async {
    await _localDb.cacheNutritionLogs(logs);
  }

  Future<List<NutritionLog>> _loadCacheLocally() async {
    return await _localDb.getNutritionLogsForDate(_userId, _selectedDate);
  }

  Widget _noImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(color: _C.bg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_rounded, color: _C.text3, size: 48),
          const SizedBox(height: 12),
          const Text('No image captured',
              style: TextStyle(color: _C.text3, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}