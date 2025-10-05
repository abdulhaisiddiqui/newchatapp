import 'package:chatapp/pages/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sentry/sentry.dart';

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
                              backgroundColor: Colors.grey[300],
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: profilePic,
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.person, size: 35),
                                ),
                              ),
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
                        Icons.security,
                        "Permissions",
                        "Camera, microphone, storage access",
                        onTap: () => _showPermissionsDialog(context),
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
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Developer Options',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      buildSettingsTile(
                        Icons.bug_report,
                        "Debug & Testing",
                        "Test error reporting and diagnostics",
                        onTap: () => _showDebugDialog(context),
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

  void _showPermissionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Permissions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPermissionTile('Camera', Permission.camera),
            _buildPermissionTile('Microphone', Permission.microphone),
            _buildPermissionTile('Storage', Permission.storage),
            _buildPermissionTile('Photos', Permission.photos),
            const SizedBox(height: 16),
            const Text(
              'These permissions are required for media sharing, voice messages, and calls.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug & Testing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use these tools to test error reporting and diagnostics.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Create intentional error for Sentry testing
                try {
                  throw StateError(
                    'This is a test exception for Sentry verification',
                  );
                } catch (exception, stackTrace) {
                  await Sentry.captureException(
                    exception,
                    stackTrace: stackTrace,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test error sent to Sentry!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Test Error to Sentry'),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will create a test exception and send it to Sentry for verification.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(String name, Permission permission) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isGranted = status?.isGranted ?? false;
        final isDenied = status?.isDenied ?? false;

        return ListTile(
          title: Text(name),
          subtitle: Text(
            isGranted
                ? 'Granted'
                : isDenied
                ? 'Denied'
                : 'Not requested',
            style: TextStyle(
              color: isGranted ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            isGranted ? Icons.check_circle : Icons.error,
            color: isGranted ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }

  // 🔹 Helper widget for settings options
  Widget buildSettingsTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: Icon(icon, color: Colors.green),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      onTap: onTap ?? () {},
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : null,
    );
  }
}
