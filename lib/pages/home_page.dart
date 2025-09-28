import 'package:chatapp/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_page.dart';

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
    print('DEBUG: Building user list');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshots) {
        print('DEBUG: StreamBuilder state: ${snapshots.connectionState}');
        print('DEBUG: Has error: ${snapshots.hasError}');
        print('DEBUG: Has data: ${snapshots.hasData}');

        if (snapshots.hasError) {
          print('DEBUG: Error: ${snapshots.error}');
          return const Center(child: Text('Error'));
        }
        if (snapshots.connectionState == ConnectionState.waiting) {
          print('DEBUG: Loading users...');
          return const Center(child: Text('Loading...'));
        }

        if (snapshots.data == null) {
          print('DEBUG: No data received');
          return const Center(child: Text('No users found'));
        }

        final docs = snapshots.data!.docs;
        print('DEBUG: Found ${docs.length} user documents');

        return ListView(
          padding: const EdgeInsets.only(top: 20),
          children: docs.map<Widget>((doc) => _buildUserListItem(doc)).toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    print('DEBUG: User document data: $data');

    // Skip current user (temporarily disabled for testing)
    final currentUser = _auth.currentUser;
    print('DEBUG: Current user email: ${currentUser?.email}');

    // TEMPORARILY DISABLED: Allow all users to be shown for testing
    // if (currentUser == null) {
    //   print('DEBUG: No current user, showing all users');
    // } else if (currentUser.email == data['email']) {
    //   print('DEBUG: Skipping current user: ${data['email']}');
    //   return Container();
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
      child: ListTile(
        onTap: () {
          final uid = data['uid'] ?? document.id; // Use document ID as fallback
          final email =
              data['email'] ?? 'test@example.com'; // Use fallback email
          print(
            'DEBUG: Tapped user - uid: $uid, email: $email, data keys: ${data.keys}',
          );

          print('DEBUG: Navigating to chat with uid: $uid, email: $email');
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
        title: Text(
          data['username'] ?? data['email'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: const Text("Tap to chat", style: TextStyle(fontSize: 12)),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                data['profilePic'] ??
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQxSFDJsQuUfNJriz0KiaTD28GR82xL1fW-nvsEF9GwaI_sq6SkPloo&usqp=CAE&s',
              ),
              radius: 25,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(backgroundColor: Colors.green, radius: 6),
            ),
          ],
        ),
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
