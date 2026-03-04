import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_chef/screens/waste/recipe_result.dart';
import 'package:smart_chef/services/waste_recipe_service.dart';
import '/services/gemini_service.dart';

enum IngredientMode { manual, scan, ai }

// --- Design System Constants ---
const Color kPrimaryGreen = Color(0xFF4CAF50);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kBgColor = Color(0xFFF9FBF9);
const double kRadius = 16.0;

class FoodWastePage extends StatefulWidget {
  final IngredientMode mode;
  const FoodWastePage({Key? key, required this.mode}) : super(key: key);

  @override
  _FoodWastePageState createState() => _FoodWastePageState();
}

class _FoodWastePageState extends State<FoodWastePage> {
  List<String> leftoverIngredients = [];
  File? imageFile;
  bool isProcessing = false;
  final picker = ImagePicker();
  final TextEditingController ingredientController = TextEditingController();

  // --- Logic Methods ---
  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        isProcessing = true;
      });
      await detectIngredients(File(pickedFile.path));
    }
  }

  Future<void> detectIngredients(File image) async {
    try {
      final detected = await GeminiService.detectIngredients(image);
      setState(() => leftoverIngredients.addAll(detected));
    } catch (e) {
      _showError("Failed to detect ingredients: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void addIngredient(String ingredient) {
    if (ingredient.trim().isEmpty) return;
    setState(() {
      leftoverIngredients.insert(0, ingredient.trim());
      ingredientController.clear();
    });
  }

  void removeIngredient(String ingredient) {
    setState(() => leftoverIngredients.remove(ingredient));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void generateRecipes() async {
    if (widget.mode != IngredientMode.ai && leftoverIngredients.isEmpty) {
      _showError("Please add ingredients first");
      return;
    }
    setState(() => isProcessing = true);
    try {
      List<Map<String, String>> recipes = [];

      if (widget.mode == IngredientMode.ai) {
        recipes = await GeminiService.generateRecipes(leftoverIngredients);
      } else {
        // 1. Fetch from Spoonacular
        final spoonacularRecipes = await RecipeService.fetchRecipes(6);

        // 2. 🟢 FIX: Map ALL fields, including kcal and duration
        recipes = spoonacularRecipes.map((r) => {
          "title": r.title,
          "ingredients": r.ingredients.join(", "),
          "steps": r.steps.join("\n"),
          "image": r.image,
          "kcal": r.kcal,
          "duration": r.duration,
        }).toList();
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeResultPage(
            initialRecipes: recipes,
            ingredients: leftoverIngredients,
          ),
        ),
      );
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  void dispose() {
    ingredientController.dispose();
    super.dispose();
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Food Waste Manager',
            style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildInputArea(),
                    const SizedBox(height: 24),
                    _buildIngredientGrid(),
                    if (imageFile != null) _buildImagePreview(),
                  ],
                ),
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = "Let's save food!";
    if (widget.mode == IngredientMode.scan) title = "Scan your fridge";
    if (widget.mode == IngredientMode.ai) title = "AI Recipe Assistant";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black)),
        const SizedBox(height: 4),
        Text("Tell us what you have left, we'll do the rest.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }

  Widget _buildInputArea() {
    bool isScan = widget.mode == IngredientMode.scan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: isScan && leftoverIngredients.isEmpty
          ? _buildScanButton()
          : _buildManualField(),
    );
  }

  Widget _buildScanButton() {
    return InkWell(
      onTap: pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          // The border already defaults to solid
          border: Border.all(
            color: kPrimaryGreen.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: kPrimaryGreen),
            const SizedBox(height: 12),
            Text(
              "Tap to scan ingredients",
              style: GoogleFonts.poppins( // Using Poppins here for consistency
                color: kPrimaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ingredientController,
            onSubmitted: (val) => addIngredient(val),
            decoration: InputDecoration(
              hintText: 'Add an ingredient...',
              filled: true,
              fillColor: kBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => addIngredient(ingredientController.text),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientGrid() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: leftoverIngredients.isEmpty
          ? const SizedBox.shrink()
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your Ingredients", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: leftoverIngredients.map((ingredient) => _buildChip(ingredient)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: Colors.white,
      elevation: 0,
      side: BorderSide(color: Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
      onDeleted: () => removeIngredient(label),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Image.file(imageFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProcessing)
            const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(color: kPrimaryGreen, backgroundColor: kBgColor)),
          ElevatedButton(
            onPressed: (isProcessing || (widget.mode != IngredientMode.ai && leftoverIngredients.isEmpty))
                ? null
                : generateRecipes,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
              elevation: 0,
            ),
            child: Text(
              widget.mode == IngredientMode.ai ? '✨ Generate AI Recipes' : 'Generate Recipes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}