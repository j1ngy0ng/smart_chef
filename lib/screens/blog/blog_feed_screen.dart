import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '/controllers/post_controller.dart';
import '/models/post_model.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class BlogFeedScreen extends StatelessWidget {
  BlogFeedScreen({super.key});

  final PostController postController = Get.put(PostController());
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: searchController,
            onChanged: (value) => postController.searchQuery.value = value,
            decoration: InputDecoration(
              hintText: "Search recipes...",
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                onPressed: () {
                  searchController.clear();
                  postController.searchQuery.value = "";
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (postController.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00A676)));
        }

        // --- USE FILTERED POSTS INSTEAD ---
        final posts = postController.filteredPosts;

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No results for '${postController.searchQuery.value}'",
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: const EdgeInsets.all(10),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildRedNoteCard(context, posts[index]);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A676),
        onPressed: () => Get.to(() => const CreatePostScreen())?.then((_) => postController.fetchPosts()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRedNoteCard(BuildContext context, PostModel post) {
    return GestureDetector(
      onTap: () => Get.to(() => PostDetailScreen(post: post)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Post Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: post.imageUrl != null
                  ? Hero(
                tag: post.id, // Added Hero tag for smooth transition
                child: Image.network(post.imageUrl!, fit: BoxFit.cover),
              )
                  : Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.image)),
            ),

            // 2. Title and Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // User Avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: post.user.avatarUrl != null
                            ? NetworkImage(post.user.avatarUrl!)
                            : null,
                        child: post.user.avatarUrl == null ? const Icon(Icons.person, size: 12) : null,
                      ),
                      const SizedBox(width: 6),
                      // Username
                      Expanded(
                        child: Text(
                          post.user.username,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // --- MODIFIED LIKE SECTION ---
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: post.isLiked ? Colors.red : Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                          "${post.likeCount}",
                          style: TextStyle(
                            fontSize: 12,
                            color: post.isLiked ? Colors.red : Colors.black,
                            fontWeight: post.isLiked ? FontWeight.bold : FontWeight.normal,
                          )
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}