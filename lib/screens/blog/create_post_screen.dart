import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '/controllers/post_controller.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PostController controller = Get.find<PostController>(); // Using find since it's likely already in memory

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Share Recipe",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        actions: [
          // "Publish" button in the AppBar is very "Rednote" style
          TextButton(
            onPressed: () => controller.submitPost(),
            child: const Text(
              "Publish",
              style: TextStyle(
                color: Color(0xFF00A676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() => controller.isLoading.value
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A676)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Upload Area (Visual Priority)
            GestureDetector(
              onTap: () => _showPickerOptions(context, controller), // Cleaned up logic
              child: Obx(() {
                if (controller.selectedImage.value != null) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          controller.selectedImage.value!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Edit/Remove Buttons
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            _buildCircleIcon(Icons.edit, () => _showPickerOptions(context, controller)),
                            const SizedBox(width: 8),
                            _buildCircleIcon(Icons.close, () => controller.selectedImage.value = null),
                          ],
                        ),
                      )
                    ],
                  );
                } else {
                  return _buildPlaceholder();
                }
              }),
            ),
            const SizedBox(height: 24),

            // 2. Title Input
            TextField(
              controller: controller.titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Give your recipe a title...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const Divider(),

            // 3. Content/Instructions Input
            TextField(
              controller: controller.contentController,
              maxLines: 10,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Share your ingredients and steps...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

// Helper for the Bottom Sheet (Solves the argument error)
void _showPickerOptions(BuildContext context, PostController controller) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFF00A676)),
            title: const Text('Take a Photo'),
            onTap: () {
              Get.back();
              controller.pickImage(ImageSource.camera); // Pass source
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF00A676)),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Get.back();
              controller.pickImage(ImageSource.gallery); // Pass source
            },
          ),
        ],
      ),
    ),
  );
}

// Helper for the circular overlay buttons
Widget _buildCircleIcon(IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: CircleAvatar(
      radius: 18,
      backgroundColor: Colors.black.withOpacity(0.5),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// Helper for the empty state placeholder
Widget _buildPlaceholder() {
  return Container(
    height: 200,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFE0F7F1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF00A676).withOpacity(0.3)),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded, size: 50, color: Color(0xFF00A676)),
        SizedBox(height: 10),
        Text("Add a photo of your dish", style: TextStyle(color: Color(0xFF00A676))),
      ],
    ),
  );
}