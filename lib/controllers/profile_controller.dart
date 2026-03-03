import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import 'post_controller.dart';

class ProfileController extends GetxController {
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  // Controllers & State
  final nameController = TextEditingController();
  var isUploading = false.obs;
  var isLoading = false.obs;

  // Profile Data
  var username = "Guest".obs;
  var avatarUrl = "".obs;
  var userId = "".obs;
  var likedPosts = <PostModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    initialLoad();
  }

  String get currentUid => _service.currentUser?.id ?? "";

  // ==========================
  // Data Loading
  // ==========================

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

        // Use a cache-buster timestamp so Flutter doesn't show the old image
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

  Future<void> fetchLikedPosts() async {
    try {
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

  // ==========================
  // Profile Actions
  // ==========================

  Future<void> updateProfile() async {
    String newName = nameController.text.trim();
    if (newName.isEmpty) {
      Get.snackbar("Error", "Name cannot be empty",
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      isLoading.value = true;
      await _service.updateProfile(username: newName);

      // Update local UI state
      username.value = newName;

      // Force refresh the PostController to update author names on feed
      try {
        final postController = Get.find<PostController>();
        await postController.fetchPosts();
      } catch (e) {
        debugPrint("PostController not available");
      }

      Get.snackbar("Success", "Profile updated",
          backgroundColor: const Color(0xFF00A676), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // HARDWARE INTEGRATION (Camera/Gallery)
  // ==========================

  Future<void> updateAvatar(ImageSource source) async {
    try {
      // Accessing Mobile Unique Feature: Camera or Gallery
      final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 50, // Optimizing for mobile data usage
          maxWidth: 400     // Standard profile size
      );

      if (image == null) return;

      isLoading.value = true;

      // 1. Upload to Supabase Storage via Service
      // The folder path logic ('profiles/') is managed inside the service
      await _service.updateProfile(
        username: username.value,
        avatarFile: File(image.path),
      );

      // 2. Re-load profile to get the new URL
      await loadProfile();

      // 3. Sync Liked tab and Main Feed avatars
      await fetchLikedPosts();
      try {
        await Get.find<PostController>().fetchPosts();
      } catch (e) {
        debugPrint("PostController not found during sync");
      }

      Get.snackbar("Success", "Avatar updated via ${source.name}!");
    } catch (e) {
      Get.snackbar("Error", "Upload failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // Authentication
  // ==========================

  Future<void> logout() async {
    try {
      await _service.signOut();

      // Clear local memory
      userId.value = "";
      username.value = "Guest";
      avatarUrl.value = "";
      likedPosts.clear();

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