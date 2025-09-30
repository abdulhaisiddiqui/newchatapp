import 'package:chatapp/components/chat_bubble.dart';
import 'package:chatapp/components/file_picker_widget.dart';
import 'package:chatapp/components/call/call_screen_widget.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatapp/services/file/file_service.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/model/message.dart';
import 'package:chatapp/components/user_status_indicator.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' show AudioRecorder, RecordConfig;
import 'package:path_provider/path_provider.dart';

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
  bool _isRecording = false;
  AudioRecorder? _audioRecorder;
  String? _recordingPath;
  bool _isTyping = false;
  Timer? _typingTimer;

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

  Future<void> _startVoiceRecording() async {
    // Voice messages are not supported on web platform
    if (kIsWeb) {
      _showErrorSnackBar('Voice messages are not supported on web platform');
      return;
    }

    // Voice messages are only available on mobile platforms
    try {
      // Check microphone permission
      if (!await _checkMicrophonePermission()) {
        _showPermissionDeniedDialog(
          'Microphone permission is required for voice messages',
        );
        return;
      }

      // Check if already recording
      if (_isRecording) {
        await _stopVoiceRecording();
        return;
      }

      // Initialize audio recorder if not already done
      _audioRecorder ??= AudioRecorder();

      // Start recording
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        _showErrorSnackBar('Microphone permission denied');
        return;
      }

      // Create a unique file path for the recording
      final directory = await getApplicationDocumentsDirectory();
      _recordingPath =
          '${directory.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(const RecordConfig(), path: _recordingPath!);

      setState(() {
        _isRecording = true;
      });

      // Auto-stop after 60 seconds
      Future.delayed(const Duration(seconds: 60), () {
        if (_isRecording) {
          _stopVoiceRecording();
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      if (!_isRecording) return;

      final path = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordingPath != null) {
        // Send the voice message
        await _sendVoiceMessage(File(_recordingPath!));
      }

      _recordingPath = null;
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _sendVoiceMessage(File voiceFile) async {
    // Voice messages are not supported on web platform
    if (kIsWeb) {
      _showErrorSnackBar('Voice messages are not supported on web platform');
      return;
    }

    // For mobile platforms, show a message that voice messages are temporarily disabled
    // due to web compatibility issues. In a production app, you'd implement proper
    // mobile-only voice message handling.
    _showErrorSnackBar(
      'Voice messages are currently disabled due to compatibility issues',
    );
  }

  @override
  void initState() {
    super.initState();
    // Add listener to detect typing
    _messageController.addListener(_onTypingChanged);
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

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _typingTimer?.cancel();
    _audioRecorder?.dispose();
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
                if (!kIsWeb) ...[
                  Semantics(
                    label: _isRecording
                        ? 'Stop recording voice message'
                        : 'Record voice message',
                    hint: _isRecording
                        ? 'Tap to stop recording and send'
                        : 'Tap and hold to record a voice message',
                    child: GestureDetector(
                      onTap: _startVoiceRecording,
                      onLongPress: _startVoiceRecording,
                      onLongPressEnd: (_) => _stopVoiceRecording(),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic_none,
                        color: _isRecording ? Colors.red : Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
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
          child: StreamBuilder(
            stream: _chatService.getMessages(
              widget.receiverUserId,
              currentUser.uid,
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

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: snapshot.data!.docs
                    .map((document) => _buildMessageItem(document))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // 🔹 Firestore Single Message
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
