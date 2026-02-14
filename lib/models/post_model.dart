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
    final userData = map['profiles'] ?? map['profiles!posts_user_id_fkey'];

    // 1. Get the list of likes from the map
    final likesList = map['likes'] as List<dynamic>? ?? [];

    // 2. Check if the current user's ID exists in the likes list
    // This assumes your Supabase join for 'likes' returns the user_id
    bool likedByMe = false;
    if (currentUserId != null) {
      likedByMe = likesList.any((like) => like['user_id'] == currentUserId);
    }

    return PostModel(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? 'No Title',
      content: map['content'] ?? '',
      imageUrl: map['image_url'],
      likeCount: likesList.length,
      isLiked: likedByMe, // Correctly set based on database data
      user: userData != null
          ? UserModel.fromMap(userData as Map<String, dynamic>)
          : UserModel(id: '', username: 'Unknown User', avatarUrl: null),
    );
  }
}