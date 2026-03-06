import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_chef/models/waste_recipe_model.dart';

class RecipeService {
  static const String apiKey = "fc36808696c7405e89a45aad686b2cdc";

  static Future<List<Recipe>> fetchRecipes(int number) async {
    final url = Uri.parse(
      "https://api.spoonacular.com/recipes/random?number=$number&addRecipeNutrition=true&apiKey=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List recipesJson = data['recipes'];

      return recipesJson.map((e) => Recipe.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load recipes");
    }
  }
}