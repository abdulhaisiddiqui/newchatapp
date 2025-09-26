import 'package:chatapp/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:chatapp/pages/bottomNav_screen.dart';

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
              backgroundImage: AssetImage('assets/images/profile-image.png'),
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
              padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  storyAvatar(
                    'My status',
                    'assets/images/profile-image.png',
                    showOverlay: true,
                  ),
                  storyAvatar(
                    'Adil',
                    'assets/images/adil.png',
                    bgColor: const Color(0xFFFFC746),
                    showOverlay: false,
                  ),
                  storyAvatar(
                    'Marina',
                    'assets/images/alex.png',
                    bgColor: const Color(0xFFEDA0A8),
                  ),
                  storyAvatar(
                    'Dean',
                    'assets/images/dean.png',
                    bgColor: const Color(0xFF98A1F1),
                  ),
                  storyAvatar(
                    'Max',
                    'assets/images/max.png',
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

        return ListView(
          padding: const EdgeInsets.only(top: 20),
          children: snapshots.data!.docs
              .map<Widget>((doc) => _buildUserListItem(doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    // Skip current user
    if (_auth.currentUser!.email == data['email']) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
      child: Slidable(
        key: ValueKey(data['uid']),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            CustomSlidableAction(
              flex: 1,
              onPressed: (context) {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  receiverUserEmail: data['email'],
                  receiverUserId: data['uid'],
                ),
              ),
            );
          },
          title: Text(
            data['username'] ?? data['email'],
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: const Text(
            "Tap to chat",
            style: TextStyle(fontSize: 12),
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(data['profilePic'] ?? 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQxSFDJsQuUfNJriz0KiaTD28GR82xL1fW-nvsEF9GwaI_sq6SkPloo&usqp=CAE&s'),
                radius: 25,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 6,
                ),
              ),
            ],
          ),
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
                    child: const Icon(Icons.add,
                        color: Colors.black, size: 14),
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
