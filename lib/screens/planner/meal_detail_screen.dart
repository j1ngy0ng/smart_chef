import 'package:flutter/material.dart';
import '../../models/meal_model.dart';

class MealDetailScreen extends StatelessWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    // Split the strings back into lists
    List<String> ingredientList = meal.ingredients.split(',');
    List<String> stepList = meal.steps.split('\n');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(meal.imageUrl, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.type.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF00A676), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(meal.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text("${meal.kcal} Calories", style: TextStyle(color: Colors.grey[600], fontSize: 16)),

                  const Divider(height: 40),

                  const Text("Ingredients", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...ingredientList.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF00A676), size: 18),
                        const SizedBox(width: 10),
                        Text(item.trim(), style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  )),

                  const SizedBox(height: 30),

                  const Text("Cooking Steps", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...stepList.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF00A676),
                          child: Text("${entry.key + 1}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value.trim(), style: const TextStyle(fontSize: 16, height: 1.5))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}