import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../services/supabase_service.dart';

class PostController extends GetxController {
  final SupabaseService _service = SupabaseService();

  // ==========================
  // Text Controllers
  // ==========================
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  // ==========================
  // Image
  // ==========================
  Rx<File?> selectedImage = Rx<File?>(null);

  // ==========================
  // Posts state
  // ==========================
  var posts = <PostModel>[].obs;
  var isLoading = false.obs;

  // ==========================
  // Init
  // ==========================
  @override
  void onInit() {
    super.onInit();
    fetchPosts(); // fetch posts on controller init
  }

  // ==========================
  // Fetch posts safely
  // ==========================
  Future<void> fetchPosts({bool showError = true}) async {
    try {
      isLoading.value = true;
      final data = await _service.fetchPosts();
      final currentUid = _service.currentUser?.id; // Get the ID of the logged-in user

      posts.value = data.map((e) {
        // Pass the current user ID to the factory constructor
        return PostModel.fromMap(e as Map<String, dynamic>, currentUserId: currentUid);
      }).toList();

    } catch (e) {
      // ... your error handling ...
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<PostModel>> getPosts() async {
    if (posts.isEmpty) await fetchPosts(showError: false);
    return posts;
  }

  // ==========================
  // Pick image
  // ==========================

  Future<void> pickImage(ImageSource source) async { // Needs 'ImageSource source'
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      selectedImage.value = File(image.path);
    }
  }

  // ==========================
  // Submit post
  // ==========================
  Future<void> submitPost() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Please fill all fields",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;

      String? imageUrl;
      if (selectedImage.value != null) {
        imageUrl = await _service.uploadImage(
          selectedImage.value!,
          'posts/${DateTime.now().millisecondsSinceEpoch}_${_service.currentUser?.id ?? 'anon'}.png',
        );

        if (imageUrl == null) {
          Get.snackbar(
            "Error",
            "Failed to upload image",
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }

      await _service.createPost(
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        imageFile: selectedImage.value,
      );

      // Clear inputs
      titleController.clear();
      contentController.clear();
      selectedImage.value = null;

      // Refresh feed safely after submission
      await fetchPosts();

      // Navigate back first
      Get.back();

      // Show success snackbar after screen pop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          "Success",
          "Post created",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      });
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  //Like or Unliked
  var isLiked = false.obs;
  var currentLikeCount = 0.obs;

  Future<void> checkIfLiked(String postId) async {
    isLiked.value = false; // Reset before checking
    try {
      final bool status = await _service.isPostLiked(postId);
      isLiked.value = status;
      print("Like status for $postId: $status"); // Debugging line
    } catch (e) {
      print("Error checking like: $e");
    }
  }

  Future<void> toggleLike(String postId) async {
    if (isLoading.value) return;

    // Capture current state
    bool originalLiked = isLiked.value;
    int originalCount = currentLikeCount.value;

    try {
      if (isLiked.value) {
        isLiked.value = false;
        currentLikeCount.value--;
      } else {
        isLiked.value = true;
        currentLikeCount.value++;
      }

      // --- THE FIX: SYNC THE MAIN LIST ---
      int index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        // Create a copy of the post with updated like data
        final updatedPost = PostModel(
          id: posts[index].id,
          title: posts[index].title,
          content: posts[index].content,
          imageUrl: posts[index].imageUrl,
          user: posts[index].user,
          likeCount: currentLikeCount.value, // Update count
          isLiked: isLiked.value,           // Update status
        );

        posts[index] = updatedPost; // Replace the post in the observable list
        posts.refresh(); // Tell GetX to redraw the Feed Screen
      }

      // Call database
      if (originalLiked) {
        await _service.unlikePost(postId);
      } else {
        await _service.likePost(postId);
      }
    } catch (e) {
      // Revert UI if database fails
      isLiked.value = originalLiked;
      currentLikeCount.value = originalCount;

      // Specifically handle the "Duplicate" error quietly
      if (e.toString().contains("23505")) {
        isLiked.value = true; // Sync UI to true since it already exists
      } else {
        Get.snackbar("Error", "Action failed");
      }
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    super.onClose();
  }
}
