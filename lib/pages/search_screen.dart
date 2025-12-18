import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatapp/pages/chat_page_chatview.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // 🔹 TODO: Replace with actual Firestore/API data
  // Example: Stream<QuerySnapshot> or List fetched from backend
  final List<Map<String, dynamic>> _dummyPeople = [
    {
      "name": "Adil Adnan",
      "status": "Be your own hero 💪",
      "avatar": "https://i.pravatar.cc/150?img=1",
    },
    {
      "name": "Bristy Haque",
      "status": "Keep working 💪",
      "avatar": "https://i.pravatar.cc/150?img=5",
    },
    {
      "name": "John Borino",
      "status": "Make yourself proud 😍",
      "avatar": "https://i.pravatar.cc/150?img=3",
    },
  ];

  final List<Map<String, dynamic>> _dummyGroups = [
    {
      "name": "Team Align-Practise",
      "participants": 4,
      "avatars": [
        "https://i.pravatar.cc/150?img=10",
        "https://i.pravatar.cc/150?img=11",
      ],
    },
    {
      "name": "Team Align",
      "participants": 8,
      "avatars": [
        "https://i.pravatar.cc/150?img=20",
        "https://i.pravatar.cc/150?img=21",
        "https://i.pravatar.cc/150?img=22",
      ],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600], size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "People",
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                              onChanged: (value) {
                                _searchUsers(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey[700], size: 28),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (_searchResults.isNotEmpty) ...[
                          const Text(
                            "People",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._searchResults.map((user) {
                            return _buildPersonTile(
                              name: user["username"] ?? '',
                              status: user["email"] ?? '',
                              avatar: user["profilePic"] ?? '',
                              uid: user["uid"] ?? '',
                            );
                          }).toList(),
                        ] else if (_searchController.text.isNotEmpty) ...[
                          const Center(
                            child: Text(
                              "No users found",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ] else ...[
                          // Show recent or something, but for now empty
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonTile({
    required String name,
    required String status,
    required String avatar,
    required String uid,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPageChatView(
              receiverUserEmail: status,
              receiverUserId: uid,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatar,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.person, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile({
    required String name,
    required int participants,
    required List<String> avatars,
  }) {
    return InkWell(
      // 🔹 TODO: Navigate to group chat screen
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(...));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Group avatar stack
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                children: [
                  if (avatars.isNotEmpty)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatars[0],
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 20),
                          ),
                        ),
                      ),
                    ),
                  if (avatars.length > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatars[1],
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 20),
                          ),
                        ),
                      ),
                    ),
                  if (avatars.length > 2)
                    Positioned(
                      left: 16,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey[300],
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatars[2],
                            fit: BoxFit.cover,
                            width: 28,
                            height: 28,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$participants participants",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      setState(() {
        _searchResults = result.docs.map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }
}
