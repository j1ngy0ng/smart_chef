import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/grocery_item.dart';
import '../../controllers/planner_controller.dart';

class GroceryListScreen extends StatelessWidget {
  final PlannerController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Grocery List")),
      body: Column(
        children: [
          // --- PIE CHART SECTION ---
          SizedBox(
            height: 250,
            child: Obx(() => PieChart(
              PieChartData(
                sections: controller.categoryTotals.entries.map((entry) {
                  return PieChartSectionData(
                    value: entry.value,
                    title: entry.key,
                    color: Colors.primaries[entry.key.hashCode % Colors.primaries.length],
                    radius: 60,
                  );
                }).toList(),
              ),
            )),
          ),

          // --- TOTAL DISPLAY ---
          Obx(() => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Total: RM${controller.totalGroceryPrice.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          )),

          // --- LIST VIEW ---
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: controller.groceryList.length,
              itemBuilder: (context, index) {
                final item = controller.groceryList[index];
                return ListTile(
                  title: Text(item.name),
                  // Display category and price with RM
                  subtitle: Text("${item.category} • RM${item.price.toStringAsFixed(2)}"),
                  onTap: () => _showEditDialog(context, item),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => controller.toggleGroceryItem(item),
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }

  // --- FULL EDIT DIALOG ---
  void _showEditDialog(BuildContext context, GroceryItem item) {
    final TextEditingController nameCtrl = TextEditingController(text: item.name);
    final TextEditingController priceCtrl = TextEditingController(text: item.price.toString());
    final RxString category = (item.category).obs;
    final List<String> categories = ["General", "Produce", "Dairy", "Protein", "Bakery", "Other"];

    Get.defaultDialog(
      title: "Edit Item",
      content: Column(
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price (RM)"), keyboardType: TextInputType.number),
          Obx(() => DropdownButtonFormField<String>(
            initialValue: category.value,
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => category.value = val!,
            decoration: const InputDecoration(labelText: "Category"),
          )),
        ],
      ),
      onConfirm: () {
        controller.editGroceryItem(
          oldName: item.name,
          newName: nameCtrl.text,
          newPrice: double.tryParse(priceCtrl.text) ?? 0.0,
          newCategory: category.value,
        );
        Get.back();
      },
    );
  }
}