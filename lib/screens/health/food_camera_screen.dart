// screens/health/food_camera_screen.dart
// AI-powered food camera screen.
// Takes a photo, sends to Gemini Vision, returns food data Map via Get.back(result: foodData).

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/gemini_service.dart';
import '../../theme/colors.dart';

typedef _C = C;

class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key});

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  bool _isAnalyzing = false;
  String _statusText = 'Take a photo of your food';

  Future<void> _captureAndAnalyze() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing food with AI...';
    });

    try {
      final Uint8List bytes = await photo.readAsBytes();
      final Map<String, dynamic>? result =
      await GeminiService.analyzeFoodImage(bytes);

      // Check for error responses from Gemini
      if (result == null) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not analyze image. Try again.';
        });
        Get.snackbar(
          '❌ Analysis Failed',
          'Something went wrong. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      // Gemini said it's not food
      if (result['error'] == 'not_food') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'No food detected. Try again.';
        });
        Get.snackbar(
          '🚫 Not Food',
          'No food detected in the photo. Please take a photo of food.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Gemini said image is unclear
      if (result['error'] == 'unclear') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Image too unclear. Try again.';
        });
        Get.snackbar(
          '📷 Unclear Photo',
          'Image is too blurry or dark. Try better lighting.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Success — return food data to add_meal_controller
      if (result.containsKey('food_name')) {
        Get.back(result: result);
      } else {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not identify food. Try again.';
        });
        Get.snackbar(
          '❌ Unknown Food',
          'Could not identify the food. Try a clearer photo.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'Something went wrong. Try again.';
      });
      Get.snackbar(
        '❌ Error',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,  // ← only change from camera
      imageQuality: 85,
    );

    if (photo == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing food with AI...';
    });

    try {
      final Uint8List bytes = await photo.readAsBytes();
      final Map<String, dynamic>? result =
      await GeminiService.analyzeFoodImage(bytes);

      if (result == null) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not analyze image. Try again.';
        });
        Get.snackbar('❌ Analysis Failed', 'Something went wrong. Please try again.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white);
        return;
      }

      if (result['error'] == 'not_food') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'No food detected. Try again.';
        });
        Get.snackbar('🚫 Not Food', 'No food detected. Please select a food photo.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
        return;
      }

      if (result['error'] == 'unclear') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Image too unclear. Try again.';
        });
        Get.snackbar('📷 Unclear Photo', 'Image is too blurry or dark.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
        return;
      }

      if (result.containsKey('food_name')) {
        Get.back(result: result);
      } else {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not identify food. Try again.';
        });
        Get.snackbar('❌ Unknown Food', 'Could not identify the food.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white);
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'Something went wrong. Try again.';
      });
      Get.snackbar('❌ Error', e.toString(), snackPosition: SnackPosition.TOP);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const Text(
                    'AI Food Scanner',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 40), // balance the row
                ],
              ),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon / loading indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isAnalyzing
                      ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      color: _C.primary,
                      strokeWidth: 3,
                    ),
                  )
                      : Container(
                    key: const ValueKey('icon'),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _C.primary.withOpacity(0.4), width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: _C.primary,
                      size: 52,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Status text
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Gemini AI will identify the food\nand estimate its calories & macros',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),

                const SizedBox(height: 48),

                // Main capture button
                if (!_isAnalyzing)
                  GestureDetector(
                    onTap: _captureAndAnalyze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _C.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isAnalyzing) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Choose from Gallery',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom manual entry button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'Enter manually instead',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}