import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/pages/chat_page_chatview.dart';
import 'package:chatapp/pages/profile_screen.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _selectedUsers = {};

  void _createGroupChat() async {
    if (_selectedUsers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 2 users for a group chat'),
        ),
      );
      return;
    }

    // Show dialog to enter group name
    final groupNameController = TextEditingController();
    final groupName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Chat'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(
            hintText: 'Enter group name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = groupNameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (groupName != null && groupName.isNotEmpty) {
      try {
        final chatService = ChatService();
        final chatRoomId = await chatService.createGroupChat(
          memberIds: _selectedUsers.toList(),
          groupName: groupName,
        );

        if (chatRoomId != null) {
          setState(() {
            _selectedUsers.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Group "$groupName" created successfully!')),
          );

          // Navigate to the group chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverUserId: chatRoomId, // Not used for groups yet
                receiverUserEmail: groupName,
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFF000E08),
      body: Column(
        children: [
          const SizedBox(height: 50), // status bar ke liye space
          // 🔹 Custom Header
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Center(
                  child: Text(
                    "Contacts",
                    style: TextStyle(
                      color: Color(0XFFFFFFFF),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  child: Row(
                    children: [
                      if (_selectedUsers.isNotEmpty)
                        IconButton(
                          onPressed: _createGroupChat,
                          icon: Icon(Icons.group_add, color: Colors.white),
                          tooltip: 'Create Group',
                        ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedUsers.isNotEmpty) {
                              _selectedUsers.clear();
                            } else {
                              // Enter selection mode - maybe show a hint
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tap contacts to select for group chat',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        },
                        icon: Icon(
                          _selectedUsers.isNotEmpty
                              ? Icons.close
                              : Icons.checklist,
                          color: Colors.white,
                        ),
                        tooltip: _selectedUsers.isNotEmpty
                            ? 'Cancel Selection'
                            : 'Select Contacts',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 👇 White Container with Settings List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: _buildUserList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshots) {
        if (snapshots.hasError) {
          return Center(child: const Text('Error'));
        }

        if (snapshots.connectionState == ConnectionState.waiting) {
          return Center(child: Text('loading'));
        }

        return ListView(
          padding: EdgeInsets.only(top: 20),
          children: snapshots.data!.docs
              .map<Widget>((doc) => _buildUserListItem(doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    final currentUserEmail = _auth.currentUser?.email;
    final userEmail = data['email'] as String?;
    final userUid = data['uid'] as String?;

    // Skip current user and invalid entries
    if (currentUserEmail == userEmail || userEmail == null || userUid == null) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedUsers.contains(userUid);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Slidable(
        key: ValueKey(userUid),
        child: ListTile(
          onTap: _selectedUsers.isNotEmpty
              ? () {
            setState(() {
              if (isSelected) {
                _selectedUsers.remove(userUid);
              } else {
                _selectedUsers.add(userUid);
              }
            });
          }
              : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  receiverUserId: userUid,
                  receiverUserEmail: userEmail ?? '',
                ),
              ),
            );
          },

          title: Text(
            data['username'] as String? ?? userEmail.split('@').first,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(
            data['bio'] as String? ?? "Hey there! I am using Chatbox",
            style: const TextStyle(fontSize: 12),
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: 25,
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: data['profilePic'] as String? ?? '',
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(strokeWidth: 2),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/images/user.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(backgroundColor: Colors.green, radius: 6),
              ),
            ],
          ),
          trailing: _selectedUsers.isNotEmpty
              ? Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedUsers.add(userUid);
                      } else {
                        _selectedUsers.remove(userUid);
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}
