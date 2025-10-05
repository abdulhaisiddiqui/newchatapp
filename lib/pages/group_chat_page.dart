import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chatview/chatview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatapp/components/file_selection_dialog.dart';
import 'package:chatapp/services/file/file_service.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<String> memberIds;
  final String groupImage;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.memberIds,
    required this.groupImage,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  late ChatController _chatController;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _imagePicker = ImagePicker();
  final _fileService = FileService();

  List<ChatUser> _chatUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadGroupMembers();
    _setupChatController();
    _listenForMessages();
  }

  Future<void> _loadGroupMembers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _chatUsers = [];

    // Add current user
    _chatUsers.add(
      ChatUser(
        id: currentUser.uid,
        name:
            currentUser.displayName ??
            currentUser.email?.split('@').first ??
            'You',
        profilePhoto: currentUser.photoURL,
      ),
    );

    // Add other members
    for (final memberId in widget.memberIds) {
      if (memberId == currentUser.uid) continue;

      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _chatUsers.add(
            ChatUser(
              id: memberId,
              name:
                  userData['username'] ??
                  userData['email']?.split('@').first ??
                  'User',
              profilePhoto: userData['profilePic'],
            ),
          );
        }
      } catch (e) {
        debugPrint('Error loading member $memberId: $e');
      }
    }
  }

  void _setupChatController() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      currentUser: ChatUser(
        id: currentUser.uid,
        name:
            currentUser.displayName ??
            currentUser.email?.split('@').first ??
            'You',
        profilePhoto: currentUser.photoURL,
      ),
      otherUsers: _chatUsers
          .where((user) => user.id != currentUser.uid)
          .toList(),
    );

    setState(() => _isLoading = false);
  }

  void _listenForMessages() {
    _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
          final messages = <Message>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final senderId = data['senderId'] ?? '';

            // Find the chat user for this sender
            final chatUser = _chatUsers.firstWhere(
              (user) => user.id == senderId,
              orElse: () => ChatUser(id: senderId, name: 'Unknown'),
            );

            MessageType messageType;
            switch (data['messageType']) {
              case 'image':
                messageType = MessageType.image;
                break;
              case 'file':
                messageType = MessageType.custom;
                break;
              default:
                messageType = MessageType.text;
            }

            final message = Message(
              id: doc.id,
              message: data['message'] ?? '',
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              sentBy: senderId,
              messageType: messageType,
            );

            messages.add(message);
          }

          if (mounted) {
            setState(() {
              _chatController.initialMessageList
                ..clear()
                ..addAll(messages);
            });
          }
        });
  }

  Future<void> _sendMessage(
    String message,
    ReplyMessage replyMessage,
    MessageType type,
  ) async {
    if (message.trim().isEmpty && type == MessageType.text) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
          'senderId': currentUser.uid,
          'message': message,
          'messageType': type == MessageType.image
              ? 'image'
              : type == MessageType.custom
              ? 'file'
              : 'text',
          'createdAt': FieldValue.serverTimestamp(),
        });

    // Update group's last message
    await _firestore.collection('groups').doc(widget.groupId).update({
      'lastMessage': message,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      // Upload image first
      final result = await _fileService.uploadFile(
        file: File(pickedFile.path),
        chatRoomId: widget.groupId,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (result.isSuccess && result.fileId != null) {
        await _sendMessage(
          result.downloadUrl ?? pickedFile.path,
          ReplyMessage(),
          MessageType.image,
        );
      }
    } catch (e) {
      debugPrint('Error sending image: $e');
    }
  }

  Future<void> _sendFile() async {
    try {
      // Show file selection dialog
      showModalBottomSheet(
        context: context,
        builder: (context) => FileSelectionDialog(
          onFilesSelected: (files) async {
            Navigator.pop(context);
            for (final file in files) {
              final result = await _fileService.uploadFile(
                file: file,
                chatRoomId: widget.groupId,
                messageId: DateTime.now().millisecondsSinceEpoch.toString(),
              );

              if (result.isSuccess) {
                await _sendMessage(
                  file.path.split('/').last,
                  ReplyMessage(),
                  MessageType.custom,
                );
              }
            }
          },
          maxFiles: 5,
        ),
      );
    } catch (e) {
      debugPrint('Error sending file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF128C7E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: widget.groupImage.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.groupImage,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.group, size: 18),
                        ),
                      )
                    : const Icon(Icons.group, size: 18, color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${widget.memberIds.length} members",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Group settings
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
          color: const Color(0xFFECE5DD),
        ),
        child: Stack(
          children: [
            ChatView(
              chatController: _chatController,
              onSendTap: _sendMessage,
              chatViewState: ChatViewState.hasMessages,
              sendMessageConfig: SendMessageConfiguration(
                textFieldConfig: const TextFieldConfiguration(
                  textStyle: TextStyle(color: Colors.black),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF128C7E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _sendFile,
                  icon: const Icon(Icons.attach_file, color: Colors.white),
                  tooltip: 'Send files',
                  iconSize: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
