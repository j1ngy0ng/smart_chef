import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/local_db_service.dart';
import 'recipe_result.dart';
import '../../services/supabase_service.dart';

const Color kPrimaryGreen = Color(0xFF4CAF50);
const Color kBgColor = Color(0xFFF9FBF9);

class FavoriteRecipesPage extends StatefulWidget {
  const FavoriteRecipesPage({Key? key}) : super(key: key);

  @override
  State<FavoriteRecipesPage> createState() => _FavoriteRecipesPageState();
}

class _FavoriteRecipesPageState extends State<FavoriteRecipesPage> {

  final SupabaseService supabaseService = SupabaseService();


  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: kBgColor,

      appBar: AppBar(
        title: Text(
          "Favorite Recipes ❤️",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseService.favoritesStream(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No favorites yet"));
          }

          final favorites = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {

              final recipe = favorites[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(

                  leading: recipe["image"] != null
                      ? Image.network(
                    recipe["image"],
                    width: 60,
                    fit: BoxFit.cover,
                  )
                      : const Icon(Icons.restaurant),

                  title: Text(recipe["title"] ?? "Unknown Recipe"),

                  subtitle: Text(
                    "${recipe["kcal"] ?? "--"} kcal • ${recipe["duration"] ?? "--"}",
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailPage(
                          recipe: Map<String, String>.from(recipe),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}