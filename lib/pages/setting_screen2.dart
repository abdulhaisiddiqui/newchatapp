import 'package:chatapp/pages/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import '../services/auth/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/user/user_status_service.dart';
import 'profile_screen2.dart';

class SettingScreen2 extends StatelessWidget {
  const SettingScreen2({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (snapshot.exists) {
      return snapshot.data();
    }
    return null;
  }

  void signOut(BuildContext context) async {
    // Set user offline before signing out
    await UserStatusService().setUserOffline();

    // Clear secure storage data
    await SecureStorageService().clearAuthData();

    final authService = Provider.of<AuthService>(context, listen: false);
    authService.signOut();
  }

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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Center(
                  child: Text(
                    "Settings",
                    style: TextStyle(
                      color: Color(0XFFFFFFFF),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
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
                  final profilePic = userData["profilePic"] ??
                      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQxSFDJsQuUfNJriz0KiaTD28GR82xL1fW-nvsEF9GwaI_sq6SkPloo&usqp=CAE&s";

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
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
                                      builder: (context) => ProfileScreen2(),
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
                              icon: const Icon(Icons.qr_code,
                                  color: Colors.green),
                            )
                          ],
                        ),
                      ),
                      buildSettingsTile(Icons.key, "Account",
                          "Privacy, security, change number"),
                      buildSettingsTile(Icons.chat, "Chat",
                          "Chat history, theme, wallpapers"),
                      buildSettingsTile(Icons.notifications, "Notifications",
                          "Messages, group and others"),
                      buildSettingsTile(Icons.help_outline, "Help",
                          "Help center, contact us, privacy policy"),
                      buildSettingsTile(Icons.storage, "Storage and data",
                          "Network usage, storage usage"),
                      buildSettingsTile(Icons.group_add, "Invite a friend", ""),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => signOut(context),
                        icon: const Icon(Icons.logout, color: Colors.black),
                      ),
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
