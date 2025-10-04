import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chatapp/components/chat_bubble.dart';
import 'package:chatapp/components/file_picker_widget.dart';
import 'package:chatapp/components/call/call_screen_widget.dart';
import 'package:chatapp/components/voice_recorder.dart';
import 'package:chatapp/pages/location_share_page.dart';
import 'package:chatapp/pages/contact_share_page.dart';
import 'package:chatapp/pages/image_viewer_page.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatapp/services/file/file_service.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/model/message.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/components/user_status_indicator.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

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
  final CallManagerInterface _callManager = CallManager.instance;
  final UserStatusService _userStatusService = UserStatusService();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusMessage;
  bool _isTyping = false;
  Timer? _typingTimer;
  Message? _replyToMessage;
  Map<String, String> _messageReactions = {};
  List<String> _chatImageUrls = [];

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      if (_replyToMessage != null) {
        // Send reply message
        await _chatService.sendReplyMessage(
          receiverId: widget.receiverUserId,
          message: _messageController.text,
          replyToMessageId: _replyToMessage!.timestamp.millisecondsSinceEpoch
              .toString(),
        );
        setState(() {
          _replyToMessage = null;
        });
      } else {
        // Send regular message
        await _chatService.sendMessage(
          widget.receiverUserId,
          _messageController.text,
        );
      }
      _messageController.clear();
    }
  }

  void _handleFileSelection(List<File> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Preparing files...';
    });

    try {
      for (File file in files) {
        // Upload file with status monitoring
        final result = await _fileService.uploadFile(
          file: file,
          chatRoomId: _getChatRoomId(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
          onStatusUpdate: (status) {
            setState(() => _statusMessage = status);
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
        _statusMessage = null;
      });
    }
  }

  String _getChatRoomId() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    List<String> ids = [currentUser.uid, widget.receiverUserId];
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

  void _onVoiceRecordingComplete(String audioPath) async {
    // Upload the recorded audio file and send as voice message
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Uploading voice message...';
    });

    try {
      final audioFile = File(audioPath);

      // Upload voice file
      final result = await _fileService.uploadFile(
        file: audioFile,
        chatRoomId: _getChatRoomId(),
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
        onStatusUpdate: (status) {
          setState(() => _statusMessage = status);
        },
      );

      if (result.isSuccess && result.fileId != null) {
        // Get the file attachment from Firestore
        final fileAttachment = await _fileService.getFileMetadata(
          result.fileId!,
        );

        if (fileAttachment != null) {
          // Send voice message
          await _chatService.sendFileMessage(
            receiverId: widget.receiverUserId,
            fileAttachment: fileAttachment,
            textMessage: '', // No text for voice messages
          );
        } else {
          _showErrorSnackBar('Failed to get voice message metadata');
        }
      } else {
        _showErrorSnackBar('Failed to upload voice message: ${result.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending voice message: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _statusMessage = null;
      });
    }
  }

  Future<void> _startAudioCall() async {
    try {
      // Check microphone permission
      if (!await _checkMicrophonePermission()) {
        _showPermissionDeniedDialog(
          'Microphone permission is required for audio calls',
        );
        return;
      }

      final success = await _callManager.startAudioCall(
        widget.receiverUserId,
        widget.receiverUserEmail,
      );

      if (success) {
        // Show call screen as full-screen dialog
        _showCallScreen();
      } else {
        _showErrorSnackBar('Failed to start audio call');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting call: $e');
    }
  }

  Future<void> _startVideoCall() async {
    try {
      // Check camera and microphone permissions
      if (!await _checkCameraPermission() ||
          !await _checkMicrophonePermission()) {
        _showPermissionDeniedDialog(
          'Camera and microphone permissions are required for video calls',
        );
        return;
      }

      final success = await _callManager.startVideoCall(
        widget.receiverUserId,
        widget.receiverUserEmail,
      );

      if (success) {
        // Show call screen as full-screen dialog
        _showCallScreen();
      } else {
        _showErrorSnackBar('Failed to start video call');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting call: $e');
    }
  }

  void _showCallScreen() {
    final callInfo = _callManager.currentCall;
    if (callInfo == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: CallScreenWidget(
          callInfo: callInfo,
          onEndCall: () async {
            await _callManager.endCall();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<bool> _checkMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    return status.isGranted;
  }

  Future<bool> _checkCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    return status.isGranted;
  }

  void _showPermissionDeniedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _handleSwipeToReply(Message message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  void _handleLongPressReaction(Message message) async {
    final selectedReaction = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Reaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '👍', '🔥', '😢', '😮', '😡'].map((emoji) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(emoji),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (selectedReaction != null) {
      setState(() {
        _messageReactions[message.timestamp.millisecondsSinceEpoch.toString()] =
            selectedReaction;
      });
      // TODO: Save reaction to Firebase for persistence across users
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _openImageViewer(String imageUrl) {
    // Collect all image URLs from current chat messages
    _collectChatImageUrls();

    final initialIndex = _chatImageUrls.indexOf(imageUrl);
    if (initialIndex >= 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            imageUrls: _chatImageUrls,
            initialIndex: initialIndex,
          ),
        ),
      );
    }
  }

  void _collectChatImageUrls() {
    _chatImageUrls.clear();
    // This would need to be implemented to collect all image URLs from the current chat
    // For now, we'll just add the current image
  }

  Future<void> _pickAndShareContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactSharePage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      try {
        final name = result['name'] as String?;
        final phone = result['phone'] as String?;

        if (name != null && phone != null) {
          await _chatService.sendContactMessage(
            receiverId: widget.receiverUserId,
            contactName: name,
            contactPhone: phone,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact shared successfully')),
          );
        }
      } catch (e) {
        _showErrorSnackBar('Failed to share contact: $e');
      }
    }
  }

  Future<void> _shareLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationSharePage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      try {
        final latitude = result['latitude'] as double;
        final longitude = result['longitude'] as double;

        final googleMapsUrl =
            "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";

        await _chatService.sendLocationMessage(
          receiverId: widget.receiverUserId,
          latitude: latitude,
          longitude: longitude,
          mapsUrl: googleMapsUrl,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location shared successfully')),
        );
      } catch (e) {
        _showErrorSnackBar('Failed to share location: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listener to detect typing
    _messageController.addListener(_onTypingChanged);

    // Clear notifications for this chat and mark messages as read
    _clearNotificationsAndMarkAsRead();
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;

    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;

      // Update typing status in Firebase
      _updateTypingStatus();

      // Reset typing timer
      _typingTimer?.cancel();
      if (_isTyping) {
        _typingTimer = Timer(const Duration(seconds: 5), () {
          _isTyping = false;
          _updateTypingStatus();
        });
      }
    }
  }

  void _updateTypingStatus() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      final chatRoomId = _getChatRoomId();
      _userStatusService.setTypingStatus(chatRoomId, _isTyping);
    }
  }

  void _clearNotificationsAndMarkAsRead() async {
    final chatRoomId = _getChatRoomId();

    // Clear notifications for this chat
    await AwesomeNotifications().dismissNotificationsByGroupKey(
      'chat_$chatRoomId',
    );

    // Mark messages as read in Firestore
    await _chatService.markMessagesAsRead(chatRoomId, widget.receiverUserId);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Use custom AppBar design from MessageScreen
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6, // Limit title width
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              CircleAvatar(
                backgroundImage: AssetImage('assets/images/user.png'),
                radius: 18, // Slightly smaller
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: UserStatusIndicator(
                    userId: widget.receiverUserId,
                    showText: false,
                    size: 9,
                  ),
                ),
              ),
              const SizedBox(width: 8), // Reduced spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.receiverUserEmail,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // Slightly smaller
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    UserStatusIndicator(
                      userId: widget.receiverUserId,
                      showText: true,
                      size: 7,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _startAudioCall,
            icon: const Icon(Icons.call, color: Colors.black),
            tooltip: 'Start audio call',
          ),
          IconButton(
            onPressed: _startVideoCall,
            icon: const Icon(Icons.videocam, color: Colors.black),
            tooltip: 'Start video call',
          ),
        ],
      ),

      body: Column(
        children: [
          // ✅ Chat Messages (Firestore Stream)
          Expanded(child: _buildMessageList()),

          // Reply preview
          if (_replyToMessage != null)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_replyToMessage!.senderEmail}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          _replyToMessage!.message.isNotEmpty
                              ? _replyToMessage!.message
                              : 'Attachment',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // ✅ Bottom Input Bar (from MessageScreen)
          Container(
            height: _replyToMessage != null ? 120 : 90,
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
                              onChanged: (text) {
                                // Update typing status
                                _userStatusService.setTypingStatus(
                                  _getChatRoomId(),
                                  text.isNotEmpty,
                                );
                              },
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
                IconButton(
                  onPressed: _pickAndShareContact,
                  icon: const Icon(
                    Icons.contacts,
                    color: Colors.black,
                    size: 24,
                  ),
                  tooltip: 'Share contact',
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _shareLocation,
                  icon: const Icon(
                    Icons.location_on,
                    color: Colors.black,
                    size: 24,
                  ),
                  tooltip: 'Share location',
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.black,
                  size: 24,
                ),
                const SizedBox(width: 10),
                if (!kIsWeb) ...[
                  VoiceRecorder(onStop: _onVoiceRecordingComplete),
                ] else ...[
                  Tooltip(
                    message: 'Voice messages not available on web',
                    child: const Icon(
                      Icons.mic_off,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Firestore Messages
  Widget _buildMessageList() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return Column(
      children: [
        // Typing indicator
        TypingIndicator(
          chatRoomId: _getChatRoomId(),
          currentUserId: currentUser.uid,
        ),

        // Messages list
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _chatService.getMessagesStream(
              currentUser.uid,
              widget.receiverUserId,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading messages: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text('No messages yet'),
                      SizedBox(height: 8),
                      Text('Start the conversation!'),
                    ],
                  ),
                );
              }

              // Show notification for new messages from other users
              final messages = snapshot.data!;
              if (messages.isNotEmpty) {
                final latestMessage = messages.last;
                if (latestMessage.senderId != currentUser.uid &&
                    !latestMessage.isRead) {
                  // Show local notification for new message
                  _chatService.showMessageNotification(
                    senderName: widget.receiverUserEmail,
                    message: latestMessage.message,
                    chatRoomId: _getChatRoomId(),
                    receiverId: widget.receiverUserId,
                    receiverEmail: widget.receiverUserEmail,
                  );
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: messages
                    .map((message) => _buildMessageItemFromMessage(message))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // 🔹 Firestore Single Message from Message object
  Widget _buildMessageItemFromMessage(Message message) {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink(); // Don't show messages if user not authenticated
    }

    bool isCurrentUser = message.senderId == currentUser.uid;
    final messageId = message.timestamp.millisecondsSinceEpoch.toString();
    final reaction = _messageReactions[messageId];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: message,
            isCurrentUser: isCurrentUser,
            onFileDownload: () {
              // Handle file download
              if (message.fileAttachment != null) {
                _downloadFile(message.fileAttachment!);
              }
            },
            onSwipeToReply: _handleSwipeToReply,
            onLongPressReaction: _handleLongPressReaction,
            onImageTap:
                message.fileAttachment != null &&
                    message.type == MessageType.image
                ? () => _openImageViewer(message.fileAttachment!.downloadUrl)
                : null,
          ),
          if (reaction != null)
            Padding(
              padding: EdgeInsets.only(
                left: isCurrentUser ? 0 : 16,
                right: isCurrentUser ? 16 : 0,
                top: 4,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(reaction, style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  // 🔹 Firestore Single Message from DocumentSnapshot (legacy)
  Widget _buildMessageItem(DocumentSnapshot document) {
    final docData = document.data();
    if (docData == null) {
      return const SizedBox.shrink(); // Skip invalid documents
    }

    Map<String, dynamic> data = docData as Map<String, dynamic>;

    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink(); // Don't show messages if user not authenticated
    }

    bool isCurrentUser = data['senderId'] == currentUser.uid;

    // Convert Firestore data to Message object
    Message message = Message.fromMap(data);

    return _buildMessageItemFromMessage(message);
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
