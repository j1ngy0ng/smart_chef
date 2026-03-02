import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/meal_model.dart';
import '../../controllers/planner_controller.dart';

class MealDetailScreen extends StatelessWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlannerController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        // Find the latest meal in the controller so UI updates when you change the photo
        final currentMeal = controller.plannedMeals.firstWhere(
              (m) => m.id == meal.id,
          orElse: () => meal,
        );

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
                background: Stack(
                  fit: StackFit.expand, // Forces children to fill the entire header
                  children: [
                    // 1. THE IMAGE AREA
                    Image.network(
                      currentMeal.imageUrl,
                      fit: BoxFit.cover,
                      // THIS BOX FIX: Ensures the placeholder fills the 250px height
                      errorBuilder: (context, error, stackTrace) => _buildFullPlaceholder(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildFullPlaceholder(); // While loading
                      },
                    ),

                    // 2. THE EDIT BUTTON
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        heroTag: "edit_btn_${currentMeal.id}",
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: const Icon(Icons.edit_outlined, color: Color(0xFF00A676)),
                        onPressed: () => _showImageSourceDialog(context, controller, currentMeal),
                      ),
                    ),
                  ],
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

                    if (currentMeal.isSocialPost) _buildResolveBanner(context, currentMeal, controller),

                    const Divider(height: 40),

                    if (currentMeal.isSocialPost) ...[
                      const Text("Community Story", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(currentMeal.steps, style: const TextStyle(fontSize: 16, height: 1.5)),
                    ] else ...[
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

  // --- THE "FIXED SIZE" PLACEHOLDER ---
  Widget _buildFullPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250, // Matches expandedHeight
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF00A676).withValues(alpha: 0.2), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 50, color: const Color(0xFF00A676).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            "NO PHOTO FOUND",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00A676).withValues(alpha: 0.5),
                letterSpacing: 1.5
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS (Banners, Items, Dialogs) ---

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
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text("Want to organize this into a recipe?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
              onPressed: controller.isLoading.value ? null : () => controller.resolveRecipe(meal),
              child: controller.isLoading.value
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("AUTO-ORGANIZE"),
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

  void _showImageSourceDialog(BuildContext context, PlannerController controller, Meal meal) {
    final TextEditingController searchController = TextEditingController(text: meal.title);

    Get.defaultDialog(
      title: "Change Photo",
      content: TextField(
        controller: searchController,
        decoration: const InputDecoration(labelText: "Search keyword..."),
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A676)),
        onPressed: () async {
          Get.back();
          String newUrl = await controller.fetchMealImage(searchController.text, 0);
          final updatedMeal = meal.copyWith(imageUrl: newUrl);
          await controller.updateMeal(updatedMeal);
          Get.snackbar("Success", "Photo updated!");
        },
        child: const Text("Update", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}