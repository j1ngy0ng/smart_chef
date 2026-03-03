import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/services/gemini_service.dart';

enum IngredientMode { manual, scan }

class FoodWastePage extends StatefulWidget {
  final IngredientMode? mode; // optional, can be null
  const FoodWastePage({Key? key, this.mode}) : super(key: key);

  @override
  _FoodWastePageState createState() => _FoodWastePageState();
}

class _FoodWastePageState extends State<FoodWastePage> {
  List<String> leftoverIngredients = [];
  File? imageFile;
  bool isProcessing = false;
  final picker = ImagePicker();
  final TextEditingController ingredientController = TextEditingController();

  // Step 1: Pick image from camera
  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        isProcessing = true;
      });

      // Step 2: Send image to AI
      await detectIngredients(File(pickedFile.path));
    }
  }

  // Step 2: Detect ingredients
  Future<void> detectIngredients(File image) async {
    try {
      final detected = await GeminiService.detectIngredients(image);

      setState(() {
        leftoverIngredients.addAll(detected);
      });
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  // Step 3: Add ingredient manually
  void addIngredient(String ingredient) {
    if (ingredient.trim().isEmpty) return;
    setState(() {
      leftoverIngredients.add(ingredient.trim());
      ingredientController.clear();
    });
  }

  // Step 4: Remove ingredient
  void removeIngredient(String ingredient) {
    setState(() {
      leftoverIngredients.remove(ingredient);
    });
  }

  // Step 5: Generate multiple recipes
  void generateRecipes() async {
    setState(() => isProcessing = true);

    try {
      final recipes = await GeminiService.generateRecipes(leftoverIngredients);
      if (recipes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No recipes generated")),
        );
      } else {
        showRecipeMenu(recipes);
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Error"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            )
          ],
        ),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  // Display recipes in a scrollable menu
  void showRecipeMenu(List<Map<String, String>> recipes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ListView.builder(
              controller: controller,
              itemCount: recipes.length,
              itemBuilder: (_, index) {
                final recipe = recipes[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: recipe["image"] != null
                        ? Image.network(recipe["image"]!,
                        width: 60, height: 60, fit: BoxFit.cover)
                        : Icon(Icons.restaurant_menu, size: 40),
                    title: Text(recipe["title"] ?? "No Title"),
                    subtitle: Text(recipe["ingredients"] ?? ""),
                    onTap: () {
                      // Show full recipe
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(recipe["title"] ?? ""),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (recipe["image"] != null)
                                  Image.network(recipe["image"]!),
                                SizedBox(height: 10),
                                Text("Ingredients:\n${recipe["ingredients"] ?? ""}"),
                                SizedBox(height: 10),
                                Text("Steps:\n${recipe["steps"] ?? ""}"),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Close"),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Step 0: Choose method (add or scan)
  void chooseInputMethod() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Select Input Method"),
        content: Text("Would you like to add ingredients manually or scan leftovers?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Manual input: nothing extra to do, main UI shows text field
            },
            child: Text("Add Ingredients"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              pickImage();
            },
            child: Text("Scan Ingredients"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Waste Manager'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: chooseInputMethod,
              child: Text("Start Adding Ingredients"),
            ),

            SizedBox(height: 16),

            // Ingredient input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ingredientController,
                    decoration: InputDecoration(
                      hintText: 'Enter ingredient manually',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => addIngredient(ingredientController.text),
                  child: Text('Add'),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Display ingredient chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leftoverIngredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  deleteIcon: Icon(Icons.close),
                  onDeleted: () => removeIngredient(ingredient),
                );
              }).toList(),
            ),

            SizedBox(height: 20),

            // Display picked image
            if (imageFile != null)
              Image.file(imageFile!, height: 200),

            if (isProcessing) CircularProgressIndicator(),

            Spacer(),

            // Generate recipe button
            ElevatedButton(
              onPressed: leftoverIngredients.isNotEmpty ? generateRecipes : null,
              child: Text('Generate Recipes'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}