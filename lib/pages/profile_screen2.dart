import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen2 extends StatefulWidget {
  const ProfileScreen2({Key? key}) : super(key: key);

  @override
  State<ProfileScreen2> createState() => _ProfileScreen2State();
}

class _ProfileScreen2State extends State<ProfileScreen2> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _imageFile;
  bool _isLoading = false;

  // 🔹 Update Firestore field
  Future<void> _updateField(String field, String value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection("users").doc(user.uid).set({
        field: value,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating $field: $e");
    }
  }

  // 🔹 Pick profile image
  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
      await _uploadImage();
    }
  }

  // 🔹 Upload to Firebase Storage
  Future<void> _uploadImage() async {
    if (_imageFile == null) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user");

      final ref = _storage
          .ref()
          .child("profile_pics/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg");

      await ref.putFile(_imageFile!);
      final downloadUrl = await ref.getDownloadURL();

      await _firestore.collection("users").doc(user.uid).set({
        "profilePic": downloadUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Upload error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No user logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041C15),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection("users").doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() ?? {};
            final name = data["username"] ?? "Unknown";
            final email = data["email"] ?? user.email ?? "No Email";
            final address = data["address"] ?? "Not Set";
            final phone = data["phone"] ?? "Not Set";
            final profilePic = data["profilePic"] ?? "";
            final bio = data["bio"] ?? "Not Set";

            return SingleChildScrollView(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Profile Section
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFE8B55B),
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (profilePic.isNotEmpty
                                  ? NetworkImage(profilePic)
                                  : const AssetImage('assets/images/user.jpg'))
                              as ImageProvider,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name and username
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.email?.split('@')[0]}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(Icons.chat_bubble_outline, () {}),
                          const SizedBox(width: 32),
                          _buildActionButton(Icons.videocam_outlined, () {}),
                          const SizedBox(width: 32),
                          _buildActionButton(Icons.call_outlined, () {}),
                          const SizedBox(width: 32),
                          _buildActionButton(Icons.more_horiz, () {}),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info Card
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEditableInfoField(
                            'Display Name',
                            name,
                                (v) => _updateField('username', v),
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            'Email Address',
                            email,
                                (_) {},
                            editable: false,
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            'Address',
                            address,
                                (v) => _updateField('address', v),
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            'Phone Number',
                            phone,
                                (v) => _updateField('phone', v),
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            'Bio',
                            bio,
                                (v) => _updateField('bio', v),
                          ),
                          const SizedBox(height: 32),

                          // Media Section placeholder
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Media Shared',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                              Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF00BFA6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildMediaItem('assets/images/media1.jpg', null)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMediaItem('assets/images/media2.jpg', null)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMediaItem('assets/images/media3.jpg', '255+')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditableInfoField(String label, String value, ValueChanged<String> onChanged,
      {bool editable = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 8),
        editable
            ? TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        )
            : Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFF0A3D2E),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  static Widget _buildMediaItem(String imagePath, String? overlayText) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFE0E0E0),
        image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
      ),
      child: overlayText != null
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.6),
        ),
        child: Center(
          child: Text(
            overlayText,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      )
          : null,
    );
  }
}
