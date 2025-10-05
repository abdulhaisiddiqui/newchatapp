import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatapp/services/story/story_service.dart';

class StoryUploadPage extends StatefulWidget {
  const StoryUploadPage({super.key});

  @override
  State<StoryUploadPage> createState() => _StoryUploadPageState();
}

class _StoryUploadPageState extends State<StoryUploadPage> {
  final StoryService _storyService = StoryService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;

  // ✅ Pick image from gallery/camera
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
      });
    }
  }

  // ✅ Upload image using StoryService
  Future<void> _uploadImageStory() async {
    if (_selectedFile == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to upload stories")),
        );
        return;
      }

      await _storyService.uploadStory(
        userId: currentUser.uid,
        username: currentUser.email ?? 'Unknown User',
        file: _selectedFile!,
        type: "image",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Story uploaded successfully!")),
      );

      Navigator.pop(context); // back to Home
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to upload: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Story")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼️ Preview selected image
            _selectedFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedFile!,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Text(
                    "No image selected",
                    style: TextStyle(fontSize: 16),
                  ),
            const SizedBox(height: 20),

            // 📸 Pick buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ Upload button
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Upload Image Story"),
              onPressed: _selectedFile != null ? _uploadImageStory : null,
            ),

            const SizedBox(height: 30),

            // ✍️ Text status
            ElevatedButton.icon(
              icon: const Icon(Icons.text_fields),
              label: const Text("Post Text Status"),
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please log in to post status"),
                    ),
                  );
                  return;
                }

                await _storyService.uploadStory(
                  userId: currentUser.uid,
                  username: currentUser.email ?? 'Unknown User',
                  text: "Hello from my status!",
                  type: "text",
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
