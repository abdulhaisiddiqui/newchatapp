import 'package:chatapp/model/custom_message.dart';
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:chatview/chatview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  late ChatController chatController;
  late ChatUser currentUser;
  late ChatUser otherUser;

  @override
  void initState() {
    super.initState();
    _initializeChat();
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

    _loadMessages();
  }

  void _loadMessages() async {
    final messages = await _chatService
        .getMessagesStream(currentUser.id, otherUser.id)
        .first;

    final chatViewMessages = messages.map((msg) {
      // Try to parse as custom message first
      final customMessage = CustomMessage.fromFirestore({
        'id': msg.timestamp.millisecondsSinceEpoch.toString(),
        'message': msg.message,
        'senderId': msg.senderId,
        'senderEmail': msg.senderEmail,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
        'customType': 'text', // Default to text
        'extraData': {},
      }, currentUser.id == msg.senderId ? currentUser : otherUser);

      return customMessage.toChatViewMessage();
    }).toList();

    chatController.loadMoreData(chatViewMessages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.receiverUserEmail,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
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
      body: ChatView(
        chatController: chatController,
        onSendTap: _onSendMessage,
        chatViewState: ChatViewState.hasMessages,
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
    );

    chatController.addMessage(newMessage);

    // Send to Firebase
    _chatService.sendMessage(widget.receiverUserId, message);
  }
}
