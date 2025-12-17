import 'package:chatapp/services/user/contact_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addContact(String contactUserId, String contactEmail) async {
    try {
      await _contactService.addContact(contactUserId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $contactEmail to contacts')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add contact: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF000E08),
      body: Column(
        children: [
          const SizedBox(height: 50),
          // Header
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Center(
                  child: Text(
                    "Add Contact",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email or username',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // User List
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
          return const Center(child: Text('Error'));
        }

        if (snapshots.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshots.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'] as String? ?? '';
          final username = data['username'] as String? ?? '';
          final uid = data['uid'] as String? ?? '';

          // Exclude current user
          if (uid == _auth.currentUser?.uid) return false;

          // Filter by search query
          if (_searchQuery.isEmpty) return false; // Only show when searching

          return email.toLowerCase().contains(_searchQuery) ||
              username.toLowerCase().contains(_searchQuery);
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Start typing to search users'
                  : 'No users found',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildUserListItem(users[index]);
          },
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final userEmail = data['email'] as String? ?? '';
    final userUid = data['uid'] as String? ?? '';
    final username = data['username'] as String? ?? userEmail.split('@').first;

    return FutureBuilder<bool>(
      future: _contactService.isContact(userUid),
      builder: (context, snapshot) {
        final isAlreadyContact = snapshot.data ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: ListTile(
            title: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              data['bio'] as String? ?? "Hey there! I am using Chatbox",
              style: const TextStyle(fontSize: 12),
            ),
            leading: CircleAvatar(
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
            trailing: isAlreadyContact
                ? const Icon(Icons.check, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addContact(userUid, userEmail),
                  ),
          ),
        );
      },
    );
  }
}
