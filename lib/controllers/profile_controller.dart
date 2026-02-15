import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import 'post_controller.dart'; // Ensure this is imported

class ProfileController extends GetxController {
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  final nameController = TextEditingController();

  var username = "Guest".obs;
  var avatarUrl = "".obs;
  var userId = "".obs;
  var likedPosts = <PostModel>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    initialLoad();
  }

  String get currentUid => _service.currentUser?.id ?? "";

  // Helper to load everything at once
  Future<void> initialLoad() async {
    await loadProfile();
    await fetchLikedPosts();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      final data = await _service.getProfile();
      if (data != null) {
        userId.value = data['id']?.toString() ?? "";
        username.value = data['username'] ?? "Unknown";

        // Add timestamp to avatar URL to bypass Flutter's image cache
        if (data['avatar_url'] != null && data['avatar_url'].isNotEmpty) {
          avatarUrl.value = "${data['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}";
        } else {
          avatarUrl.value = "";
        }

        nameController.text = username.value;
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProfile() async {
    String newName = nameController.text.trim();
    if (newName.isEmpty) {
      Get.snackbar("Error", "Name cannot be empty", backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      isLoading.value = true;
      await _service.updateProfile(username: newName);

      // 1. Update local UI immediately
      username.value = newName;

      // 2. Refresh PostController so "My Recipes" shows the new name
      try {
        final postController = Get.find<PostController>();
        await postController.fetchPosts();
      } catch (e) {
        debugPrint("PostController not initialized yet");
      }

      Get.snackbar("Success", "Profile updated", backgroundColor: const Color(0xFF00A676), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLikedPosts() async {
    try {
      // Don't trigger main isLoading here to avoid full screen shimmers on every like
      final List<dynamic> data = await _service.fetchLikedPosts();
      likedPosts.value = data.map((item) {
        return PostModel.fromMap(
            item['posts'] as Map<String, dynamic>,
            currentUserId: currentUid
        );
      }).toList();
    } catch (e) {
      debugPrint("Error fetching liked posts: $e");
    }
  }

  Future<void> updateAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image == null) return;

      isLoading.value = true;

      // 1. Update Supabase
      await _service.updateProfile(
        username: username.value,
        avatarFile: File(image.path),
      );

      // 2. Refresh local profile (Me Screen header)
      await loadProfile();

      // 3. THE FIX: Refresh the Liked Posts list
      // This updates the avatars in your "Liked" tab
      await fetchLikedPosts();

      // 4. Refresh the Main Feed list
      // This updates the avatars in the main home screen
      try {
        await Get.find<PostController>().fetchPosts();
      } catch (e) {
        debugPrint("PostController not yet loaded");
      }

      Get.snackbar("Success", "Updated everywhere!");
    } catch (e) {
      Get.snackbar("Error", "Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _service.signOut();
      // Clear data before leaving
      userId.value = "";
      username.value = "Guest";
      avatarUrl.value = "";
      likedPosts.clear();

      // IMPORTANT: Navigates to the route defined in main.dart
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar("Error", "Logout failed: $e");
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}