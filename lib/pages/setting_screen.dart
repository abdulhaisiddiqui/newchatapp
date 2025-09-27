import 'package:chatapp/pages/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;
    final uid = currentUser.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (snapshot.exists) {
      return snapshot.data();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.only(top: 30)),

          // 👇 White Container with Settings List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text("User data not found"));
                  }

                  final userData = snapshot.data!;
                  final username = userData["username"] ?? userData["email"];
                  final profilePic =
                      userData["profilePic"] ??
                      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQxSFDJsQuUfNJriz0KiaTD28GR82xL1fW-nvsEF9GwaI_sq6SkPloo&usqp=CAE&s"; // default avatar

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: NetworkImage(profilePic),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Never give up 💪",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.qr_code,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      buildSettingsTile(
                        Icons.key,
                        "Account",
                        "Privacy, security, change number",
                      ),
                      buildSettingsTile(
                        Icons.chat,
                        "Chat",
                        "Chat history, theme, wallpapers",
                      ),
                      buildSettingsTile(
                        Icons.notifications,
                        "Notifications",
                        "Messages, group and others",
                      ),
                      buildSettingsTile(
                        Icons.help_outline,
                        "Help",
                        "Help center, contact us, privacy policy",
                      ),
                      buildSettingsTile(
                        Icons.storage,
                        "Storage and data",
                        "Network usage, storage usage",
                      ),
                      buildSettingsTile(Icons.group_add, "Invite a friend", ""),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Helper widget for settings options
  Widget buildSettingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: Icon(icon, color: Colors.green),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      onTap: () {},
    );
  }
}
