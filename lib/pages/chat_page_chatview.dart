import 'package:chatapp/model/custom_message.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatapp/services/connectivity_service.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:chatapp/services/file/file_service.dart';
import 'package:chatapp/components/file_selection_dialog.dart';
import 'package:chatapp/components/voice_recorder.dart';
import 'package:chatview/chatview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chatapp/pages/location_share_page.dart';
import 'package:chatapp/pages/contact_share_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class ChatPageChatView extends StatefulWidget {
  final String receiverUserEmail;
  final String receiverUserId;

  const ChatPageChatView({
    super.key,
    required this.receiverUserEmail,
    required this.receiverUserId,
  });

  @override
  State<ChatPageChatView> createState() => _ChatPageChatViewState();
}

class _ChatPageChatViewState extends State<ChatPageChatView> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
  final FileService _fileService = FileService();

  late ChatController chatController;
  late ChatUser currentUser;
  late ChatUser otherUser;
  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusMessage;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _connectionStatus = _connectivityService.currentStatus;
    _connectivityService.connectionStatusStream.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
    });
  }

  void _initializeChat() {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return;

    currentUser = ChatUser(
      id: firebaseUser.uid,
      name: firebaseUser.email ?? 'Unknown',
    );

    otherUser = ChatUser(
      id: widget.receiverUserId,
      name: widget.receiverUserEmail,
    );

    chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      currentUser: currentUser,
      otherUsers: [otherUser],
    );

  }

  // void _loadMessages() async {
  //   final messages = await _chatService
  //       .getMessagesStream(currentUser.id, otherUser.id)
  //       .first;
  //
  //   final chatViewMessages = messages.map((msg) {
  //     // For file messages, create CustomMessage with proper data
  //     if (msg.hasFileAttachment && msg.fileAttachment != null) {
  //       final fileAttachment = msg.fileAttachment!;
  //       CustomMessageType messageType;
  //
  //       if (fileAttachment.isImage) {
  //         messageType = CustomMessageType.image;
  //       } else if (fileAttachment.isVideo) {
  //         messageType = CustomMessageType.document; // Videos as documents
  //       } else if (fileAttachment.isAudio) {
  //         messageType = CustomMessageType.voice;
  //       } else {
  //         messageType = CustomMessageType.document;
  //       }
  //
  //       final customMessage = CustomMessage(
  //         id: msg.timestamp.millisecondsSinceEpoch.toString(),
  //         message: messageType == CustomMessageType.image
  //             ? 'Sent image: ${fileAttachment.originalFileName}'
  //             : msg.message.isNotEmpty
  //             ? msg.message
  //             : 'Sent file: ${fileAttachment.originalFileName}',
  //         sender: currentUser.id == msg.senderId ? currentUser : otherUser,
  //         createdAt: msg.timestamp.toDate(),
  //         customType: messageType,
  //         extraData: {
  //           'fileId': fileAttachment.fileId,
  //           'fileName': fileAttachment.originalFileName,
  //           'fileSize': fileAttachment.fileSizeBytes,
  //           'downloadUrl': fileAttachment.downloadUrl,
  //           'senderEmail': msg.senderEmail,
  //         },
  //       );
  //
  //       return customMessage.toChatViewMessage();
  //     } else {
  //       // For text messages, use the existing logic
  //       final firestoreData = msg.toMap();
  //       firestoreData['id'] = msg.timestamp.millisecondsSinceEpoch.toString();
  //
  //       final customMessage = CustomMessage.fromFirestore(
  //         firestoreData,
  //         currentUser.id == msg.senderId ? currentUser : otherUser,
  //       );
  //
  //       return customMessage.toChatViewMessage();
  //     }
  //   }).toList();
  //
  //   chatController.loadMoreData(chatViewMessages);
  // }

  void _handleVoiceRecording(String audioPath) {
    _onVoiceRecordingComplete(audioPath);
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) {
      // Stop recording - this would be handled by the VoiceRecorder widget
      setState(() => _isRecording = false);
      // The actual recording completion is handled by _handleVoiceRecording
    } else {
      // Start recording
      if (!await _checkMicrophonePermission()) {
        _showPermissionDeniedDialog(
          'Microphone permission is required for voice messages',
        );
        return;
      }

      setState(() => _isRecording = true);

      // Show voice recorder overlay using the actual VoiceRecorder component
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Recording Voice Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hold to record, release to stop'),
              const SizedBox(height: 16),
              VoiceRecorder(
                onStop: (audioPath) {
                  Navigator.pop(context);
                  setState(() => _isRecording = false);
                  _handleVoiceRecording(audioPath);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getChatRoomId() {
    List<String> ids = [currentUser.id, otherUser.id];
    ids.sort();
    return ids.join("_");
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
          // Send voice message using ChatService
          await _chatService.sendFileMessage(
            receiverId: widget.receiverUserId,
            fileAttachment: fileAttachment,
            textMessage: '', // No text for voice messages
          );

          // Add to chat view
          final customMessage = CustomMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Voice message',
            sender: currentUser,
            createdAt: DateTime.now(),
            customType: CustomMessageType.voice,
            extraData: {
              'fileId': fileAttachment.fileId,
              'fileName': fileAttachment.fileName,
              'fileSize': fileAttachment.fileSizeBytes,
              'duration': 0, // You might want to calculate actual duration
            },
          );

          chatController.addMessage(customMessage.toChatViewMessage());
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

  Future<bool> _checkMicrophonePermission() async {
    // Web doesn't support microphone permissions through permission_handler
    if (kIsWeb) {
      _showWebFeatureDialog(
        'Voice recording is not supported on web. Please use the mobile app for voice messages.',
      );
      return false;
    }

    try {
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      // Platform not available, assume permission granted
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF128C7E), // WhatsApp green
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: Text(
                  widget.receiverUserEmail.isNotEmpty
                      ? widget.receiverUserEmail[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiverUserEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<UserStatus>(
                    stream: UserStatusService().getUserStatus(
                      widget.receiverUserId,
                    ),
                    builder: (context, snapshot) {
                      final userStatus = snapshot.data;
                      final isOnline = userStatus?.isOnline ?? false;
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _connectionStatus.isOnline
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _connectionStatus.isOnline ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _connectionStatus.isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: _connectionStatus.isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _connectionStatus.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: _connectionStatus.isOnline
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Popup menu for additional options (available on both web and mobile)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'location':
                  _shareLocation();
                  break;
                case 'contact':
                  _shareContact();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'location',
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Share Location'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'contact',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Share Contact'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'More options',
          ),
          IconButton(
            onPressed: () {
              // Add Sentry test button here
              throw StateError(
                'This is a test Sentry error from ChatView page',
              );
            },
            icon: const Icon(Icons.bug_report, color: Colors.red),
            tooltip: 'Test Sentry Error',
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
          color: const Color(0xFFECE5DD), // WhatsApp background color
        ),
        child: Stack(
          children: [
            ChatView(
              chatController: chatController,
              onSendTap: _onSendMessage,
              chatViewState: ChatViewState.hasMessages,
              sendMessageConfig: SendMessageConfiguration(
                textFieldConfig: TextFieldConfiguration(
                  textStyle: const TextStyle(color: Colors.black),
                ),
              ),
              featureActiveConfig: const FeatureActiveConfig(
                enableReplySnackBar: true,
                enableSwipeToReply: true,
                enableSwipeToSeeTime: true,
              ),
            ),
            // Show file sharing features on both mobile and web
            Positioned(
              bottom: 100, // Above the chat input
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Voice recording only on mobile (not supported on web)
                  if (!kIsWeb)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF128C7E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _startVoiceRecording,
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? Colors.red : Colors.white,
                        ),
                        tooltip: _isRecording
                            ? 'Stop recording'
                            : 'Record voice message',
                        iconSize: 24,
                      ),
                    ),
                  // File attachment available on both web and mobile
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF128C7E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSendMessage(
    String message,
    ReplyMessage replyMessage,
    MessageType messageType,
  ) {
    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      createdAt: DateTime.now(),
      sentBy: currentUser.id,
      messageType: messageType,
      replyMessage: replyMessage,
    );

    chatController.addMessage(newMessage);

    // Send to Firebase - handle reply messages
    if (replyMessage.message.isNotEmpty) {
      // This is a reply message
      _chatService.sendReplyMessage(
        receiverId: widget.receiverUserId,
        message: message,
        replyToMessageId: replyMessage.messageId,
      );
    } else {
      // Regular message
      _chatService.sendMessage(widget.receiverUserId, message);
    }
  }

  Future<void> _shareLocation() async {
    try {
      // Check location permission
      if (!await _checkLocationPermission()) {
        _showPermissionDeniedDialog(
          'Location permission is required to share location',
        );
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LocationSharePage()),
      );

      if (result != null && result is Map<String, dynamic>) {
        final latitude = result['latitude'] as double?;
        final longitude = result['longitude'] as double?;

        if (latitude != null && longitude != null) {
          await _chatService.sendLocationMessage(
            receiverId: widget.receiverUserId,
            latitude: latitude,
            longitude: longitude,
          );

          // Add to chat view
          final customMessage = CustomMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Shared location',
            sender: currentUser,
            createdAt: DateTime.now(),
            customType: CustomMessageType.location,
            extraData: {
              'lat': latitude,
              'lng': longitude,
              'address': 'Shared location',
            },
          );

          chatController.addMessage(customMessage.toChatViewMessage());
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to share location: $e');
    }
  }

  Future<void> _shareContact() async {
    try {
      // Check contacts permission
      if (!await _checkContactsPermission()) {
        _showPermissionDeniedDialog(
          'Contacts permission is required to share contacts',
        );
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContactSharePage()),
      );

      if (result != null && result is Map<String, dynamic>) {
        final name = result['name'] as String?;
        final phone = result['phone'] as String?;

        if (name != null && phone != null) {
          await _chatService.sendContactMessage(
            receiverId: widget.receiverUserId,
            contactName: name,
            contactPhone: phone,
          );

          // Add to chat view
          final customMessage = CustomMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Shared contact: $name',
            sender: currentUser,
            createdAt: DateTime.now(),
            customType: CustomMessageType.contact,
            extraData: {'name': name, 'phone': phone},
          );

          chatController.addMessage(customMessage.toChatViewMessage());
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to share contact: $e');
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
              setState(() {
                _isUploading = true;
                _uploadProgress = 0.0;
                _statusMessage = 'Uploading file...';
              });

              try {
                // Upload file to Firebase Storage using FileService
                final uploadResult = await _fileService.uploadFile(
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

                if (uploadResult.isSuccess && uploadResult.fileId != null) {
                  // Get the file attachment from Firestore
                  final fileAttachment = await _fileService.getFileMetadata(
                    uploadResult.fileId!,
                  );

                  if (fileAttachment != null) {
                    // Send file message using ChatService
                    await _chatService.sendFileMessage(
                      receiverId: widget.receiverUserId,
                      fileAttachment: fileAttachment,
                      textMessage: '',
                    );

                    // Determine the appropriate custom message type based on file
                    CustomMessageType messageType;
                    if (fileAttachment.isImage) {
                      messageType = CustomMessageType.image;
                    } else if (fileAttachment.isVideo) {
                      messageType = CustomMessageType
                          .document; // Videos as documents for now
                    } else if (fileAttachment.isAudio) {
                      messageType = CustomMessageType.voice;
                    } else {
                      messageType = CustomMessageType.document;
                    }

                    // Add to chat view
                    final customMessage = CustomMessage(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      message: messageType == CustomMessageType.image
                          ? 'Sent image: ${fileAttachment.originalFileName}'
                          : 'Sent file: ${fileAttachment.originalFileName}',
                      sender: currentUser,
                      createdAt: DateTime.now(),
                      customType: messageType,
                      extraData: {
                        'fileId': fileAttachment.fileId,
                        'fileName': fileAttachment.originalFileName,
                        'fileSize': fileAttachment.fileSizeBytes,
                        'downloadUrl': fileAttachment.downloadUrl,
                      },
                    );

                    chatController.addMessage(
                      customMessage.toChatViewMessage(),
                    );
                  } else {
                    _showErrorSnackBar('Failed to get file information');
                  }
                } else {
                  _showErrorSnackBar(
                    'Failed to upload file: ${uploadResult.error}',
                  );
                }
              } catch (e) {
                _showErrorSnackBar('Error uploading file: $e');
              } finally {
                setState(() {
                  _isUploading = false;
                  _uploadProgress = 0.0;
                  _statusMessage = null;
                });
              }
            }
          },
          maxFiles: 5,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send file: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    // Web has limited location support
    if (kIsWeb) {
      _showWebFeatureDialog(
        'Location sharing on web requires browser permission. Please allow location access when prompted.',
      );
      return true; // Allow the flow to continue, browser will handle permissions
    }

    try {
      final status = await Permission.location.status;
      if (status.isDenied) {
        final result = await Permission.location.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      // Platform not available, assume permission granted
      return true;
    }
  }

  Future<bool> _checkContactsPermission() async {
    // Web doesn't support native contacts access
    if (kIsWeb) {
      _showWebFeatureDialog(
        'Contact sharing is not supported on web. Please use the mobile app to share contacts.',
      );
      return false;
    }

    try {
      final status = await Permission.contacts.status;
      if (status.isDenied) {
        final result = await Permission.contacts.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      // Platform not available, assume permission granted
      return true;
    }
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showWebFeatureDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Not Available'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
