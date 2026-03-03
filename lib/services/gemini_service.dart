import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String apiKey = "AIzaSyACFv2DxwHwYxVXo4wCT0ouVSku3mofgR8";
  static const String pixabayApiKey = "54874799-571b5c264e06fb47d926b6bb3";

  // 🔹 Detect ingredients from image
  static Future<List<String>> detectIngredients(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "Identify all food ingredients in this image. Return only a comma-separated list."},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      }),
    );

    // 🔹 ADD THIS LINE
    print("Gemini response raw: ${response.body}");



    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";
      return text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      throw Exception("Gemini Error: ${response.body}");
    }
  }


  // 🔹 Generate multiple recipes with images from Pixabay
  static Future<List<Map<String, String>>> generateRecipes(List<String> ingredients) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
    );

    // Strict JSON prompt to ensure parsable output
    final prompt = """
You are a cooking assistant. Generate 3 simple healthy recipes using these ingredients: ${ingredients.join(", ")}.
Return output as a JSON object with a single key "recipes", which is an array of 3 recipes.
Each recipe must have the following fields:
- title
- ingredients (comma-separated)
- steps (numbered instructions)
Do NOT include any extra text or commentary outside the JSON.
Example output:
{
  "recipes": [
    {
      "title": "Grilled Chicken Salad",
      "ingredients": "chicken, lettuce, tomato",
      "steps": "1. Cook chicken. 2. Chop vegetables. 3. Mix together."
    }
  ]
}
""";

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {"parts": [{"text": prompt}]}
        ]
      }),
    );

    // 🔹 ADD THIS LINE
    print("Gemini response raw: ${response.body}");

    if (response.statusCode != 200) {
      print("STATUS CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");
      return [];
    }

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";

    try {
      // 🔹 Strip any Markdown backticks
      String cleanedText = text.replaceAll(RegExp(r'```(json)?'), '').trim();

      // 🔹 Parse the cleaned JSON
      final Map<String, dynamic> parsed = jsonDecode(cleanedText);
      final List<dynamic> recipesList = parsed["recipes"] ?? [];

      List<Map<String, String>> recipes = [];

      for (var recipe in recipesList) {
        String title = recipe["title"] ?? "";
        String ingredientsText = recipe["ingredients"] ?? "";
        String steps = recipe["steps"] ?? "";

        String imageUrl = await fetchRecipeImagePixabay(title);

        recipes.add({
          "title": title,
          "ingredients": ingredientsText,
          "steps": steps,
          "image": imageUrl,
        });
      }

      return recipes;
    } catch (e) {
      print("Failed to parse Gemini JSON: $e");
      print("Gemini response: $text");
      return [];
    }
  }

  // 🔹 Fetch a recipe image from Pixabay
  static Future<String> fetchRecipeImagePixabay(String query) async {
    try {
      final url = Uri.parse(
        "https://pixabay.com/api/?key=$pixabayApiKey&q=${Uri.encodeComponent(query)}&image_type=photo&per_page=3",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data["hits"] as List<dynamic>?;

        if (hits != null && hits.isNotEmpty) {
          return hits[0]["webformatURL"] ?? "";
        } else {
          return ""; // No image found
        }
      } else {
        print("Pixabay API error: ${response.statusCode}");
        return "";
      }
    } catch (e) {
      print("Error fetching Pixabay image: $e");
      return "";
    }
  }
}