import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chatapp/model/message.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/pages/image_viewer_page.dart';
import 'package:flutter/foundation.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;
  final String username;
  final String profilePic;
  final String chatRoomId;

  const UserProfilePage({
    Key? key,
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.chatRoomId,
  }) : super(key: key);

  Stream<List<Message>> _getSharedMedia() {
    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('fileAttachment', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) {
      final messages = <Message>[];
      for (var doc in snapshot.docs) {
        try {
          final message = Message.fromMap(doc.data());
          if (message.fileAttachment != null &&
              (message.fileAttachment!.mimeType.startsWith('image/') ||
                  message.fileAttachment!.mimeType.startsWith('video/') ||
                  message.fileAttachment!.mimeType.startsWith('application/'))) {
            messages.add(message);
          }
        } catch (e) {
          debugPrint('Error parsing message ${doc.id}: $e');
          debugPrint('Problematic document data: ${doc.data()}');
        }
      }
      return messages;
    });
  }

  void _openMediaViewer(BuildContext context, String mediaUrl, List<String> mediaUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerPage(
          imageUrls: mediaUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF0A3D2E),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(String imageUrl, String? overlayText, {VoidCallback? onTap}) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFE0E0E0),
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: overlayText != null
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.6),
        ),
        child: Center(
          child: Text(
            overlayText,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041C15),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Profile Section
              Container(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                  builder: (context, snapshot) {
                    String email = 'Unknown';
                    String address = 'Not provided';
                    String phoneNumber = 'Not provided';
                    bool isOnline = false;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      email = userData['email'] ?? 'Unknown';
                      address = userData['address'] ?? 'Not provided';
                      phoneNumber = userData['phoneNumber'] ?? 'Not provided';
                      isOnline = userData['isOnline'] ?? false;
                    }

                    return Column(
                      children: [
                        // Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8B55B),
                            image: profilePic.isNotEmpty
                                ? DecorationImage(
                              image: NetworkImage(profilePic),
                              fit: BoxFit.cover,
                            )
                                : const DecorationImage(
                              image: AssetImage('assets/images/user.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Username (Handle)
                        Text(
                          '@$username',
                          style: const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                        ),
                        const SizedBox(height: 8),

                        // Status
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(Icons.chat_bubble_outline, () {
                              // Navigate back to ChatPage
                              Navigator.pop(context);
                            }),
                            const SizedBox(width: 32),
                            _buildActionButton(Icons.videocam_outlined, () {
                              // TODO: Implement video call
                            }),
                            const SizedBox(width: 32),
                            _buildActionButton(Icons.call_outlined, () {
                              // TODO: Implement voice call
                            }),
                            const SizedBox(width: 32),
                            _buildActionButton(Icons.more_horiz, () {
                              // TODO: Implement more options (e.g., block, report)
                            }),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Info Card
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoField('Display Name', username),
                      const SizedBox(height: 24),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                        builder: (context, snapshot) {
                          String email = 'Unknown';
                          String address = 'Not provided';
                          String phoneNumber = 'Not provided';

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            email = userData['email'] ?? 'Unknown';
                            address = userData['address'] ?? 'Not provided';
                            phoneNumber = userData['phoneNumber'] ?? 'Not provided';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoField('Email Address', email),
                              const SizedBox(height: 24),
                              _buildInfoField('Address', address),
                              const SizedBox(height: 24),
                              _buildInfoField('Phone Number', phoneNumber),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Media Section
                      StreamBuilder<List<Message>>(
                        stream: _getSharedMedia(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            debugPrint('StreamBuilder error: ${snapshot.error}');
                            return Center(child: Text('Error loading media: ${snapshot.error}'));
                          }
                          final mediaMessages = snapshot.data ?? [];
                          if (mediaMessages.isEmpty) {
                            return const Center(child: Text('No shared media'));
                          }

                          final mediaUrls = mediaMessages
                              .where((msg) => msg.fileAttachment!.mimeType.startsWith('image/'))
                              .map((msg) => msg.fileAttachment!.downloadUrl)
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Media Shared',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // TODO: Navigate to a full media view screen
                                    },
                                    child: Text(
                                      'View All',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF00BFA6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: mediaMessages.isNotEmpty
                                        ? _buildMediaItem(
                                      mediaMessages[0].fileAttachment!.downloadUrl,
                                      null,
                                      onTap: () => _openMediaViewer(
                                        context,
                                        mediaMessages[0].fileAttachment!.downloadUrl,
                                        mediaUrls,
                                        0,
                                      ),
                                    )
                                        : Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: mediaMessages.length > 1
                                        ? _buildMediaItem(
                                      mediaMessages[1].fileAttachment!.downloadUrl,
                                      null,
                                      onTap: () => _openMediaViewer(
                                        context,
                                        mediaMessages[1].fileAttachment!.downloadUrl,
                                        mediaUrls,
                                        1,
                                      ),
                                    )
                                        : Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: mediaMessages.length > 2
                                        ? _buildMediaItem(
                                      mediaMessages[2].fileAttachment!.downloadUrl,
                                      mediaMessages.length > 3 ? '${mediaMessages.length - 2}+' : null,
                                      onTap: () => _openMediaViewer(
                                        context,
                                        mediaMessages[2].fileAttachment!.downloadUrl,
                                        mediaUrls,
                                        2,
                                      ),
                                    )
                                        : Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}