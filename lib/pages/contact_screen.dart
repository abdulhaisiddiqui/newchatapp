import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/pages/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
                  child: IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.person, color: Colors.white),
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
    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

    if (_auth.currentUser!.email == data['email']) {
      return Container();
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Slidable(
        key: ValueKey(data['uid']),

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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(data['bio'] ?? "Hey there! I am using Chatbox", style: TextStyle(fontSize: 12)),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(
                  data['profilePic'] ?? 'assets/images/google-logo.png',
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
      ),
    );
  }
}
