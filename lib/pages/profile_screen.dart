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
  int _selectedIndex = 3; // Settings tab selected

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      debugPrint("Error uploading profile picture: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: const Center(child: Text("No user logged in")),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection("users").doc(uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final Map<String, dynamic>? data = snapshot.data?.data();

              final String email =
                  (data?['email'] as String?) ?? user.email ?? "No Email";
              final String profilePic = (data?['profilePic'] as String?) ?? "";
              final String username =
                  (data?['username'] as String?) ??
                  (user.email != null
                      ? user.email!.split('@')[0]
                      : user.uid.substring(0, 6));
              final String phone = (data?['phone'] as String?) ?? "Not set";
              final String bio =
                  (data?['bio'] as String?) ?? "Never give up 💪";

              return Column(
                children: [
                  // App bar
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              "Settings",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // White card container
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // Drag indicator
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Profile header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!)
                                              as ImageProvider
                                        : (profilePic.isNotEmpty
                                              ? NetworkImage(profilePic)
                                              : const AssetImage(
                                                  "assets/images/user.png",
                                                )),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bio,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2,
                                    color: Colors.teal,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 25),

                          // Settings list
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              children: [
                                _buildSettingItem(
                                  icon: Icons.key_outlined,
                                  title: "Account",
                                  subtitle: "Privacy, security, change number",
                                  onTap: () {
                                    _navigateToEditProfile(
                                      context,
                                      username,
                                      email,
                                      phone,
                                      bio,
                                    );
                                  },
                                ),
                                _buildSettingItem(
                                  icon: Icons.chat_bubble_outline,
                                  title: "Chat",
                                  subtitle: "Chat history, theme, wallpapers",
                                  onTap: () {},
                                ),
                                _buildSettingItem(
                                  icon: Icons.notifications_outlined,
                                  title: "Notifications",
                                  subtitle: "Messages, group and others",
                                  onTap: () {},
                                ),
                                _buildSettingItem(
                                  icon: Icons.help_outline,
                                  title: "Help",
                                  subtitle:
                                      "Help center, contact us, privacy policy",
                                  onTap: () {},
                                ),
                                _buildSettingItem(
                                  icon: Icons.storage_outlined,
                                  title: "Storage and data",
                                  subtitle: "Network usage, storage usage",
                                  onTap: () {},
                                ),
                                _buildSettingItem(
                                  icon: Icons.person_add_outlined,
                                  title: "Invite a friend",
                                  subtitle: "",
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
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

      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.chat_bubble_outline, "Message", 0),
                _buildNavItem(Icons.call_outlined, "Calls", 1),
                _buildNavItem(Icons.contacts_outlined, "Contacts", 2),
                _buildNavItem(Icons.settings_outlined, "Settings", 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey[700], size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.teal : Colors.grey, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.teal : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(
    BuildContext context,
    String username,
    String email,
    String phone,
    String bio,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          username: username,
          email: email,
          phone: phone,
          bio: bio,
          onUpdate: (field, value) async {
            final user = _auth.currentUser;
            if (user == null) return;

            try {
              await _firestore.collection("users").doc(user.uid).set({
                field: value,
              }, SetOptions(merge: true));
            } catch (e) {
              debugPrint("Error updating $field: $e");
            }
          },
        ),
      ),
    );
  }
}

// Edit Profile Screen (separate page for editing details)
class EditProfileScreen extends StatefulWidget {
  final String username;
  final String email;
  final String phone;
  final String bio;
  final Function(String, String) onUpdate;

  const EditProfileScreen({
    super.key,
    required this.username,
    required this.email,
    required this.phone,
    required this.bio,
    required this.onUpdate,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _phoneController = TextEditingController(text: widget.phone);
    _bioController = TextEditingController(text: widget.bio);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildEditField(
            label: "Display Name",
            controller: _usernameController,
            onChanged: () =>
                widget.onUpdate("username", _usernameController.text),
          ),
          _buildEditField(
            label: "Email Address",
            controller: TextEditingController(text: widget.email),
            enabled: false,
            onChanged: () {},
          ),
          _buildEditField(
            label: "Bio",
            controller: _bioController,
            onChanged: () => widget.onUpdate("bio", _bioController.text),
          ),
          _buildEditField(
            label: "Phone Number",
            controller: _phoneController,
            onChanged: () => widget.onUpdate("phone", _phoneController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.teal),
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
