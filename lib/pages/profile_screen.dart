import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _imageFile;
  bool _isLoading = false;

  // 🔹 Firestore field update helper
  Future<void> _updateField(String field, String value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection("users").doc(user.uid).set({
        field: value,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating $field: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update $field")),
      );
    }
  }

  // 🔹 Image picker
  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  // 🔹 Upload image to Firebase Storage
  Future<void> _uploadImage() async {
    if (_imageFile == null) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No logged in user");

      String uid = user.uid;
      Reference ref = _storage.ref().child("profile_pics/$uid.jpg");

      await ref.putFile(_imageFile!);
      String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection("users").doc(uid).set({
        "profilePic": downloadUrl,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated!")),
      );
    } catch (e) {
      debugPrint("Error uploading profile picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Profile"),
        ),
        body: const Center(child: Text("No user logged in")),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF001E1A),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection("users").doc(uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final Map<String, dynamic>? data = snapshot.data?.data();

              final String email = (data?['email'] as String?) ??
                  user.email ??
                  "No Email";
              final String profilePic = (data?['profilePic'] as String?) ?? "";
              final String username = (data?['username'] as String?) ??
                  (user.email != null
                      ? "@${user.email!.split('@')[0]}"
                      : "@${user.uid.substring(0, 6)}");
              final String phone = (data?['phone'] as String?) ?? "Not Set";
              final String bio = (data?['bio'] as String?) ?? "Not Set";
              final String address = (data?['address'] as String?) ?? "Not Set";

              return Column(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Profile picture
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 55,
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : (profilePic.isNotEmpty
                                    ? NetworkImage(profilePic)
                                    : const AssetImage("assets/images/default_profile.png")),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          username,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _actionButton(Icons.chat),
                            const SizedBox(width: 20),
                            _actionButton(Icons.videocam),
                            const SizedBox(width: 20),
                            _actionButton(Icons.call),
                            const SizedBox(width: 20),
                            _actionButton(Icons.more_horiz),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // White editable fields
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: ListView(
                        children: [
                          _buildEditableField(
                            label: "Display Name",
                            value: username,
                            onChanged: (val) => _updateField("username", val),
                          ),
                          _buildEditableField(
                            label: "Email Address",
                            value: email,
                            onChanged: (_) {},
                          ),
                          _buildEditableField(
                            label: "Bio",
                            value: bio,
                            onChanged: (val) => _updateField("bio", val),
                          ),
                          _buildEditableField(
                            label: "Phone Number",
                            value: phone,
                            onChanged: (val) => _updateField("phone", val),
                          ),
                          _buildEditableField(
                            label: "Address",
                            value: address,
                            onChanged: (val) => _updateField("address", val),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // 🔹 Editable field widget
  Widget _buildEditableField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 5),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none, // 👈 border hat gaya
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

        ],
      ),
    );
  }

  static Widget _actionButton(IconData icon) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.teal.withOpacity(0.15),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
