import 'package:chatapp/components/chat_bubble.dart';
import 'package:chatapp/components/file_picker_widget.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatapp/services/file/file_service.dart';
import 'package:chatapp/model/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String receiverUserEmail;
  final String receiverUserId;

  const ChatPage({
    super.key,
    required this.receiverUserEmail,
    required this.receiverUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FileService _fileService = FileService();

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        widget.receiverUserId,
        _messageController.text,
      );
      _messageController.clear();
    }
  }

  void _handleFileSelection(List<File> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      for (File file in files) {
        // Upload file
        final result = await _fileService.uploadFile(
          file: file,
          chatRoomId: _getChatRoomId(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
        );

        if (result.isSuccess && result.fileId != null) {
          // Get the file attachment from Firestore
          final fileAttachment = await _fileService.getFileMetadata(
            result.fileId!,
          );

          if (fileAttachment != null) {
            // Send file message using the new ChatService method
            String textMessage = _messageController.text.isNotEmpty
                ? _messageController.text
                : ''; // Empty string if no text, file will be the main content

            await _chatService.sendFileMessage(
              receiverId: widget.receiverUserId,
              fileAttachment: fileAttachment,
              textMessage: textMessage,
            );

            // Clear text only if it was used as caption
            if (_messageController.text.isNotEmpty) {
              _messageController.clear();
            }
          } else {
            _showErrorSnackBar('Failed to get file information');
          }
        } else {
          _showErrorSnackBar('Failed to upload file: ${result.error}');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading files: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  String _getChatRoomId() {
    List<String> ids = [_firebaseAuth.currentUser!.uid, widget.receiverUserId];
    ids.sort();
    return ids.join("_");
  }

  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Use custom AppBar design from MessageScreen
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            const CircleAvatar(
              backgroundImage: AssetImage('assets/images/profile-image.png'),
              radius: 20,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverUserEmail,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  "Active now",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam, color: Colors.black),
          ),
        ],
      ),

      body: Column(
        children: [
          // ✅ Chat Messages (Firestore Stream)
          Expanded(child: _buildMessageList()),

          // ✅ Bottom Input Bar (from MessageScreen)
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Semantics(
                  label: 'Attach files to message',
                  hint: 'Tap to select files, photos, or documents to share',
                  child: ChatFilePickerButton(
                    onFilesSelected: _handleFileSelection,
                    maxFiles: 5,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Message input field',
                            hint: 'Type your message here',
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: "Write your message",
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) =>
                                  _isUploading ? null : sendMessage(),
                            ),
                          ),
                        ),
                        if (_isUploading) ...[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: _isUploading ? null : sendMessage,
                          icon: const Icon(
                            Icons.send,
                            color: Colors.teal,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.black,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Icon(Icons.mic_none, color: Colors.black, size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Firestore Messages
  Widget _buildMessageList() {
    return StreamBuilder(
      stream: _chatService.getMessages(
        widget.receiverUserId,
        _firebaseAuth.currentUser!.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs
              .map((document) => _buildMessageItem(document))
              .toList(),
        );
      },
    );
  }

  // 🔹 Firestore Single Message
  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderId'] == _firebaseAuth.currentUser!.uid;

    // Convert Firestore data to Message object
    Message message = Message.fromMap(data);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ChatBubble(
        message: message,
        isCurrentUser: isCurrentUser,
        onFileDownload: () {
          // Handle file download
          if (message.fileAttachment != null) {
            _downloadFile(message.fileAttachment!);
          }
        },
      ),
    );
  }

  void _downloadFile(fileAttachment) async {
    try {
      final result = await _fileService.downloadFile(
        downloadUrl: fileAttachment.downloadUrl,
        fileName: fileAttachment.fileName,
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${fileAttachment.originalFileName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar('Download failed: ${result.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Download error: $e');
    }
  }
}
