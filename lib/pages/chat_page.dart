import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chatapp/components/chat_bubble.dart';
import 'package:chatapp/components/call/call_screen_widget.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isTyping = false;
  Timer? _typingTimer;
  Message? _replyToMessage;
  Map<String, String> _messageReactions = {};
  List<String> _chatImageUrls = [];
  Set<String> _notifiedMessageIds = {};

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
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      widget.receiverUserEmail.isNotEmpty
                          ? widget.receiverUserEmail[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: UserStatusIndicator(
                      userId: widget.receiverUserId,
                      showText: false,
                      size: 9,
                    ),
                  ),
                ],
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

          // ✅ Bottom Input Bar
          ChatInputBar(
            messageController: _messageController,
            onSendMessage: sendMessage,
            onFilesSelected: _handleFileSelection,
            onCameraPressed: () async {
              try {
                // Check camera permission
                if (!await _checkCameraPermission()) {
                  _showPermissionDeniedDialog(
                    'Camera permission is required to take photos',
                  );
                  return;
                }

                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (image != null) {
                  _handleFileSelection([File(image.path)]);
                }
              } catch (e) {
                _showErrorSnackBar('Failed to open camera: $e');
              }
            },
            onGalleryPressed: () async {
              try {
                // Check gallery permission
                List<Permission> permissionsToCheck = [Permission.photos];
                if (Platform.isAndroid) {
                  // For older Android versions, photos permission might not be available
                  try {
                    await Permission.photos.status;
                  } catch (e) {
                    permissionsToCheck = [Permission.storage];
                  }
                }

                bool hasPermission = true;
                for (Permission permission in permissionsToCheck) {
                  PermissionStatus status = await permission.status;
                  if (status.isDenied || status.isLimited) {
                    status = await permission.request();
                  }
                  if (!status.isGranted) {
                    hasPermission = false;
                    break;
                  }
                }

                if (!hasPermission) {
                  _showPermissionDeniedDialog(
                    'Gallery permission is required to select photos',
                  );
                  return;
                }

                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (image != null) {
                  _handleFileSelection([File(image.path)]);
                }
              } catch (e) {
                _showErrorSnackBar('Failed to open gallery: $e');
              }
            },
            onDocumentPressed: () async {
              try {
                // Check storage permission for documents
                if (Platform.isAndroid) {
                  PermissionStatus status = await Permission.storage.status;
                  if (status.isDenied || status.isLimited) {
                    status = await Permission.storage.request();
                  }
                  if (!status.isGranted) {
                    _showPermissionDeniedDialog(
                      'Storage permission is required to select documents',
                    );
                    return;
                  }
                }

                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  allowMultiple: true,
                );
                if (result != null) {
                  List<File> files = result.paths
                      .where((path) => path != null)
                      .map((path) => File(path!))
                      .toList();
                  _handleFileSelection(files);
                }
              } catch (e) {
                _showErrorSnackBar('Failed to pick documents: $e');
              }
            },
            onContactPressed: _pickAndShareContact,
            onLocationPressed: _shareLocation,
            onVoiceRecordStart: () {
              // Voice recording is handled by the VoiceRecorder widget separately
            },
            onVoiceRecordStop: () {
              // Voice recording is handled by the VoiceRecorder widget separately
            },
            isUploading: _isUploading,
            uploadProgress: _uploadProgress,
            isWeb: kIsWeb,
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
                final messageId = latestMessage.timestamp.millisecondsSinceEpoch
                    .toString();
                if (latestMessage.senderId != currentUser.uid &&
                    !latestMessage.isRead &&
                    !_notifiedMessageIds.contains(messageId)) {
                  _notifiedMessageIds.add(messageId);
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

// ============================================================================
// CHAT INPUT BAR WIDGET
// ============================================================================
class ChatInputBar extends StatefulWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final Function(List<File>) onFilesSelected;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onDocumentPressed;
  final VoidCallback onContactPressed;
  final VoidCallback onLocationPressed;
  final VoidCallback? onVoiceRecordStart;
  final VoidCallback? onVoiceRecordStop;
  final bool isUploading;
  final double uploadProgress;
  final bool isWeb;

  const ChatInputBar({
    Key? key,
    required this.messageController,
    required this.onSendMessage,
    required this.onFilesSelected,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onDocumentPressed,
    required this.onContactPressed,
    required this.onLocationPressed,
    this.onVoiceRecordStart,
    this.onVoiceRecordStop,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isWeb = false,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  late AnimationController _micController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);

    // Mic button animation controller
    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _micScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _micController, curve: Curves.easeInOut));
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AttachmentBottomSheet(
        onCameraPressed: () {
          Navigator.pop(context);
          widget.onCameraPressed();
        },
        onGalleryPressed: () {
          Navigator.pop(context);
          widget.onGalleryPressed();
        },
        onDocumentPressed: () {
          Navigator.pop(context);
          widget.onDocumentPressed();
        },
        onContactPressed: () {
          Navigator.pop(context);
          widget.onContactPressed();
        },
        onLocationPressed: () {
          Navigator.pop(context);
          widget.onLocationPressed();
        },
      ),
    );
  }

  void _handleMicPress() {
    if (!widget.isWeb && widget.onVoiceRecordStart != null) {
      setState(() => _isRecording = true);
      _micController.forward();
      widget.onVoiceRecordStart!();
    }
  }

  void _handleMicRelease() {
    if (_isRecording && widget.onVoiceRecordStop != null) {
      setState(() => _isRecording = false);
      _micController.reverse();
      widget.onVoiceRecordStop!();
    }
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    _micController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Emoji Button
            _buildIconButton(
              icon: _showEmojiPicker
                  ? Icons.keyboard
                  : Icons.emoji_emotions_outlined,
              onPressed: () {
                setState(() => _showEmojiPicker = !_showEmojiPicker);
                // TODO: Implement emoji picker toggle
              },
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 4),

            // Message Input Field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text Field
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: widget.messageController,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                    ),

                    // Attachment Button
                    if (!_hasText)
                      _buildIconButton(
                        icon: Icons.attach_file,
                        onPressed: _showAttachmentMenu,
                        color: Colors.grey.shade700,
                        padding: const EdgeInsets.only(right: 8),
                      ),

                    // Upload Progress Indicator
                    if (widget.isUploading)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 10),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: widget.uploadProgress,
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF128C7E),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Send Button (when has text) OR Mic Button (when no text)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: _hasText ? _buildSendButton() : _buildMicButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    EdgeInsets? padding,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildSendButton() {
    return Material(
      key: const ValueKey('send'),
      color: const Color(0xFF128C7E),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: widget.isUploading ? null : widget.onSendMessage,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.send, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    if (widget.isWeb) {
      return Material(
        key: const ValueKey('mic_disabled'),
        color: Colors.grey.shade300,
        shape: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.mic_off, color: Colors.grey.shade600, size: 22),
        ),
      );
    }

    return ScaleTransition(
      key: const ValueKey('mic'),
      scale: _micScaleAnimation,
      child: Material(
        color: _isRecording ? Colors.red : const Color(0xFF128C7E),
        shape: const CircleBorder(),
        child: InkWell(
          onTapDown: (_) => _handleMicPress(),
          onTapUp: (_) => _handleMicRelease(),
          onTapCancel: _handleMicRelease,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ATTACHMENT BOTTOM SHEET
// ============================================================================
class AttachmentBottomSheet extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onDocumentPressed;
  final VoidCallback onContactPressed;
  final VoidCallback onLocationPressed;

  const AttachmentBottomSheet({
    Key? key,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onDocumentPressed,
    required this.onContactPressed,
    required this.onLocationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Grid of attachment options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AttachmentOption(
                        icon: Icons.insert_drive_file,
                        label: 'Document',
                        color: const Color(0xFF7F66FF),
                        onTap: onDocumentPressed,
                      ),
                      _AttachmentOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        color: const Color(0xFFEC407A),
                        onTap: onCameraPressed,
                      ),
                      _AttachmentOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        color: const Color(0xFFAB47BC),
                        onTap: onGalleryPressed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AttachmentOption(
                        icon: Icons.headset,
                        label: 'Audio',
                        color: const Color(0xFFFF7043),
                        onTap: () {
                          Navigator.pop(context);
                          // Handle audio - could open audio picker
                        },
                      ),
                      _AttachmentOption(
                        icon: Icons.location_on,
                        label: 'Location',
                        color: const Color(0xFF66BB6A),
                        onTap: onLocationPressed,
                      ),
                      _AttachmentOption(
                        icon: Icons.person,
                        label: 'Contact',
                        color: const Color(0xFF29B6F6),
                        onTap: onContactPressed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ATTACHMENT OPTION BUTTON
// ============================================================================
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
