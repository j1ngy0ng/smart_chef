import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String apiKey = "AIzaSyB6KnlaPVuiS27R4OtNF8nM3gru82CKIng";
  static const String pixabayApiKey = "54874799-571b5c264e06fb47d926b6bb3";

  static const String _nutritionApiKey = 'AIzaSyC95VmA7tfXrMtqgvomfSYPFZD9jOUrxkI';

  // 🔹 Detect ingredients from image (Kept exactly as your working version)
  static Future<List<String>> detectIngredients(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "Identify all food ingredients in this image. Return only a comma-separated list."},
              {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";
      return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      throw Exception("Gemini Error: ${response.body}");
    }
  }

  // 🔹 Generate Recipes (Updated specifically for kcal/duration)
  static Future<List<Map<String, String>>> generateRecipes(List<String> ingredients, {int targetCount = 6}) async {
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    // 🟢 Step 1: Specific prompt for kcal and duration
    final prompt = """
        You are a creative AI chef. Using: ${ingredients.join(", ")}, invent $targetCount unique recipes. 
        For each recipe, provide:
        - title: Name of recipe
        - kcal: Estimated calories (e.g. "320 kcal")
        - duration: Total time (e.g. "25 mins")
        - ingredients: Bullet points (e.g. "- ingredient 1\\n- ingredient 2")
        - steps: Numbered list (e.g. "1. Step one.\\n2. Step two.")
        
        Return strictly in this JSON format:
        {
          "recipes": [
            {
              "title": "Recipe Name",
              "kcal": "400 kcal",
              "duration": "30 mins",
              "ingredients": "- item 1\\n- item 2",
              "steps": "1. Step 1\\n2. Step 2"
            }
          ]
        }
        """;

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";

    try {
      final cleanedText = text.replaceAll(RegExp(r'```(json)?'), '').trim();
      final parsed = jsonDecode(cleanedText) as Map<String, dynamic>;
      final List<dynamic> recipesList = parsed["recipes"] ?? [];

      List<Map<String, String>> recipes = [];

      for (var recipe in recipesList) {
        if (recipes.length >= targetCount) break;

        final title = recipe["title"] ?? "";
        final imageUrl = await fetchRecipeImagePixabay(title);

        // ✅ Only include if image exists (kept your logic)
        if (imageUrl.isNotEmpty) {
          recipes.add({
            "title": title,
            "kcal": recipe["kcal"] ?? "---",
            "duration": recipe["duration"] ?? "---",
            "ingredients": recipe["ingredients"] ?? "",
            "steps": recipe["steps"] ?? "",
            "image": imageUrl,
          });
        }
      }

      // 🟢 Step 2: Recursive call (kept your logic)
      if (recipes.length < targetCount) {
        final more = await generateRecipes(ingredients, targetCount: targetCount - recipes.length);
        recipes.addAll(more);
      }

      return recipes;
    } catch (e) {
      print("Failed to parse: $e");
      return [];
    }
  }

  // 🔹 Fetch Image (Kept exactly as your working version)
  static Future<String> fetchRecipeImagePixabay(String query) async {
    try {
      final url = Uri.parse(
        "https://pixabay.com/api/?key=$pixabayApiKey&q=${Uri.encodeComponent(query)}&image_type=photo&per_page=3",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data["hits"] as List<dynamic>?;
        return (hits != null && hits.isNotEmpty) ? hits[0]["webformatURL"] : "";
      }
      return "";
    } catch (e) {
      return "";
    }
  }
  static Future<Map<String, dynamic>?> analyzeFoodImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_nutritionApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                },
                {
                  'text': '''You are a nutrition expert. Look at this food image carefully.
1. First check if this image actually contains food
2. If NO food is visible or image is unclear, return this exact JSON:
   {"error": "not_food"} or {"error": "unclear"}
3. If food IS visible:
   - Identify the exact food name and brand if visible
   - Search for accurate nutrition information online
   - Estimate the portion size in grams based on what you see
Respond ONLY in valid JSON with exactly these keys for food:
{
  "food_name": "",
  "estimated_grams": 0,
  "calories_per_serving": 0,
  "protein_per_serving": 0,
  "carbs_per_serving": 0,
  "fat_per_serving": 0
}
Or for errors:
{"error": "not_food"} or {"error": "unclear"}
No extra text, no markdown, just the JSON.'''
                }
              ]
            }
          ],
          'tools': [
            {'google_search': {}}
          ],
        }),
      );

      print('=== GEMINI STATUS: ${response.statusCode} ===');
      print('=== GEMINI BODY: ${response.body} ===');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'] as String;

        print('=== GEMINI TEXT: $text ===');

        final jsonMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
        if (jsonMatch == null) {
          print('=== NO JSON FOUND ===');
          return null;
        }

        final clean = jsonMatch.group(0)!;
        print('=== EXTRACTED JSON: $clean ===');

        return Map<String, dynamic>.from(jsonDecode(clean));
      } else {
        print('=== GEMINI HTTP ERROR: ${response.body} ===');
        return null;
      }
    } catch (e) {
      print('=== GEMINI ERROR: $e ===');
      return null;
    }
  }
}