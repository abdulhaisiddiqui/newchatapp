import 'package:chatapp/pages/story_upload_page.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/story/story_service.dart';
import 'package:chatapp/pages/story_upload_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/story/story_viewer.dart';
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

  Stream<QuerySnapshot> getChatRooms() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      // return an empty stream to avoid errors when not authenticated
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('members', arrayContains: currentUid)
        .orderBy('lastActivity', descending: true)
        .snapshots();
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
          // 👇 Stories Section (unchanged)
      // 👇 Stories Section
      Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            // --- My Status Button ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StoryUploadPage()), // banaoge alag file
                );
              },
              child: storyAvatar(
                'My Status',
                'assets/images/user.png',
                showOverlay: true,
              ),
            ),

            // --- Other Users Stories from Firestore ---
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: StoryService().getVisibleStories(_auth.currentUser!.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No statuses from your chats");
                  }

                  final stories = snapshot.data!;

                  return SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: stories.length,
                      itemBuilder: (context, index) {
                        final userStory = stories[index]; // ek user ka full bundle
                        final username = userStory["username"] ?? "User";

                        // user ke subcollection ka sabse naya story
                        final List<dynamic> userStories = userStory["stories"];
                        final latest = userStories.first; // already orderBy(desc)

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerPage(userData: userStory),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: latest["type"] == "image"
                                    ? NetworkImage(latest["url"])
                                    : null,
                                child: latest["type"] == "text"
                                    ? Text(
                                  latest["text"],
                                  style: const TextStyle(color: Colors.white),
                                )
                                    : null,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                username,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              )



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
                child: _buildChatList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    // Use StreamBuilder on chat_rooms (only chats where current user is a member)
    return StreamBuilder<QuerySnapshot>(
      stream: getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // show the real error so you can debug (index/auth/permission errors)
          final err = snapshot.error.toString();
          debugPrint('Firestore chat_rooms error: $err');
          return Center(child: Text('Error loading chats:\n$err'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chatRoom = docs[index];
            // defensive extraction of data
            final raw = chatRoom.data() as Map<String, dynamic>? ?? {};
            debugPrint('chat_room[${chatRoom.id}] -> $raw');

            // members may be List<dynamic>, convert safely to List<String>
            List<String> members = [];
            if (raw['members'] != null && raw['members'] is List) {
              members = (raw['members'] as List).map((e) => e.toString()).toList();
            }

            // find other user id (fallback: first member)
            final currentUid = _auth.currentUser?.uid ?? '';
            String otherUserId;
            if (members.isEmpty) {
              otherUserId = ''; // no members, fallback to empty
            } else if (members.length == 1) {
              otherUserId = members.first;
            } else {
              otherUserId = members.firstWhere(
                    (id) => id != currentUid,
                orElse: () => members.first,
              );
            }

            // extract lastMessage safely (it may be Map or String)
            String lastMessageText = _extractLastMessageText(raw['lastMessage']);

            // get profile and username of other user using FutureBuilder
            if (otherUserId.isEmpty) {
              // If otherUserId cannot be determined, just render a fallback tile
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('Unknown'),
                subtitle: Text(lastMessageText),
              );
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  debugPrint('Error fetching user $otherUserId: ${userSnapshot.error}');
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('User error'),
                    subtitle: Text(lastMessageText),
                  );
                }

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  // small placeholder while user doc loads
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Loading...'),
                    subtitle: Text(lastMessageText),
                  );
                }

                if (!userSnapshot.hasData || !(userSnapshot.data!.exists)) {
                  debugPrint("⚠️ User doc missing for $otherUserId");
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(otherUserId), // show UID instead of Unknown
                    subtitle: Text(lastMessageText),
                  );
                }


                final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final username = (userData['username'] ?? userData['email']?.split('@')?.first ?? 'User').toString();
                final email = (userData['email'] ?? '').toString();
                final profilePic = (userData['profilePic'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profilePic.isNotEmpty
                          ? NetworkImage(profilePic)
                          : const AssetImage('assets/images/user.png') as ImageProvider,
                      radius: 24,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: UserStatusIndicator(userId: otherUserId, showText: false, size: 12),
                      ),
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      lastMessageText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            receiverUserEmail: email,
                            receiverUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _extractLastMessageText(dynamic lastMessageField) {
    // handle different stored shapes (Map, String, null)
    try {
      if (lastMessageField == null) return '';
      if (lastMessageField is String) return lastMessageField;
      if (lastMessageField is Map) {
        // common keys that might contain text
        final map = Map<String, dynamic>.from(lastMessageField);
        return (map['message'] ?? map['text'] ?? map['content'] ?? map['body'] ?? '').toString();
      }
      // fallback
      return lastMessageField.toString();
    } catch (e) {
      debugPrint('Failed to parse lastMessage: $e');
      return '';
    }
  }




  /// --- Story Avatar Widget (unchanged) ---
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
