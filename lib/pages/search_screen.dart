import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

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
                              // 🔹 TODO: Implement search functionality
                              onChanged: (value) {
                                // Filter people/groups based on search query
                                // Example: _searchUsers(value);
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // People section
                  const Text(
                    "People",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔹 TODO: Replace with StreamBuilder or FutureBuilder
                  // Example: StreamBuilder<QuerySnapshot>(...)
                  ..._dummyPeople.map((person) {
                    return _buildPersonTile(
                      name: person["name"],
                      status: person["status"],
                      avatar: person["avatar"],
                    );
                  }).toList(),

                  const SizedBox(height: 24),

                  // Group Chat section
                  const Text(
                    "Group Chat",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔹 TODO: Replace with StreamBuilder or FutureBuilder for groups
                  ..._dummyGroups.map((group) {
                    return _buildGroupTile(
                      name: group["name"],
                      participants: group["participants"],
                      avatars: group["avatars"],
                    );
                  }).toList(),

                  const SizedBox(height: 20),
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
  }) {
    return InkWell(
      // 🔹 TODO: Navigate to chat or profile screen
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(...));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(avatar),
              backgroundColor: Colors.grey[300],
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
                        backgroundImage: NetworkImage(avatars[0]),
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                  if (avatars.length > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(avatars[1]),
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                  if (avatars.length > 2)
                    Positioned(
                      left: 16,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(avatars[2]),
                        backgroundColor: Colors.grey[300],
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

  // 🔹 TODO: Implement backend search methods
  /*
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      // Show all users or clear results
      return;
    }
    
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      setState(() {
        // Update your search results
      });
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }
  
  Future<void> _searchGroups(String query) async {
    // Similar implementation for groups
  }
  */
}
