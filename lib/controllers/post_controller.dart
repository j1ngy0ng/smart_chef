import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_chef/controllers/profile_controller.dart';
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

  //Search variable
  var searchQuery = "".obs; // Holds the current search text

  // Use a computed property (getter) to filter posts automatically
  List<PostModel> get filteredPosts {
    if (searchQuery.value.isEmpty) {
      return posts;
    }
    return posts.where((post) {
      final title = post.title.toLowerCase();
      final content = post.content.toLowerCase();
      final query = searchQuery.value.toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList();
  }
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
        final model = PostModel.fromMap(e as Map<String, dynamic>, currentUserId: currentUid);

        // DEBUG PRINT: Compare these two in your console!
        print("Post ID: ${model.id} | Author ID: ${model.user.id} | My ID: $currentUid");

        return model;
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

  List<PostModel> get myPosts {
    final currentUid = _service.currentUser?.id;
    if (currentUid == null) return [];
    // We use .where to filter posts belonging to the logged-in user
    return posts.where((p) => p.user.id == currentUid).toList();
  }

  //Update post
  Future<void> updatePost(String postId) async {
    try {
      isLoading.value = true;

      await _service.updatePost(
        postId: postId,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
      );

      // This is vital! It tells the BlogFeedScreen to show the new info
      await fetchPosts();

      // Clear inputs for the next time the user opens the screen
      titleController.clear();
      contentController.clear();
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
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

    final profileController = Get.find<ProfileController>();
    bool originalLiked = isLiked.value;
    int originalCount = currentLikeCount.value;

    try {
      // 1. Optimistic UI Toggle
      if (isLiked.value) {
        isLiked.value = false;
        currentLikeCount.value--;

        // SYNC: Remove from profile list
        profileController.likedPosts.removeWhere((p) => p.id == postId);
      } else {
        isLiked.value = true;
        currentLikeCount.value++;

        // SYNC: Add to profile list
        // Find the post object from our main list
        final likedPost = posts.firstWhereOrNull((p) => p.id == postId);
        if (likedPost != null) {
          // Create a copy with the liked status set to true
          final updatedLikedPost = PostModel(
            id: likedPost.id,
            title: likedPost.title,
            content: likedPost.content,
            imageUrl: likedPost.imageUrl,
            user: likedPost.user,
            likeCount: currentLikeCount.value,
            isLiked: true,
          );

          // Add to the beginning of the liked list
          profileController.likedPosts.insert(0, updatedLikedPost);
        }
      }

      // 2. Update the main feed list
      int index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        posts[index] = PostModel(
          id: posts[index].id,
          title: posts[index].title,
          content: posts[index].content,
          imageUrl: posts[index].imageUrl,
          user: posts[index].user,
          likeCount: currentLikeCount.value,
          isLiked: isLiked.value,
        );
        posts.refresh();
      }

      // 3. Call Database
      if (originalLiked) {
        await _service.unlikePost(postId);
      } else {
        await _service.likePost(postId);
      }
    } catch (e) {
      // Revert UI on failure
      isLiked.value = originalLiked;
      currentLikeCount.value = originalCount;
      await profileController.fetchLikedPosts(); // Refresh from DB to be sure
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    super.onClose();
  }
}
