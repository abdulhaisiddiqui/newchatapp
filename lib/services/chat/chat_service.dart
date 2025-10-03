import 'package:chatapp/model/message.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


class ChatService extends ChangeNotifier {
  // get instance of auth and firestore
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //SEND TEXT MESSAGES
  Future<void> sendMessage(String receiverId, String message) async {
    await sendTextMessage(receiverId, message);
  }

  //SEND TEXT MESSAGES (Enhanced)
  Future<void> sendTextMessage(String receiverId, String message) async {
    //get current user info
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;
    final String currentUserEmail = currentUser.email ?? 'unknown@example.com';
    final Timestamp timestamp = Timestamp.now();

    //create a new message
    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      type: MessageType.text,
    );

    await _sendMessageToFirestore(newMessage, receiverId);
  }

  //SEND FILE MESSAGES
  Future<void> sendFileMessage({
    required String receiverId,
    required FileAttachment fileAttachment,
    String? textMessage,
  }) async {
    //get current user info
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;
    final String currentUserEmail = currentUser.email ?? 'unknown@example.com';
    final Timestamp timestamp = Timestamp.now();

    //create a new file message
    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: textMessage ?? '',
      timestamp: timestamp,
      type: MessageType.fromMimeType(fileAttachment.mimeType),
      fileAttachment: fileAttachment,
    );

    await _sendMessageToFirestore(newMessage, receiverId);
  }

  //SEND REPLY MESSAGE
  Future<void> sendReplyMessage({
    required String receiverId,
    required String message,
    required String replyToMessageId,
    MessageType type = MessageType.text,
    FileAttachment? fileAttachment,
  }) async {
    //get current user info
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;
    final String currentUserEmail = currentUser.email ?? 'unknown@example.com';
    final Timestamp timestamp = Timestamp.now();

    //create a new reply message
    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      type: type,
      fileAttachment: fileAttachment,
      replyToMessageId: replyToMessageId,
    );

    await _sendMessageToFirestore(newMessage, receiverId);
  }

  //EDIT MESSAGE
  Future<void> editMessage({
    required String messageId,
    required String chatRoomId,
    required String newMessage,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;

    try {
      // Get the original message to verify ownership
      DocumentSnapshot messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      Map<String, dynamic> messageData =
          messageDoc.data() as Map<String, dynamic>;

      // Check if current user is the sender
      if (messageData['senderId'] != currentUserId) {
        throw Exception('You can only edit your own messages');
      }

      // Update the message
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({
            'message': newMessage,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to edit message: ${e.toString()}');
    }
  }

  //DELETE MESSAGE
  Future<void> deleteMessage({
    required String messageId,
    required String chatRoomId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;

    try {
      // Get the message to verify ownership and check for file attachments
      DocumentSnapshot messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      Map<String, dynamic> messageData =
          messageDoc.data() as Map<String, dynamic>;

      // Check if current user is the sender
      if (messageData['senderId'] != currentUserId) {
        throw Exception('You can only delete your own messages');
      }

      // If message has file attachment, delete the file too
      if (messageData['fileAttachment'] != null) {
        // Note: File deletion would be handled by FileService
        // FileAttachment fileAttachment = FileAttachment.fromMap(messageData['fileAttachment']);
        // await FileService().deleteFile(fileId: fileAttachment.fileId, chatRoomId: chatRoomId);
      }

      // Delete the message
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  //HELPER METHOD TO SEND MESSAGE TO FIRESTORE
  Future<void> _sendMessageToFirestore(
      Message message,
      String receiverId,
      ) async {
    List<String> ids = [message.senderId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // 1. Save message
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());

    // 2. Update chat room metadata
    await _updateChatRoomMetadata(chatRoomId, message);

    // 3. Send push notification to receiver
    await _sendNotificationToReceiver(receiverId, message.message);
  }

  Future<void> _sendNotificationToReceiver(String receiverId, String message) async {
    try {
      // Get receiver tokens
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(receiverId).get();

      if (!userDoc.exists) return;

      List<dynamic> tokens = userDoc['fcmTokens'] ?? [];
      if (tokens.isEmpty) return;

      for (String token in tokens) {
        await FirebaseMessaging.instance.sendMessage(
          to: token,
          data: {
            'title': 'New Message',
            'body': message,
          },
        );
      }
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
  }


  //UPDATE CHAT ROOM METADATA
  Future<void> _updateChatRoomMetadata(
    String chatRoomId,
    Message message,
  ) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'members': [message.senderId, message.receiverId],
        'lastMessage': message.toMap(),
        'lastActivity': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
        if (message.hasFileAttachment) 'fileCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // Don't throw error for metadata update failure
      debugPrint('Failed to update chat room metadata: $e');
    }
  }

  //GET MESSAGES WITH ENHANCED PARSING
  Stream<List<Message>> getMessagesStream(String userId, String otherUserId) {
    //construct chat room id from user ids (sorted to ensure it matches the id used when sending messages)
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> docData = doc.data();
            Map<String, dynamic> data = Map<String, dynamic>.from(docData);
            data['id'] = doc.id; // Add document ID for editing/deleting
            return Message.fromMap(data);
          }).toList();
        });
  }

  //GET MESSAGES (Legacy - for backward compatibility)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    //construct chat room id from user ids (sorted to ensure it matches the id used when sending messages)
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  //GET CHAT ROOM ID
  String getChatRoomId(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    return ids.join("_");
  }

  //SEARCH MESSAGES
  Future<List<Message>> searchMessages({
    required String chatRoomId,
    required String query,
    MessageType? type,
  }) async {
    try {
      Query messagesQuery = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (type != null) {
        messagesQuery = messagesQuery.where('type', isEqualTo: type.name);
      }

      QuerySnapshot snapshot = await messagesQuery.get();

      List<Message> messages = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
          .where(
            (message) =>
                message.message.toLowerCase().contains(query.toLowerCase()) ||
                (message.fileAttachment?.originalFileName
                        .toLowerCase()
                        .contains(query.toLowerCase()) ??
                    false),
          )
          .toList();

      return messages;
    } catch (e) {
      throw Exception('Search failed: ${e.toString()}');
    }
  }

  //GET FILES FROM CHAT
  Future<List<FileAttachment>> getChatFiles({
    required String chatRoomId,
    MessageType? fileType,
  }) async {
    try {
      Query messagesQuery = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('type', whereNotIn: ['text'])
          .orderBy('timestamp', descending: true);

      if (fileType != null) {
        messagesQuery = messagesQuery.where('type', isEqualTo: fileType.name);
      }

      QuerySnapshot snapshot = await messagesQuery.get();

      List<FileAttachment> files = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
          .where((message) => message.fileAttachment != null)
          .map((message) => message.fileAttachment!)
          .toList();

      return files;
    } catch (e) {
      throw Exception('Failed to get chat files: ${e.toString()}');
    }
  }


}
