import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatapp/services/story/story_service.dart';

class StoryUploadPage extends StatefulWidget {
  const StoryUploadPage({super.key});

  @override
  State<StoryUploadPage> createState() => _StoryUploadPageState();
}

class _StoryUploadPageState extends State<StoryUploadPage> {
  final StoryService _storyService = StoryService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  File? _selectedFile;
  bool _isUploading = false;
  String? _currentUserId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      // Try to get username from Firestore users collection
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        _currentUsername =
            userDoc.data()?['username'] as String? ??
            user.email?.split('@').first ??
            'User';
      } catch (e) {
        _currentUsername = user.email?.split('@').first ?? 'User';
      }
      setState(() {});
    }
  }

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

    setState(() => _isUploading = true);

    try {
      await _storyService.uploadStory(
        userId: _currentUserId!,
        username: _currentUsername!,
        file: _selectedFile!,
        type: "image",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story uploaded successfully!")),
        );
        Navigator.pop(context); // back to Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ✅ Upload text story
  Future<void> _uploadTextStory() async {
    if (_currentUserId == null || _currentUsername == null) return;

    setState(() => _isUploading = true);

    try {
      await _storyService.uploadStory(
        userId: _currentUserId!,
        username: _currentUsername!,
        text: "Hello from my status!",
        type: "text",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text status posted successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to post status: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? "Uploading..." : "Upload Image Story"),
              onPressed: _selectedFile != null && !_isUploading
                  ? _uploadImageStory
                  : null,
            ),

            const SizedBox(height: 30),

            // ✍️ Text status
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.text_fields),
              label: Text(_isUploading ? "Posting..." : "Post Text Status"),
              onPressed: _isUploading ? null : () => _uploadTextStory(),
            ),
          ],
        ),
      ),
    );
  }
}
