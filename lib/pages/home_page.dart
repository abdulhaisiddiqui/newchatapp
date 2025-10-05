import 'package:chatapp/pages/story_upload_page.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/story/story_service.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';

import '../services/story/story_viewer.dart';
import '../services/chat/chat_service.dart';
import '../services/secure_storage_service.dart';
import 'chat_page_chatview.dart';
import 'group_chat_page.dart';
import '../components/user_status_indicator.dart';
import 'contact_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const historyLength = 5;

  List<String> _searchHistory = [];
  String selectedTerm = '';

  List<String> filteredSearchHistory = [];
  List<Map<String, dynamic>> filteredUsers = [];

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

  List<String> addSearchTerm(String term) {
    if (_searchHistory.contains(term)) {
      putSearchTermFirst(term);
      return _searchHistory;
    }

    _searchHistory.add(term);
    if (_searchHistory.length > historyLength) {
      _searchHistory.removeRange(0, _searchHistory.length - historyLength);
    }

    filteredSearchHistory = filterSearchTerms(filter: null);
    return _searchHistory;
  }

  void deleteSearchTerm(String term) {
    _searchHistory.removeWhere((t) => t == term);
    filteredSearchHistory = filterSearchTerms(filter: null);
  }

  void putSearchTermFirst(String term) {
    deleteSearchTerm(term);
    addSearchTerm(term);
  }

  List<String> filterSearchTerms({required String? filter}) {
    if (filter != null && filter.isNotEmpty) {
      return _searchHistory.reversed
          .where((term) => term.toLowerCase().contains(filter.toLowerCase()))
          .toList();
    } else {
      return _searchHistory.reversed.toList();
    }
  }

  void addFilteredUsers(List<Map<String, dynamic>> users) {
    filteredUsers = users;
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      // Search users by username or email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '${query}\uf8ff')
          .limit(10)
          .get();

      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: '${query}\uf8ff')
          .limit(10)
          .get();

      final users = <Map<String, dynamic>>[];

      // Add users from username query
      for (var doc in userQuery.docs) {
        if (doc.id != currentUserId) {
          final userData = doc.data();
          userData['id'] = doc.id;
          users.add(userData);
        }
      }

      // Add users from email query (avoid duplicates)
      for (var doc in emailQuery.docs) {
        if (doc.id != currentUserId && !users.any((u) => u['id'] == doc.id)) {
          final userData = doc.data();
          userData['id'] = doc.id;
          users.add(userData);
        }
      }

      return users;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
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

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      // Fetch user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      return userDoc.exists ? userDoc.data() ?? {} : {};
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ChatApp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                );
              },
              icon: const Icon(Icons.group_add, color: Colors.white),
              tooltip: 'Create Group',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              backgroundImage: const AssetImage('assets/images/user.png'),
              radius: 18,
              backgroundColor: Colors.transparent,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: signOut,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Sign Out',
            ),
          ),
        ],
      ),
      body: FloatingSearchBar(
        hint: 'Search users and groups...',
        hintStyle: const TextStyle(color: Colors.grey),
        queryStyle: const TextStyle(color: Colors.white),
        backgroundColor: const Color(0xFF1A1A1A),
        backdropColor: Colors.black.withOpacity(0.5),
        scrollPadding: const EdgeInsets.only(top: 16, bottom: 80),
        transitionDuration: const Duration(milliseconds: 600),
        transitionCurve: Curves.easeInOut,
        physics: const BouncingScrollPhysics(),
        axisAlignment: isPortrait ? 0.0 : -1.0,
        openAxisAlignment: 0.0,
        width: isPortrait ? 600 : 500,
        debounceDelay: const Duration(milliseconds: 500),
        onQueryChanged: (query) {
          setState(() {
            filteredSearchHistory = filterSearchTerms(filter: query);
          });
        },
        onSubmitted: (query) async {
          setState(() {
            addSearchTerm(query);
            selectedTerm = query;
          });

          // Search for users
          final users = await searchUsers(query);
          setState(() {
            addFilteredUsers(users);
          });
        },
        transition: CircularFloatingSearchBarTransition(),
        actions: [
          FloatingSearchBarAction(
            showIfOpened: false,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
          FloatingSearchBarAction.searchToClear(showIfClosed: false),
        ],
        builder: (context, transition) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: const Color(0xFF1A1A1A),
              elevation: 8.0,
              shadowColor: Colors.black.withOpacity(0.3),
              child: Builder(
                builder: (context) {
                  if (filteredUsers.isEmpty && selectedTerm.isEmpty) {
                    return Container(
                      height: 56,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Start typing to search users...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  if (filteredUsers.isEmpty && selectedTerm.isNotEmpty) {
                    return Container(
                      height: 56,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'No users found for "$selectedTerm"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: filteredUsers
                        .map(
                          (user) => Container(
                            height: 72,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  radius: 18,
                                  child: ClipOval(
                                    child: user['profilePic'] != null
                                        ? CachedNetworkImage(
                                            imageUrl: user['profilePic'],
                                            fit: BoxFit.cover,
                                            width: 32,
                                            height: 32,
                                            placeholder: (context, url) =>
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                                      Icons.person,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                          )
                                        : Image.asset(
                                            'assets/images/user.png',
                                            width: 32,
                                            height: 32,
                                          ),
                                  ),
                                ),
                              ),
                              title: Text(
                                user['username'] ??
                                    user['email']?.split('@').first ??
                                    'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                user['email'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                // Start chat with this user
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPageChatView(
                                      receiverUserId: user['id'],
                                      receiverUserEmail: user['email'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          );
        },
        body: Column(
          children: [
            // 👇 Stories Section
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Container(
                height: 110,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                child: Row(
                  children: [
                    // --- My Status Button ---
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoryUploadPage(),
                          ),
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
                        stream: StoryService().getVisibleStories(
                          _auth.currentUser!.uid,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text(
                              "No statuses from your chats",
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          final stories = snapshot.data!;

                          return SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: stories.length,
                              itemBuilder: (context, index) {
                                final userStory =
                                    stories[index]; // ek user ka full bundle
                                final username =
                                    userStory["username"] ?? "User";

                                // user ke subcollection ka sabse naya story
                                final List<dynamic> userStories =
                                    userStory["stories"];
                                final latest =
                                    userStories.first; // already orderBy(desc)

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoryViewerPage(
                                          userData: userStory,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey[300],
                                        child: ClipOval(
                                          child: latest["type"] == "image"
                                              ? CachedNetworkImage(
                                                  imageUrl: latest["url"],
                                                  fit: BoxFit.cover,
                                                  width: 60,
                                                  height: 60,
                                                  placeholder: (context, url) =>
                                                      const CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                            Icons.image,
                                                            size: 30,
                                                          ),
                                                )
                                              : latest["type"] == "text"
                                              ? Container(
                                                  width: 60,
                                                  height: 60,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.blue,
                                                        Colors.purple,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    latest["text"] ?? "",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  size: 30,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
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
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: _buildChatList(),
                ),
              ),
            ),
          ],
        ),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading chats:\n$err',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No chats yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final chatRoom = docs[index];
            // defensive extraction of data
            final raw = chatRoom.data() as Map<String, dynamic>? ?? {};

            // members may be List<dynamic>, convert safely to List<String>
            List<String> members = [];
            if (raw['members'] != null && raw['members'] is List) {
              members = (raw['members'] as List)
                  .map((e) => e.toString())
                  .toList();
            }

            // Check if this is a group chat
            final chatType = raw['chatType'] as String? ?? 'direct';
            final isGroupChat = chatType == 'group';
            final groupName = raw['groupName'] as String?;
            final groupAvatar = raw['groupAvatar'] as String?;

            // find other user id (for direct chats only)
            final currentUid = _auth.currentUser?.uid ?? '';
            String otherUserId = '';
            if (!isGroupChat && members.length >= 2) {
              otherUserId = members.firstWhere(
                (id) => id != currentUid,
                orElse: () => members.first,
              );
            }

            // extract lastMessage safely (it may be Map or String)
            String lastMessageText = _extractLastMessageText(
              raw['lastMessage'],
            );

            // Get unread count from chat room document
            final unreadCountMap =
                raw['unreadCount'] as Map<String, dynamic>? ?? {};
            final currentUserId = _auth.currentUser?.uid ?? '';
            final unreadCount = (unreadCountMap[currentUserId] as int?) ?? 0;

            // Handle group chats vs direct chats
            if (isGroupChat) {
              // Group chat display
              final displayName = groupName ?? 'Group Chat';
              final displayAvatar = groupAvatar ?? '';
              final memberCount = members.length;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 16,
                ),
                child: ListTile(
                  leading: badges.Badge(
                    showBadge: unreadCount > 0,
                    badgeContent: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: Colors.red,
                      padding: EdgeInsets.all(6),
                    ),
                    position: badges.BadgePosition.topEnd(top: -8, end: -8),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      radius: 24,
                      child: displayAvatar.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: displayAvatar,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.group, size: 24),
                              ),
                            )
                          : const Icon(Icons.group, size: 24),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '$memberCount members • $lastMessageText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: unreadCount > 0 ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  onTap: () async {
                    // Mark messages as read when opening chat
                    if (unreadCount > 0) {
                      await ChatService().markMessagesAsRead(
                        chatRoom.id,
                        _auth.currentUser!.uid,
                      );
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupChatPage(
                          groupId: chatRoom.id,
                          groupName: displayName,
                          memberIds: members,
                          groupImage: displayAvatar,
                        ),
                      ),
                    );
                  },
                ),
              );
            } else {
              // Direct chat display (existing logic)
              if (otherUserId.isEmpty) {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text(
                    'Unknown',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    lastMessageText,
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _getUserData(otherUserId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    debugPrint(
                      'Error fetching data for $otherUserId: ${userSnapshot.error}',
                    );
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text(
                        'Error loading',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        lastMessageText,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text('Loading...'),
                      subtitle: Text(lastMessageText),
                    );
                  }

                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        otherUserId,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        lastMessageText,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final userData = userSnapshot.data!;
                  final username =
                      (userData['username'] ??
                              userData['email']?.split('@')?.first ??
                              'User')
                          .toString();
                  final email = (userData['email'] ?? '').toString();
                  final profilePic = (userData['profilePic'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 16,
                    ),
                    child: ListTile(
                      leading: badges.Badge(
                        showBadge: unreadCount > 0,
                        badgeContent: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        badgeStyle: const badges.BadgeStyle(
                          badgeColor: Colors.red,
                          padding: EdgeInsets.all(6),
                        ),
                        position: badges.BadgePosition.topEnd(top: -8, end: -8),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: 24,
                          child: Stack(
                            children: [
                              ClipOval(
                                child: profilePic.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: profilePic,
                                        fit: BoxFit.cover,
                                        width: 48,
                                        height: 48,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                              'assets/images/user.png',
                                              width: 48,
                                              height: 48,
                                            ),
                                      )
                                    : Image.asset(
                                        'assets/images/user.png',
                                        width: 48,
                                        height: 48,
                                      ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: UserStatusIndicator(
                                  userId: otherUserId,
                                  showText: false,
                                  size: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      title: Text(
                        username,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: unreadCount > 0
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                      onTap: () async {
                        // Mark messages as read when opening chat
                        if (unreadCount > 0) {
                          await ChatService().markMessagesAsRead(
                            chatRoom.id,
                            _auth.currentUser!.uid,
                          );
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPageChatView(
                              receiverUserId: otherUserId,
                              receiverUserEmail: email,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
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
