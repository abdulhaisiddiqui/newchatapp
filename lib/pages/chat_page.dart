import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chatapp/components/call/call_screen_widget.dart';
import 'package:chatapp/components/voice_recorder.dart';
import 'package:chatapp/pages/location_share_page.dart';
import 'package:chatapp/pages/contact_share_page.dart';
import 'package:chatapp/pages/image_viewer_page.dart';
import 'package:chatapp/pages/user_profile_page.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

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
  final ScrollController _scrollController = ScrollController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isTyping = false;
  Timer? _typingTimer;
  Message? _replyToMessage;
  final Map<String, String> _messageReactions = {};
  final List<String> _chatImageUrls = [];
  final Set<String> _notifiedMessageIds = {};
  final List<Message> _cachedMessages = [];

  final List<Message> _localMessages = [];

  // void _showErrorSnackBar(String message) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       backgroundColor: Colors.red,
  //     ),
  //   );
  // }
  void sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      if (_replyToMessage != null) {
        await _chatService.sendReplyMessage(
          receiverId: widget.receiverUserId,
          message: _messageController.text,
          replyToMessageId: _replyToMessage!.timestamp.millisecondsSinceEpoch
              .toString(),
          messageId: messageId,
        );
      } else {
        await _chatService.sendMessage(
          widget.receiverUserId,
          _messageController.text,
          messageId: messageId,
        );
      }
      setState(() {
        _messageController.clear();
        _replyToMessage = null;
      });
      // Scroll to the latest message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e', onRetry: sendMessage);
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
        File uploadFile = file;
        final startTime = DateTime.now();
        debugPrint(
          'Original file size: ${await file.length() / 1024 / 1024} MB',
        );

        if (file.path.endsWith('.jpg') ||
            file.path.endsWith('.jpeg') ||
            file.path.endsWith('.png')) {
          final compressedPath = file.path.replaceAll(
            RegExp(r'\.\w+$'),
            '_compressed.jpg',
          );
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            file.path,
            compressedPath,
            quality: 70,
            minWidth: 1024,
            minHeight: 1024,
          );
          if (compressedFile != null) {
            uploadFile = File(compressedFile.path);
            debugPrint(
              'Compressed file size: ${await uploadFile.length() / 1024 / 1024} MB',
            );
          }
        }

        final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        final String fileExtension = path
            .extension(uploadFile.path)
            .toLowerCase();
        final tempMessage = Message(
          id: tempMessageId,
          senderId: _firebaseAuth.currentUser!.uid,
          senderEmail:
              _firebaseAuth.currentUser!.email ?? 'unknown@example.com',
          receiverId: widget.receiverUserId,
          message: '',
          isEdited: false,
          timestamp: Timestamp.now(),
          type: MessageType.image,
          fileAttachment: FileAttachment(
            fileId: tempMessageId,
            fileName: uploadFile.path.split('/').last,
            downloadUrl: uploadFile.path,
            mimeType: 'image/jpeg',
            fileSizeBytes: await uploadFile.length(),
            originalFileName: uploadFile.path.split('/').last,
            fileExtension: fileExtension,
            uploadedAt: Timestamp.now(),
            uploadedBy: _firebaseAuth.currentUser!.uid,
            status: FileStatus.uploading,
          ),
          isRead: false,
        );

        setState(() {
          _localMessages.add(tempMessage);
          _cachedMessages.add(tempMessage);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        });

        final result = await _fileService.uploadFile(
          file: uploadFile,
          chatRoomId: _getChatRoomId(),
          messageId: tempMessageId,
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
          onStatusUpdate: (status) {
            debugPrint('Upload status: $status');
          },
        );

        debugPrint(
          'Upload completed in ${DateTime.now().difference(startTime).inMilliseconds} ms',
        );

        if (result.isSuccess &&
            result.fileId != null &&
            result.downloadUrl != null) {
          final fileAttachment = FileAttachment(
            fileId: result.fileId!,
            fileName: uploadFile.path.split('/').last,
            downloadUrl: result.downloadUrl!,
            mimeType: 'image/jpeg',
            fileSizeBytes: await uploadFile.length(),
            originalFileName: uploadFile.path.split('/').last,
            fileExtension: fileExtension,
            uploadedAt: Timestamp.now(),
            uploadedBy: _firebaseAuth.currentUser!.uid,
            status: FileStatus.uploaded,
          );
          await _chatService.sendFileMessage(
            receiverId: widget.receiverUserId,
            fileAttachment: fileAttachment,
            textMessage: _messageController.text.isNotEmpty
                ? _messageController.text
                : '',
          );
          if (_messageController.text.isNotEmpty) {
            _messageController.clear();
          }
          setState(() {
            _localMessages.removeWhere((m) => m.id == tempMessageId);
            _cachedMessages.removeWhere((m) => m.id == tempMessageId);
          });
        } else {
          setState(() {
            _localMessages.removeWhere((m) => m.id == tempMessageId);
            _cachedMessages.removeWhere((m) => m.id == tempMessageId);
          });
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
  // void _handleFileSelection(List<File> files) async {
  //   if (files.isEmpty) return;
  //
  //   setState(() {
  //     _isUploading = true;
  //     _uploadProgress = 0.0;
  //   });
  //
  //   try {
  //     for (File file in files) {
  //       File uploadFile = file;
  //       final startTime = DateTime.now();
  //       debugPrint('Original file size: ${await file.length() / 1024 / 1024} MB');
  //
  //       // Compress image
  //       if (file.path.endsWith('.jpg') || file.path.endsWith('.jpeg') || file.path.endsWith('.png')) {
  //         final compressedPath = file.path.replaceAll(RegExp(r'\.\w+$'), '_compressed.jpg');
  //         final compressedFile = await FlutterImageCompress.compressAndGetFile(
  //           file.path,
  //           compressedPath,
  //           quality: 70,
  //           minWidth: 1024,
  //           minHeight: 1024,
  //         );
  //         if (compressedFile != null) {
  //           uploadFile = File(compressedFile.path);
  //           debugPrint('Compressed file size: ${await uploadFile.length() / 1024 / 1024} MB');
  //         }
  //       }
  //
  //       final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
  //       final String fileExtension = path.extension(uploadFile.path).toLowerCase();
  //       final tempMessage = Message(
  //         id: tempMessageId,
  //         senderId: _firebaseAuth.currentUser!.uid,
  //         senderEmail: _firebaseAuth.currentUser!.email ?? 'unknown@example.com',
  //         receiverId: widget.receiverUserId,
  //         message: '',
  //         timestamp: Timestamp.now(),
  //         type: MessageType.image,
  //         fileAttachment: FileAttachment(
  //           fileId: tempMessageId,
  //           fileName: uploadFile.path.split('/').last,
  //           downloadUrl: uploadFile.path,
  //           mimeType: 'image/jpeg',
  //           fileSizeBytes: await uploadFile.length(),
  //           originalFileName: uploadFile.path.split('/').last,
  //           fileExtension: fileExtension,
  //           uploadedAt: Timestamp.now(),
  //           uploadedBy: _firebaseAuth.currentUser!.uid,
  //           status: FileStatus.uploading,
  //         ),
  //         isRead: false,
  //       );
  //
  //       setState(() {
  //         _localMessages.add(tempMessage);
  //         WidgetsBinding.instance.addPostFrameCallback((_) {
  //           if (_scrollController.hasClients) {
  //             _scrollController.animateTo(
  //               _scrollController.position.minScrollExtent,
  //               duration: const Duration(milliseconds: 300),
  //               curve: Curves.easeOut,
  //             );
  //           }
  //         });
  //       });
  //
  //       final result = await _fileService.uploadFile(
  //         file: uploadFile,
  //         chatRoomId: _getChatRoomId(),
  //         messageId: tempMessageId,
  //         onProgress: (progress) {
  //           setState(() => _uploadProgress = progress);
  //         },
  //         onStatusUpdate: (status) {
  //           debugPrint('Upload status: $status');
  //         },
  //       );
  //
  //       debugPrint('Upload completed in ${DateTime.now().difference(startTime).inMilliseconds} ms');
  //
  //       if (result.isSuccess && result.fileId != null && result.downloadUrl != null) {
  //         final fileAttachment = FileAttachment(
  //           fileId: result.fileId!,
  //           fileName: uploadFile.path.split('/').last,
  //           downloadUrl: result.downloadUrl!,
  //           mimeType: 'image/jpeg',
  //           fileSizeBytes: await uploadFile.length(),
  //           originalFileName: uploadFile.path.split('/').last,
  //           fileExtension: fileExtension,
  //           uploadedAt: Timestamp.now(),
  //           uploadedBy: _firebaseAuth.currentUser!.uid,
  //           status: FileStatus.uploaded,
  //         );
  //         await _chatService.sendFileMessage(
  //           receiverId: widget.receiverUserId,
  //           fileAttachment: fileAttachment,
  //           textMessage: _messageController.text.isNotEmpty ? _messageController.text : '',
  //         );
  //         if (_messageController.text.isNotEmpty) {
  //           _messageController.clear();
  //         }
  //       } else {
  //         _showErrorSnackBar('Failed to upload file: ${result.error}');
  //       }
  //
  //       setState(() {
  //         _localMessages.removeWhere((m) => m.id == tempMessageId);
  //       });
  //     }
  //   } catch (e) {
  //     _showErrorSnackBar('Error uploading files: $e');
  //
  //   } finally {
  //     setState(() {
  //       _isUploading = false;
  //       _uploadProgress = 0.0;
  //     });
  //   }
  // }

  void _handleVoiceRecording(String audioPath) {
    _onVoiceRecordingComplete(audioPath);
  }

  void _onVoiceRecordingComplete(String audioPath) async {
    if (audioPath.isEmpty || !File(audioPath).existsSync()) {
      _showErrorSnackBar('No valid audio file recorded');
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = Message(
      id: messageId,
      senderId: _firebaseAuth.currentUser!.uid,
      senderEmail: _firebaseAuth.currentUser!.email ?? 'unknown@example.com',
      receiverId: widget.receiverUserId,
      message: '',
      isEdited: false,
      timestamp: Timestamp.now(),
      type: MessageType.audio,
      fileAttachment: FileAttachment(
        fileId: messageId,
        fileName: audioPath.split('/').last,
        downloadUrl: audioPath,
        mimeType: 'audio/mpeg',
        fileSizeBytes: await File(audioPath).length(),
        originalFileName: audioPath.split('/').last,
        fileExtension: '.mp3',
        uploadedAt: Timestamp.now(),
        uploadedBy: _firebaseAuth.currentUser!.uid,
        status: FileStatus.uploading,
      ),
      isRead: false,
    );

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _localMessages.add(tempMessage);
      _cachedMessages.add(tempMessage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });

    try {
      final audioFile = File(audioPath);
      final result = await _fileService.uploadFile(
        file: audioFile,
        chatRoomId: _getChatRoomId(),
        messageId: messageId,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
        onStatusUpdate: (status) {
          debugPrint('Upload status: $status');
        },
      );

      if (result.isSuccess && result.fileId != null) {
        final fileAttachment = await _fileService.getFileMetadata(
          result.fileId!,
        );
        if (fileAttachment != null) {
          await _chatService.sendFileMessage(
            receiverId: widget.receiverUserId,
            fileAttachment: fileAttachment,
            textMessage: '',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice message sent successfully')),
            );
          }
          setState(() {
            _localMessages.removeWhere((m) => m.id == messageId);
            _cachedMessages.removeWhere((m) => m.id == messageId);
          });
        } else {
          throw Exception('Failed to get voice message metadata');
        }
      } else {
        throw Exception('Failed to upload voice message: ${result.error}');
      }
    } catch (e) {
      setState(() {
        _localMessages.removeWhere((m) => m.id == messageId);
        _cachedMessages.removeWhere((m) => m.id == messageId);
      });
      _showErrorSnackBar('Error sending voice message: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      if (File(audioPath).existsSync()) {
        await File(audioPath).delete();
      }
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

  // void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       backgroundColor: Colors.red,
  //       duration: const Duration(seconds: 4),
  //       action: onRetry != null
  //           ? SnackBarAction(
  //         label: 'Retry',
  //         textColor: Colors.white,
  //         onPressed: onRetry,
  //       )
  //           : null,
  //     ),
  //   );
  // }

  Future<void> _startAudioCall() async {
    try {
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
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _openImageViewer(String imageUrl) {
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact shared successfully')),
            );
          }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location shared successfully')),
          );
        }
      } catch (e) {
        _showErrorSnackBar('Failed to share location: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTypingChanged);
    _clearNotificationsAndMarkAsRead();
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;
      _updateTypingStatus();
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
    await AwesomeNotifications().dismissNotificationsByGroupKey(
      'chat_$chatRoomId',
    );
    await _chatService.markMessagesAsRead(chatRoomId, widget.receiverUserId);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ AppBar from MessageScreen
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
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.receiverUserId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  );
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final username = userData['username'] ?? 'User';
                final profilePic = userData['profilePic'] ?? '';
                return Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: profilePic.isNotEmpty
                              ? NetworkImage(profilePic)
                              : const AssetImage('assets/images/user.png')
                                    as ImageProvider,
                          radius: 20,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              userId: widget.receiverUserId,
                              username: username,
                              profilePic: profilePic,
                              chatRoomId: _getChatRoomId(),
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                );
              },
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/images/m-Call.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: _startAudioCall,
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/images/Video.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: _startVideoCall,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
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
          // ✅ Input Bar from MessageScreen
          ChatInputBar(
            messageController: _messageController,
            onSendMessage: sendMessage,
            onFilesSelected: _handleFileSelection,
            onCameraPressed: () async {
              try {
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
            onVoiceRecordStart: () {},
            onVoiceRecordStop: (audioPath) => _handleVoiceRecording(audioPath),
            isUploading: _isUploading,
            uploadProgress: _uploadProgress,
            isWeb: kIsWeb,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return Column(
      children: [
        StreamBuilder<bool>(
          stream: _userStatusService.getTypingStatus(
            _getChatRoomId(),
            widget.receiverUserId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "Someone is typing...",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _chatService.getMessagesStream(
              currentUser.uid,
              widget.receiverUserId,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];

              if (snapshot.connectionState == ConnectionState.waiting &&
                  messages.isEmpty) {
                debugPrint('StreamBuilder: Waiting for data');
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('StreamBuilder error: ${snapshot.error}');
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

              if (messages.isEmpty) {
                debugPrint('StreamBuilder: No messages');
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

              if (messages.isNotEmpty) {
                final latestMessage = messages.first;
                final messageId = latestMessage.timestamp.millisecondsSinceEpoch
                    .toString();
                if (latestMessage.senderId != currentUser.uid &&
                    !latestMessage.isRead &&
                    !_notifiedMessageIds.contains(messageId)) {
                  _notifiedMessageIds.add(messageId);
                  _chatService.showMessageNotification(
                    senderName: widget.receiverUserEmail,
                    message: latestMessage.message,
                    chatRoomId: _getChatRoomId(),
                    receiverId: widget.receiverUserId,
                    receiverEmail: widget.receiverUserEmail,
                  );
                }
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                controller: _scrollController,
                itemCount: messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Today",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildMessageItemFromMessage(messages[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItemFromMessage(Message message) {
    final currentUser = _firebaseAuth.currentUser;
    bool isMe = message.senderId == currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: isMe
          ? _buildCurrentUserMessage(message)
          : _buildOtherUserMessage(message),
    );
  }

  Widget _buildCurrentUserMessage(Message message) {
    debugPrint('Rendering curent user message: ${message.toMap()}');
    return Align(
      alignment: Alignment.centerRight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onLongPress: () => _handleLongPressReaction(message),
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _handleSwipeToReply(message);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(left: 50),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.fileAttachment != null &&
                      message.fileAttachment!.downloadUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          message.fileAttachment!.downloadUrl.startsWith(
                                'file://',
                              ) ||
                              message.fileAttachment!.downloadUrl.contains(
                                '/cache/',
                              )
                          ? Image.file(
                              File(message.fileAttachment!.downloadUrl),
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Local image load error: $error');
                                return const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : Image.network(
                              message.fileAttachment!.downloadUrl,
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint(
                                  'Image load error: $error, URL: ${message.fileAttachment!.downloadUrl}',
                                );
                                return const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                );
                              },
                            ),
                    )
                  else if (message.type == MessageType.audio)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white),
                        const SizedBox(width: 4),
                        const Icon(Icons.graphic_eq, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          message.fileAttachment?.fileName ?? "Voice message",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  else if (message.type == MessageType.contact)
                    Text(
                      'Contact: ${message.message}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  else if (message.type == MessageType.location)
                    Text(
                      'Location: ${message.message}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  else
                    Text(
                      message.message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp.toDate()),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  if (_messageReactions.containsKey(
                    message.timestamp.millisecondsSinceEpoch.toString(),
                  ))
                    Text(
                      _messageReactions[message.timestamp.millisecondsSinceEpoch
                          .toString()]!,
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ),
          if (_isUploading &&
              message.fileAttachment != null &&
              message.fileAttachment!.downloadUrl.startsWith('file://'))
            CircularProgressIndicator(
              value: _uploadProgress,
              strokeWidth: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return "$hour:${timestamp.minute.toString().padLeft(2, '0')} $period";
  }

  Widget _buildOtherUserMessage(Message message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(message.senderId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const CircleAvatar(
                radius: 18,
                backgroundImage: AssetImage('assets/default_avatar.png'),
              );
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final profilePic = userData['profilePic'];
            return CircleAvatar(
              radius: 18,
              backgroundImage: profilePic != null && profilePic != ''
                  ? NetworkImage(profilePic)
                  : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
            );
          },
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(message.senderId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text(
                      "Unknown User",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    );
                  }
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  return Text(
                    userData['username'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  );
                },
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onLongPress: () => _handleLongPressReaction(message),
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _handleSwipeToReply(message);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(13),
                      bottomLeft: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.fileAttachment != null &&
                          message.fileAttachment!.downloadUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () => _openImageViewer(
                            message.fileAttachment!.downloadUrl,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              message.fileAttachment!.downloadUrl,
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                            ),
                          ),
                        )
                      else if (message.type == MessageType.audio)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.black),
                            const SizedBox(width: 4),
                            const Icon(Icons.graphic_eq, color: Colors.black),
                            const SizedBox(width: 8),
                            Text(
                              message.fileAttachment?.fileName ??
                                  "Voice message",
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        )
                      else if (message.type == MessageType.contact)
                        Text(
                          'Contact: ${message.message}',
                          style: const TextStyle(fontSize: 14),
                        )
                      else if (message.type == MessageType.location)
                        Text(
                          'Location: ${message.message}',
                          style: const TextStyle(fontSize: 14),
                        )
                      else
                        Text(
                          message.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(message.timestamp.toDate()),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                      if (_messageReactions.containsKey(
                        message.timestamp.millisecondsSinceEpoch.toString(),
                      ))
                        Text(
                          _messageReactions[message
                              .timestamp
                              .millisecondsSinceEpoch
                              .toString()]!,
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
  final Function(String)? onVoiceRecordStop;
  final bool isUploading;
  final double uploadProgress;
  final bool isWeb;

  const ChatInputBar({
    super.key,
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
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  bool _isRecording = false;
  late AnimationController _micController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);
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
      setState(() {
        _hasText = hasText;
        if (_hasText && _isRecording) {
          _isRecording = false; // Stop recording if user starts typing
          _micController.reverse();
        }
      });
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: ShareContentPopup(
          onCameraPressed: widget.onCameraPressed,
          onDocumentPressed: widget.onDocumentPressed,
          onGalleryPressed: widget.onGalleryPressed,
          onContactPressed: widget.onContactPressed,
          onLocationPressed: widget.onLocationPressed,
        ),
      ),
    );
  }

  void _handleMicPress() async {
    if (!widget.isWeb && widget.onVoiceRecordStop != null) {
      PermissionStatus micStatus = await Permission.microphone.status;
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Microphone permission is required for voice messages',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
          return;
        }
      }
      setState(() {
        _isRecording = true;
        _hasText = false; // Ensure send button is hidden when recording
      });
      _micController.forward();
      widget.onVoiceRecordStart?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recording is not supported on web'),
        ),
      );
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
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          if (widget.isUploading)
            LinearProgressIndicator(
              value: widget.uploadProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          Row(
            children: [
              IconButton(
                onPressed: _showAttachmentMenu,
                icon: const Icon(
                  Icons.attach_file,
                  color: Colors.black,
                  size: 24,
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
                        child: TextField(
                          controller: widget.messageController,
                          decoration: const InputDecoration(
                            hintText: "Write your message",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.content_paste_rounded,
                        color: Colors.grey,
                        weight: 600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.black,
                  weight: 600,
                  size: 24,
                ),
                onPressed: widget.onCameraPressed,
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: _hasText
                    ? Material(
                        key: const ValueKey('send'),
                        color: const Color(0xFF128C7E),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: widget.isUploading
                              ? null
                              : widget.onSendMessage,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        key: const ValueKey('mic'),
                        children: [
                          ScaleTransition(
                            scale: _micScaleAnimation,
                            child: Material(
                              color: _isRecording
                                  ? Colors.red
                                  : const Color(0xFF128C7E),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTapDown: (_) => _handleMicPress(),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    _isRecording ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_isRecording)
                            Positioned.fill(
                              child: VoiceRecorder(
                                onStop: (audioPath) {
                                  setState(() {
                                    _isRecording = false;
                                    _hasText = widget.messageController.text
                                        .trim()
                                        .isNotEmpty;
                                  });
                                  _micController.reverse();
                                  if (widget.onVoiceRecordStop != null &&
                                      audioPath.isNotEmpty) {
                                    widget.onVoiceRecordStop!(audioPath);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ShareContentPopup extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onDocumentPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onContactPressed;
  final VoidCallback onLocationPressed;

  const ShareContentPopup({
    super.key,
    required this.onCameraPressed,
    required this.onDocumentPressed,
    required this.onGalleryPressed,
    required this.onContactPressed,
    required this.onLocationPressed,
  });

  Widget _buildOption(
    BuildContext context,
    String imagePath,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF2F8F7),
        child: Image.asset(imagePath, width: 24, height: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'caros',
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Share Content",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'caros',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildOption(
                context,
                'assets/images/cameraIcon.png',
                "Camera",
                "Share your camera",
                onCameraPressed,
              ),
              _buildOption(
                context,
                'assets/images/docIcon.png',
                "Documents",
                "Share your files",
                onDocumentPressed,
              ),
              _buildOption(
                context,
                'assets/images/chartIcon.png',
                "Create a poll",
                "Create a poll for any query",
                () => Navigator.pop(context),
              ),
              _buildOption(
                context,
                'assets/images/mediaIcon.png',
                "Media",
                "Share photos and videos",
                onGalleryPressed,
              ),
              _buildOption(
                context,
                'assets/images/userIcon.png',
                "Contact",
                "Share your contacts",
                onContactPressed,
              ),
              _buildOption(
                context,
                'assets/images/userIcon.png',
                "Location",
                "Share your location",
                onLocationPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
