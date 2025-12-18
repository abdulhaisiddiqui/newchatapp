import 'package:chatapp/pages/chat_page_chatview.dart';
import 'package:chatapp/pages/create_group_page.dart';
import 'package:chatapp/pages/group_chat_page.dart';
import 'package:chatapp/pages/search_screen.dart';
import 'package:chatapp/pages/setting_screen2.dart';
import 'package:chatapp/pages/story_upload_page.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/story/story_service.dart';
import 'package:chatapp/services/story/story_viewer.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../components/user_status_indicator.dart';
import '../services/chat/chat_service.dart';
import '../services/secure_storage_service.dart';
import 'contact_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Start monitoring online presence
    UserStatusService().initializePresenceMonitoring();
  }

  @override
  void dispose() {
    // Cleanup presence monitoring
    UserStatusService().dispose();
    super.dispose();
  }

  // Sign user out
  void signOut() async {
    // Set user offline before signing out
    await UserStatusService().setUserOffline();

    // Clear secure storage data
    await SecureStorageService().clearAuthData();

    final authService = Provider.of<AuthService>(context, listen: false);
    authService.signOut();
  }

  Stream<QuerySnapshot> getChatRooms() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('members', arrayContains: currentUid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFF000E08),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40), // status bar ke liye space
              // 🔹 Custom Header (AppBar movedinside body)
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🔍 Search Button
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                      ),

                      // 🏠 Title
                      const Text(
                        'Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // 👤 Profile + Logout Row
                      Row(
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser!.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  !snapshot.data!.exists) {
                                return const CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage(
                                    'assets/images/user.png',
                                  ),
                                );
                              }

                              final userData =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final imageUrl = userData['profilePic'] ?? '';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SettingScreen2(),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: imageUrl.isNotEmpty
                                      ? NetworkImage(imageUrl)
                                      : const AssetImage(
                                              'assets/images/user.png',
                                            )
                                            as ImageProvider,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 👇 Stories Section
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  height: 110,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: StoryService().getVisibleStories(
                      _auth.currentUser!.uid,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<Map<String, dynamic>> stories = [];
                      if (snapshot.hasData) {
                        stories = snapshot.data!;
                        // Sort unseen first
                        stories.sort((a, b) {
                          final aSeen = a["isSeen"] ?? false;
                          final bSeen = b["isSeen"] ?? false;
                          return aSeen == bSeen ? 0 : (aSeen ? 1 : -1);
                        });
                      }

                      final allStories = [
                        {"username": "My Status", "isMyStatus": true},
                        ...stories,
                      ];

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allStories.length,
                        itemBuilder: (context, index) {
                          final story = allStories[index];
                          final isMyStatus = story["isMyStatus"] == true;

                          if (isMyStatus) {
                            return const MyStatusWidget();
                          } else {
                            final username = story["username"] ?? "User";
                            final List<dynamic> userStories = story["stories"];
                            final latest = userStories.first;
                            final bool isSeen = story["isSeen"] ?? false;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StoryViewerPage(userData: story),
                                  ),
                                ).then((_) async {
                                  for (var s in userStories) {
                                    await StoryService().markStoryAsViewed(
                                      story["userId"],
                                      s["storyId"],
                                    );
                                  }
                                });
                              },
                              child: storyAvatar(
                                username,
                                'assets/images/user.png',
                                isSeen: isSeen,
                                imageUrl: latest["type"] == "image"
                                    ? latest["url"]
                                    : null,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ),

              // 👇 Firestore Chat List
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
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
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'new_chat', // Unique tag to avoid Hero animation conflicts
            backgroundColor: const Color(0XFF24786D),
            onPressed: () {
              // Action for starting a new chat
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContactScreen()),
              );
            },
            child: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'New Chat',
          ),
          const SizedBox(height: 16), // Spacing between FABs
          FloatingActionButton(
            heroTag: 'new_group', // Unique tag for second FAB
            backgroundColor: const Color(0XFF20A065),
            onPressed: () {
              // Action for creating a group chat or another feature
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateGroupPage()),
              );
            },
            child: const Icon(Icons.group_add, color: Colors.white),
            tooltip: 'New Group',
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final currentUid = _auth.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading chats: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }

        // 🔹 Filter out hidden chats
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
          return !hiddenFor.contains(currentUid);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No visible chats'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chatRoom = docs[index];
            final raw = chatRoom.data() as Map<String, dynamic>? ?? {};

            final isGroup = raw['isGroup'] == true;
            if (isGroup) {
              final groupName = raw['name'] ?? 'Unnamed Group';
              final description = raw['description'] ?? '';

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.group)),
                title: Text(groupName),
                subtitle: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatPage(
                        groupId: chatRoom.id,
                        groupName: groupName,
                        description: description,
                      ),
                    ),
                  );
                },
              );
            }

            List<String> members = [];
            if (raw['members'] != null && raw['members'] is List) {
              members = (raw['members'] as List)
                  .map((e) => e.toString())
                  .toList();
            }

            String otherUserId;
            if (members.isEmpty) {
              otherUserId = '';
            } else if (members.length == 1) {
              otherUserId = members.first;
            } else {
              otherUserId = members.firstWhere(
                (id) => id != currentUid,
                orElse: () => members.first,
              );
            }

            String lastMessageText = _extractLastMessageText(
              raw['lastMessage'],
            );

            if (otherUserId.isEmpty) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('Unknown'),
                subtitle: Text(lastMessageText),
              );
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('User error'),
                    subtitle: Text(lastMessageText),
                  );
                }

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(child: Icon(Icons.person)),
                    title: Text('Loading...'),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(otherUserId),
                    subtitle: Text(lastMessageText),
                  );
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final String username =
                    (userData['username'] ??
                            userData['email']?.split('@')?.first ??
                            'User')
                        .toString();
                final String email = (userData['email'] ?? '').toString();
                final String profilePic = (userData['profilePic'] ?? '')
                    .toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 16,
                  ),
                  child: Slidable(
                    key: ValueKey(userData['uid'] ?? otherUserId),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        CustomSlidableAction(
                          flex: 1,
                          onPressed: (context) async {
                            // 🔔 Notification button
                            debugPrint('🔔 Notification pressed for $username');
                          },
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
                                child: const Icon(
                                  Icons.notifications,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 20),
                              // 🗑️ DELETE (Hide chat)
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('chat_rooms')
                                        .doc(chatRoom.id)
                                        .update({
                                          'hiddenFor': FieldValue.arrayUnion([
                                            currentUid,
                                          ]),
                                        });
                                    debugPrint(
                                      '🗑️ Chat hidden for user $currentUid',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Chat with $username removed from home',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('❌ Error hiding chat: $e');
                                  }
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection('chat_rooms')
                            .doc(chatRoom.id)
                            .update({'unreadCount.$currentUid': 0});

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPageChatView(
                              receiverUserEmail: email,
                              receiverUserId: otherUserId,
                            ),
                          ),
                        );
                      },
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : const AssetImage('assets/images/user.png')
                                      as ImageProvider,
                            radius: 25,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: UserStatusIndicator(
                              userId: otherUserId,
                              showText: false,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (raw['unreadCount'] != null &&
                              raw['unreadCount'][currentUid] != null &&
                              raw['unreadCount'][currentUid] > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                raw['unreadCount'][currentUid].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        lastMessageText,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
        return (map['message'] ??
                map['text'] ??
                map['content'] ??
                map['body'] ??
                '')
            .toString();
      }
      // fallback
      return lastMessageField.toString();
    } catch (e) {
      debugPrint('Failed to parse lastMessage: $e');
      return '';
    }
  }
}

/// --- Story Avatar Widget ---
Widget storyAvatar(
  String name,
  String imagePath, {
  Color bgColor = Colors.grey,
  bool showOverlay = false,
  bool isSeen = false,
  bool showBorder = true,
  String? imageUrl,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: showBorder
                ? (isSeen
                      ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                      : const LinearGradient(
                          colors: [Color(0XFF24786D), Color(0XFF24786D)],
                        ))
                : const LinearGradient(
                    colors: [Colors.transparent, Colors.transparent],
                  ),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.black,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : AssetImage(imagePath) as ImageProvider,
            child: showOverlay
                ? const Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.add, color: Colors.black, size: 14),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 70,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class MyStatusWidget extends StatefulWidget {
  const MyStatusWidget({super.key});

  @override
  State<MyStatusWidget> createState() => _MyStatusWidgetState();
}

class _MyStatusWidgetState extends State<MyStatusWidget> {
  String? profilePicUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfilePic();
  }

  Future<void> _loadProfilePic() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        setState(() {
          profilePicUrl = doc.data()?['profilePic'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('⚠️ Error loading profilePic: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 60,
        height: 60,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StoryUploadPage()),
        );
      },
      child: storyAvatar(
        'My Status',
        'assets/images/user.png',
        imageUrl: profilePicUrl,
        showOverlay: true,
        showBorder: false,
      ),
    );
  }
}
