import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart'; // Ensure you import your model

class ProfileController extends GetxController {
  final SupabaseService _service = SupabaseService();

  final nameController = TextEditingController();

  // Observable profile data
  var username = "Guest".obs;
  var avatarUrl = "".obs;
  var userId = "".obs;

  // Observable lists
  var likedPosts = <PostModel>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
    fetchLikedPosts();
  }

  // Helper to get current user ID quickly
  String get currentUid => _service.currentUser?.id ?? "";

  Future<void> loadProfile() async {
    try {
      final data = await _service.getProfile();
      if (data != null) {
        userId.value = data['id'] ?? "";
        username.value = data['username'] ?? "Unknown";
        avatarUrl.value = data['avatar_url'] ?? "";

        nameController.text = username.value;
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<void> updateProfile() async {
    if (nameController.text.isEmpty) {
      Get.snackbar(
          "Error", "Name cannot be empty", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isLoading.value = true;
      await _service.updateProfile(
        username: nameController.text.trim(),
      );

      // Locally update observables so UI changes immediately
      username.value = nameController.text.trim();

      Get.snackbar(
          "Success", "Profile updated", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLikedPosts() async {
    try {
      isLoading.value = true;
      final List<dynamic> data = await _service.fetchLikedPosts();

      // We map the nested 'posts' data from Supabase into PostModel objects
      likedPosts.value = data.map((item) {
        // fetchLikedPosts usually returns {'posts': {...}}
        // We pass the currentUid to handle the 'isLiked' state correctly in the model
        return PostModel.fromMap(item['posts'], currentUserId: currentUid);
      }).toList();
    } catch (e) {
      print("Error fetching liked posts: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _service.signOut();
      // This clears all screens and takes the user back to Login
      // Replace '/login' with whatever your login route name is
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar("Error", "Logout failed: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white
      );
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> updateAvatar() async {
    try {
      // 1. Pick the image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Compress to save storage space
      );

      if (image == null) return;

      isLoading.value = true;
      File imageFile = File(image.path);

      // 2. Upload to Supabase
      // Note: We use the updateProfile method you already have in SupabaseService
      await _service.updateProfile(
        username: username.value,
        avatarFile: imageFile,
      );

      // 3. Refresh local data
      await loadProfile();
      Get.snackbar("Success", "Avatar updated!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF00A676),
          colorText: Colors.white
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }

    @override
    void onClose() {
      nameController.dispose();
      super.onClose();
    }
  }
}