import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatapp/services/story/story_service.dart';

class StoryUploadPage extends StatefulWidget {
  const StoryUploadPage({Key? key}) : super(key: key);

  @override
  State<StoryUploadPage> createState() => _StoryUploadPageState();
}

class _StoryUploadPageState extends State<StoryUploadPage> {
  final StoryService _storyService = StoryService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;


  File? _selectedFile;
  String selectedPrivacy = 'Public';
  final TextEditingController captionController = TextEditingController();

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

    setState(() {
      _isLoading = true; // ✅ start loading
    });

    try {
      await _storyService.uploadStory(
        file: _selectedFile!,
        type: "image",
        caption: captionController.text.trim(),
        privacy: selectedPrivacy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story uploaded successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // ✅ stop loading
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041C15),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Top App Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Create Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // 🔹 Main Container
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🖼️ Preview Section
                      Center(
                        child: Container(
                          width: double.infinity,
                          height: 380,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 2,
                            ),
                          ),
                          child: _selectedFile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              _selectedFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF26A69A)
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: Color(0xFF26A69A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select a photo for your story',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ✍️ Caption
                      const Text(
                        'Add Caption',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: captionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write something about this moment...',
                          hintStyle: const TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔒 Privacy Options
                      const Text(
                        'Privacy',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildPrivacyOption('Public', Icons.public),
                          const SizedBox(width: 12),
                          _buildPrivacyOption('Friends', Icons.people),
                          const SizedBox(width: 12),
                          _buildPrivacyOption('Private', Icons.lock_outline),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // 🔹 Bottom Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Color(0xFF26A69A),
                        ),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(
                            color: Color(0xFF26A69A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF26A69A),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _selectedFile != null && !_isLoading ? _uploadImageStory : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white, // ✅ white spinner on green button
                          ),
                        )
                            : const Text(
                          'Post Story',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String label, IconData icon) {
    final isSelected = selectedPrivacy == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPrivacy = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF26A69A) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                isSelected ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                  isSelected ? const Color(0xFF2E7D32) : const Color(0xFF757575),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }
}
