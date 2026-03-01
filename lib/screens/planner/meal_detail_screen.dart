import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Import Get
import '../../models/meal_model.dart';
import '../../controllers/planner_controller.dart'; // Import Controller

class MealDetailScreen extends StatelessWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlannerController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        // Find the latest version of the meal in the controller
        final currentMeal = controller.plannedMeals.firstWhere(
              (m) => m.id == meal.id,
          orElse: () => meal,
        );

        // Logic for lists
        List<String> ingredientList = currentMeal.ingredients.contains('\n')
            ? currentMeal.ingredients.split('\n')
            : currentMeal.ingredients.split(',');

        List<String> stepList = currentMeal.steps.split('\n');

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: const Color(0xFF00A676),
              flexibleSpace: FlexibleSpaceBar(
                background: Image.network(
                  currentMeal.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentMeal.type.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF00A676), fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentMeal.title,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${currentMeal.kcal} Calories",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),

                    // --- NEW: AI RESOLVE BANNER ---
                    if (currentMeal.isSocialPost) _buildResolveBanner(context, currentMeal, controller),

                    const Divider(height: 40),

                    // --- CONDITIONAL UI: BLOG vs RECIPE ---
                    if (currentMeal.isSocialPost) ...[
                      const Text("Community Story", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        currentMeal.steps, // The raw content we saved
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ] else ...[
                      // Normal Recipe View (Ingredients + Steps)
                      const Text("Ingredients", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._buildIngredientItems(ingredientList),
                      const SizedBox(height: 30),
                      const Text("Cooking Steps", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._buildStepItems(stepList),
                    ],

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // --- UI HELPERS ---

  Widget _buildResolveBanner(BuildContext context, Meal meal, PlannerController controller) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text("This is a blog post. Want to extract a structured recipe?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white
              ),
              onPressed: controller.isLoading.value ? null : () => controller.resolveRecipe(meal),
              child: controller.isLoading.value
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("MAGIC FIX: AUTO-ORGANIZE"), // Much simpler name!
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientItems(List<String> list) {
    return list.where((i) => i.trim().isNotEmpty).map((item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00A676), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(item.trim(), style: const TextStyle(fontSize: 16))),
        ],
      ),
    )).toList();
  }

  List<Widget> _buildStepItems(List<String> list) {
    return list.where((s) => s.trim().isNotEmpty).toList().asMap().entries.map((entry) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFF00A676),
            child: Text("${entry.key + 1}", style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(entry.value.trim(), style: const TextStyle(fontSize: 16, height: 1.6))),
        ],
      ),
    )).toList();
  }
}