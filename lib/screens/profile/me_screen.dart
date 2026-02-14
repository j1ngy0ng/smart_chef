import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import 'package:get/get.dart';
import '/controllers/profile_controller.dart';
import '/controllers/post_controller.dart';
import '/screens/blog/post_detail_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> with SingleTickerProviderStateMixin {
  final ProfileController profileController = Get.put(ProfileController());
  final PostController postController = Get.find<PostController>();
  late TabController _tabController;

  final Color primaryGreen = const Color(0xFF00A676);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    profileController.loadProfile();
    profileController.fetchLikedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Kitchen", // Personalized title
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              HapticFeedback.lightImpact(); // Subtle vibration
              _showSettingsSheet();
            },
          )
        ],
      ),
      body: Obx(() => Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: primaryGreen,
                      unselectedLabelColor: Colors.grey[400],
                      indicatorColor: primaryGreen,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: const [
                        Tab(text: "My Recipes"),
                        Tab(text: "Liked"),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostGrid(isLiked: false),
                _buildPostGrid(isLiked: true),
              ],
            ),
          ),
          // Global Loading Overlay
          if (profileController.isLoading.value)
            Container(
              color: Colors.white.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator(color: primaryGreen)),
            ),
        ],
      )),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Avatar with Camera Overlay
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              profileController.updateAvatar();
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryGreen.withOpacity(0.2), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: profileController.avatarUrl.value.isNotEmpty
                        ? NetworkImage(profileController.avatarUrl.value)
                        : null,
                    child: profileController.avatarUrl.value.isEmpty
                        ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                        : null,
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryGreen,
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profileController.username.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "ID: ${profileController.userId.value.length > 8 ? profileController.userId.value.substring(0, 8) : profileController.userId.value}",
            style: TextStyle(color: Colors.grey[500], fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          // Clean Stat Container
          Row(
            children: [
              Expanded(child: _buildStatItem("Recipes", postController.posts.where((p) => p.user.id == profileController.userId.value).length.toString())),
              Container(height: 30, width: 1, color: Colors.grey[200]), // Divider
              Expanded(child: _buildStatItem("Collection", profileController.likedPosts.length.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildPostGrid({required bool isLiked}) {
    final posts = isLiked
        ? profileController.likedPosts
        : postController.posts.where((p) => p.user.id == profileController.userId.value).toList();

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Text(isLiked ? "No favorites yet" : "Start sharing recipes!",
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12), // Add padding for a "card" feel
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 items per row looks better for recipes
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => Get.to(() => PostDetailScreen(post: post)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(post.imageUrl ?? '', fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  void _showSettingsSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        color: const Color(0xFF00A676),
        decoration: BoxDecoration(
          shape: BoxShape.circle, // ✅ Correct: shape goes inside BoxDecoration
          color: Colors.green,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.person_outline, color: primaryGreen),
              title: const Text("Edit Profile Name", style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () { Get.back(); _showEditNameDialog(); },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
              onTap: () => profileController.logout(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    Get.defaultDialog(
      title: "Change Name",
      titlePadding: const EdgeInsets.only(top: 20),
      contentPadding: const EdgeInsets.all(24),
      content: TextField(
        controller: profileController.nameController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: "What should we call you?",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryGreen)),
        ),
      ),
      textConfirm: "Save Changes",
      confirmTextColor: Colors.white,
      buttonColor: primaryGreen,
      onConfirm: () async {
        await profileController.updateProfile();
        Get.back();
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(context, offset, overlaps) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate old) => false;
}