import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _groupNameController = TextEditingController();
  final _groupDescController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isCreating = false;
  List<String> selectedUserIds = [];

  @override
  void initState() {
    super.initState();
    selectedUserIds.add(_auth.currentUser!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser!;

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
          'Create Group',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Group Name Label
                    const Text(
                      'Group Name',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                    ),
                    const SizedBox(height: 12),

                    // 🔹 Group Name Field
                    TextField(
                      controller: _groupNameController,
                      decoration: InputDecoration(
                        hintText: "Enter group name",
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 🔹 Group Description Label
                    const Text(
                      'Group Description',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                    ),
                    const SizedBox(height: 12),

                    // 🔹 Group Description Field
                    TextField(
                      controller: _groupDescController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Write something about the group...",
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),

                    const SizedBox(height: 32),

                    // 🔹 Group Admin Label
                    const Text(
                      'Group Admin',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Admin Info
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFB39DDB),
                            image: DecorationImage(
                              image: AssetImage('assets/images/admin.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.email ?? "Admin",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Group Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 🔹 Members Section
                    const Text(
                      'Select Members',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                    ),
                    const SizedBox(height: 16),

                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection("users").snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final users = snapshot.data!.docs;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: users.map((user) {
                            final userId = user.id;
                            final username = user.data().toString().contains('username')
                                ? user["username"]
                                : "Unknown";

                            if (userId == currentUser.uid) {
                              return _buildMemberAvatar(
                                "assets/images/admin.jpg",
                                const Color(0xFFB39DDB),
                                label: "$username (You)",
                                isSelected: true,
                              );
                            }

                            final isSelected = selectedUserIds.contains(userId);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedUserIds.remove(userId);
                                  } else {
                                    selectedUserIds.add(userId);
                                  }
                                });
                              },
                              child: _buildMemberAvatar(
                                "assets/images/member1.jpg",
                                const Color(0xFFE8B55B),
                                label: username,
                                isSelected: isSelected,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 🔹 Create Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Create',
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
    );
  }

  Widget _buildMemberAvatar(String imagePath, Color? bgColor,
      {String? label, bool isSelected = false}) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor ?? Colors.grey.shade300,
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
                border: Border.all(
                  color: isSelected ? Colors.teal : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            if (isSelected)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle, color: Colors.teal, size: 22),
              ),
          ],
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a group name")),
      );
      return;
    }

    setState(() => _isCreating = true);
    final currentUser = _auth.currentUser!;

    try {
      await _firestore.collection("chat_rooms").add({
        "name": _groupNameController.text.trim(),
        "description": _groupDescController.text.trim(),
        "adminId": currentUser.uid,
        "members": selectedUserIds,
        "isGroup": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group created successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating group: $e")),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }
}
