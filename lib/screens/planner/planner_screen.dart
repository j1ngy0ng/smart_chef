import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../controllers/planner_controller.dart';
import '../../controllers/post_controller.dart';
import '../../models/meal_model.dart';
import 'meal_detail_screen.dart';

class SmartPlannerScreen extends GetView<PlannerController> {
  const SmartPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlannerController());
    final PostController postController = Get.find<PostController>();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptionSheet(context, controller, postController),
        backgroundColor: const Color(0xFF00A676),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 50),
                _buildHeader(controller),
                _buildCalendar(controller),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.plannedMeals.isEmpty) {
                      return const Center(child: Text("No meals planned for today"));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 100),
                      itemCount: controller.plannedMeals.length,
                      itemBuilder: (context, index) {
                        return _buildMealCard(controller.plannedMeals[index], controller);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),

          // Updated Pill to trigger the SETUP SHEET
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildSmartGenerationPill(context, controller),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildHeader(PlannerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 30),
            onPressed: () => controller.updateSelectedDay(
              controller.selectedDay.value.subtract(const Duration(days: 7)),
              controller.focusedDay.value.subtract(const Duration(days: 7)),
            ),
          ),
          Obx(() => Text(
            DateFormat('MMMM yyyy').format(controller.focusedDay.value),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          )),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 30),
            onPressed: () => controller.updateSelectedDay(
              controller.selectedDay.value.add(const Duration(days: 7)),
              controller.focusedDay.value.add(const Duration(days: 7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(PlannerController controller) {
    return Obx(() => TableCalendar(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: controller.focusedDay.value,
      headerVisible: false,
      calendarFormat: CalendarFormat.week,
      selectedDayPredicate: (day) => isSameDay(controller.selectedDay.value, day),
      onDaySelected: controller.updateSelectedDay,
      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(color: Color(0xFF00A676), shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Color(0x8000A676), shape: BoxShape.circle),
      ),
    ));
  }

  Widget _buildSmartGenerationPill(BuildContext context, PlannerController controller) {
    return Obx(() => GestureDetector(
      // Trigger the new setup sheet instead of immediate generation
      onTap: controller.isLoading.value ? null : () => _showSmartSetupSheet(context, controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00A676),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
                controller.isLoading.value ? "AI is Thinking..." : "Smart Generation",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
      ),
    ));
  }

  // --- NEW SMART SETUP SHEET ---

  void _showSmartSetupSheet(BuildContext context, PlannerController controller) {
    // Local state for the sheet
    var rangeStart = controller.selectedDay.value.obs;
    var rangeEnd = controller.selectedDay.value.obs;
    var selectedTypes = <String>['Breakfast', 'Lunch', 'Dinner'].obs;
    final cravingController = TextEditingController();

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("✨ Smart Generation Setup", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 1. Date Range Calendar
              Obx(() => TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: rangeStart.value,
                rangeSelectionMode: RangeSelectionMode.toggledOn,
                rangeStartDay: rangeStart.value,
                rangeEndDay: rangeEnd.value,
                onRangeSelected: (start, end, focused) {
                  if (start != null) rangeStart.value = start;
                  if (end != null) rangeEnd.value = end;
                },
                calendarStyle: const CalendarStyle(
                  rangeStartDecoration: BoxDecoration(color: Color(0xFF00A676), shape: BoxShape.circle),
                  rangeEndDecoration: BoxDecoration(color: Color(0xFF00A676), shape: BoxShape.circle),
                  rangeHighlightColor: Color(0x3300A676),
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              )),

              const SizedBox(height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text("Include Meals:", style: TextStyle(fontWeight: FontWeight.bold))),

              // 2. Meal Type Selection (Chips)
              Obx(() => Wrap(
                spacing: 10,
                children: ['Breakfast', 'Lunch', 'Dinner'].map((type) {
                  final isSelected = selectedTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00A676).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF00A676),
                    onSelected: (val) => val ? selectedTypes.add(type) : selectedTypes.remove(type),
                  );
                }).toList(),
              )),

              const SizedBox(height: 20),

              // 3. Cravings / Preference Field
              TextField(
                controller: cravingController,
                decoration: InputDecoration(
                  hintText: "Cravings? (e.g., Spicy, Italian, Low Carb)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  prefixIcon: const Icon(Icons.fastfood, color: Color(0xFF00A676)),
                ),
              ),

              const SizedBox(height: 30),

              // 4. Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A676),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  controller.generateSmartPlan(
                    start: rangeStart.value,
                    end: rangeEnd.value ?? rangeStart.value,
                    mealTypes: selectedTypes,
                    craving: cravingController.text,
                  );
                },
                child: const Text("GENERATE MY PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // --- MEAL CARD & DIALOGS ---

  Widget _buildMealCard(Meal meal, PlannerController controller) {
    return GestureDetector(
      onTap: () => Get.to(() => MealDetailScreen(meal: meal)),
      onLongPress: () => _showDeleteDialog(meal, controller),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                meal.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(height: 180, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.type.toUpperCase(), style: const TextStyle(color: Color(0xFF00A676), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(meal.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${meal.kcal} kcal", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Meal meal, PlannerController controller) {
    Get.defaultDialog(
      title: "Delete Meal?",
      middleText: "Remove ${meal.title} from your plan?",
      textConfirm: "Delete",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        controller.deleteMeal(meal.id!);
        Get.back();
      },
    );
  }

  void _showAddOptionSheet(BuildContext context, PlannerController controller, PostController postController) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Add to Plan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text("Pick from Community Favorites", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: Obx(() => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: postController.posts.length,
                itemBuilder: (context, index) {
                  final post = postController.posts[index];
                  return GestureDetector(
                    onTap: () {
                      controller.addFromPost(post);
                      Get.back();
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(post.imageUrl ?? "", height: 90, width: 130, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(color: Colors.grey[200], height: 90, width: 130)),
                          ),
                          const SizedBox(height: 5),
                          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              )),
            ),
          ],
        ),
      ),
    );
  }
}