import 'package:chatapp/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_page.dart';
import '../components/user_status_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign user out
  void signOut() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: CircleAvatar(
              backgroundImage: AssetImage('assets/images/user.png'),
            ),
          ),
          IconButton(
            onPressed: signOut,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // 👇 Stories Section
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Container(
              height: 110,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  storyAvatar(
                    'My status',
                    'assets/images/user.png',
                    showOverlay: true,
                  ),
                  storyAvatar(
                    'Adil',
                    'assets/images/user.png',
                    bgColor: const Color(0xFFFFC746),
                    showOverlay: false,
                  ),
                  storyAvatar(
                    'Marina',
                    'assets/images/user.png',
                    bgColor: const Color(0xFFEDA0A8),
                  ),
                  storyAvatar(
                    'Dean',
                    'assets/images/user.png',
                    bgColor: const Color(0xFF98A1F1),
                  ),
                  storyAvatar(
                    'Max',
                    'assets/images/user.png',
                    bgColor: const Color(0xFFFBDC94),
                    showOverlay: false,
                  ),
                ],
              ),
            ),
          ),

          // 👇 Firestore Chat List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: _buildUserList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --- Firestore User List ---
  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshots) {
        if (snapshots.hasError) {
          return const Center(child: Text('Error'));
        }
        if (snapshots.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Loading...'));
        }

        if (snapshots.data == null) {
          return const Center(child: Text('No users found'));
        }

        final docs = snapshots.data!.docs;

        return ListView(
          padding: const EdgeInsets.only(top: 20),
          children: docs.map<Widget>((doc) => _buildUserListItem(doc)).toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    // Skip current user (temporarily disabled for testing)
    final currentUser = _auth.currentUser;

    // TEMPORARILY DISABLED: Allow all users to be shown for testing
    // if (currentUser == null) {
    // } else if (currentUser.email == data['email']) {
    //   return Container();
    // }

    final uid = data['uid'] ?? document.id; // Use document ID as fallback
    final email = data['email'] ?? 'test@example.com'; // Use fallback email
    final username = data['username'] ?? email.split('@')[0];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              data['profilePic'] != null &&
                  data['profilePic'].toString().isNotEmpty
              ? NetworkImage(data['profilePic'])
              : const AssetImage('assets/images/user.png') as ImageProvider,
          radius: 24,
          child: Align(
            alignment: Alignment.bottomRight,
            child: UserStatusIndicator(userId: uid, showText: false, size: 12),
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: UserStatusIndicator(userId: uid, showText: true, size: 8),
        onTap: () {
          // Ensure we have valid data before navigating
          if (uid != null &&
              uid.isNotEmpty &&
              email != null &&
              email.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatPage(receiverUserEmail: email, receiverUserId: uid),
              ),
            );
          } else {
            // Show error if navigation data is invalid
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open chat: Invalid user data')),
            );
          }
        },
      ),
    );
  }

  /// --- Story Avatar Widget ---
  Widget storyAvatar(
    String name,
    String imagePath, {
    Color bgColor = Colors.grey,
    bool showOverlay = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: bgColor,
                radius: 30,
                child: CircleAvatar(
                  backgroundImage: AssetImage(imagePath),
                  radius: 27,
                  backgroundColor: Colors.transparent,
                ),
              ),
              if (showOverlay)
                Positioned(
                  top: 40,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.add, color: Colors.black, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
