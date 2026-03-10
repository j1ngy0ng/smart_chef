import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'waste_screen.dart';
import 'favorite_recipes_page.dart';
import '../waste/favorite_recipes_page.dart';

// --- Design System Constants ---
const Color kPrimaryGreen = Color(0xFF4CAF50);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kBgColor = Color(0xFFF9FBF9);

class IngredientChoicePage extends StatelessWidget {
  const IngredientChoicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Smart Chef',
          style: GoogleFonts.poppins(
            color: kPrimaryGreen,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FavoriteRecipesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "Reduce Waste,",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                "Cook Deliciously.",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryGreen,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "How would you like to add your leftovers today?",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Feature Cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildChoiceCard(
                      context,
                      title: "Smart Scan",
                      subtitle: "Take a photo of your fridge",
                      icon: Icons.camera_alt_rounded,
                      color: kPrimaryGreen,
                      mode: IngredientMode.scan,
                    ),
                    _buildChoiceCard(
                      context,
                      title: "Manual Entry",
                      subtitle: "Type in what you have left",
                      icon: Icons.edit_note_rounded,
                      color: Colors.blueGrey,
                      mode: IngredientMode.manual,
                    ),
                    _buildChoiceCard(
                      context,
                      title: "AI Creative Mode",
                      subtitle: "Surprise me with AI magic",
                      icon: Icons.auto_awesome_rounded,
                      color: kAccentOrange,
                      mode: IngredientMode.ai,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required IngredientMode mode,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FoodWastePage(mode: mode)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}