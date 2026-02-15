import 'package:smart_chef/models/user_model.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final bool isLiked; // Added this field
  final UserModel user;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.likeCount,
    this.isLiked = false, // Default to false
    required this.user,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    // 1. Handle deep nesting
    // Sometimes Supabase returns { "posts": { ... } } instead of the post directly
    final postData = map.containsKey('posts') ? map['posts'] : map;

    // 2. Identify the User/Profile data
    // Check for 'profiles' (singular join) or the specific fkey join name
    final userData = postData['profiles'] ?? postData['profiles!posts_user_id_fkey'];

    // 3. Robust ID extraction
    final String authorId = postData['user_id']?.toString() ?? userData?['id']?.toString() ?? '';

    // 4. Like Logic
    final likesList = postData['likes'] as List<dynamic>? ?? [];
    bool likedByMe = false;

    if (currentUserId != null && currentUserId.isNotEmpty) {
      likedByMe = likesList.any((like) =>
      like['user_id']?.toString() == currentUserId.toString());
    }

    return PostModel(
      id: postData['id']?.toString() ?? '',
      title: postData['title'] ?? 'No Title',
      content: postData['content'] ?? '',
      imageUrl: postData['image_url'],
      likeCount: likesList.length,
      isLiked: likedByMe,
      user: UserModel(
        id: authorId,
        username: userData?['username'] ?? 'Unknown User',
        avatarUrl: userData?['avatar_url'],
      ),
    );
  }
}