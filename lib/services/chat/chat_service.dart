import 'package:chatapp/model/message.dart' as app_message;
import 'package:chatapp/model/message_type.dart' as app_message_type;
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/model/custom_message.dart';
import 'package:chatapp/services/notification_service.dart';
import 'package:chatview/chatview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    app_message.Message newMessage = app_message.Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      type: app_message_type.MessageType.text,
      isRead: false, // New messages are unread by default
    );

    await _sendMessageToFirestore(newMessage, receiverId);
  }

  //SEND CONTACT MESSAGES (Updated for CustomMessage)
  Future<void> sendContactMessage({
    required String receiverId,
    required String contactName,
    required String contactPhone,
  }) async {
    //get current user info
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;
    final String currentUserEmail = currentUser.email ?? 'unknown@example.com';

    // Create ChatUser for chatview
    final ChatUser sender = ChatUser(id: currentUserId, name: currentUserEmail);

    // Create custom message
    final customMessage = CustomMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: 'Shared contact: $contactName',
      sender: sender,
      createdAt: DateTime.now(),
      customType: CustomMessageType.contact,
      extraData: {
        'name': contactName,
        'phone': contactPhone,
        'senderEmail': currentUserEmail,
      },
    );

    await _sendCustomMessageToFirestore(customMessage, receiverId);
  }

  //SEND LOCATION MESSAGES (Updated for CustomMessage)
  Future<void> sendLocationMessage({
    required String receiverId,
    required double latitude,
    required double longitude,
    String? mapsUrl,
  }) async {
    //get current user info
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final String currentUserId = currentUser.uid;
    final String currentUserEmail = currentUser.email ?? 'unknown@example.com';

    // Create ChatUser for chatview
    final ChatUser sender = ChatUser(id: currentUserId, name: currentUserEmail);

    // Create custom message
    final customMessage = CustomMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: 'Shared location',
      sender: sender,
      createdAt: DateTime.now(),
      customType: CustomMessageType.location,
      extraData: {
        'lat': latitude,
        'lng': longitude,
        'address': 'Shared location',
        'mapsUrl': mapsUrl,
        'senderEmail': currentUserEmail,
      },
    );

    await _sendCustomMessageToFirestore(customMessage, receiverId);
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
    app_message.Message newMessage = app_message.Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: textMessage ?? '',
      timestamp: timestamp,
      type: app_message_type.MessageType.fromMimeType(fileAttachment.mimeType),
      fileAttachment: fileAttachment,
      isRead: false, // New messages are unread by default
    );

    await _sendMessageToFirestore(newMessage, receiverId);
  }

  //SEND REPLY MESSAGE
  Future<void> sendReplyMessage({
    required String receiverId,
    required String message,
    required String replyToMessageId,
    app_message_type.MessageType type = app_message_type.MessageType.text,
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
    app_message.Message newMessage = app_message.Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      type: type,
      fileAttachment: fileAttachment,
      replyToMessageId: replyToMessageId,
      isRead: false, // New messages are unread by default
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
    app_message.Message message,
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

    // 3. Increment unread count for receiver
    await _incrementUnreadCount(chatRoomId, receiverId);

    // 4. Send push notification to receiver
    await _sendNotificationToReceiver(receiverId, message.message);
  }

  //HELPER METHOD TO SEND CUSTOM MESSAGE TO FIRESTORE
  Future<void> _sendCustomMessageToFirestore(
    CustomMessage customMessage,
    String receiverId,
  ) async {
    List<String> ids = [customMessage.sender.id, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // 1. Save custom message
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(customMessage.toFirestore());

    // 2. Create a legacy Message object for metadata update
    final legacyMessage = app_message.Message(
      senderId: customMessage.sender.id,
      senderEmail: customMessage.extraData?['senderEmail'] ?? '',
      receiverId: receiverId,
      message: customMessage.message,
      timestamp: Timestamp.fromDate(customMessage.createdAt),
      type: app_message_type.MessageType.text,
      isRead: false,
    );

    // 3. Update chat room metadata
    await _updateChatRoomMetadata(chatRoomId, legacyMessage);

    // 4. Send push notification to receiver
    await _sendNotificationToReceiver(receiverId, customMessage.message);
  }

  //HELPER METHOD TO SEND MESSAGE TO FIRESTORE WITH CUSTOM DATA
  Future<void> _sendMessageToFirestoreWithData(
    Map<String, dynamic> messageData,
    String receiverId,
  ) async {
    final senderId = messageData['senderId'] as String;
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // 1. Save message with custom data
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2. Create a Message object for metadata update
    final message = app_message.Message.fromMap(messageData);

    // 3. Update chat room metadata
    await _updateChatRoomMetadata(chatRoomId, message);

    // 4. Send push notification to receiver
    await _sendNotificationToReceiver(receiverId, message.message);
  }

  Future<void> _sendNotificationToReceiver(
    String receiverId,
    String message,
  ) async {
    try {
      // Get receiver tokens
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();

      if (!userDoc.exists) return;

      List<dynamic> tokens = userDoc['fcmTokens'] ?? [];
      if (tokens.isEmpty) return;

      // FCM Server Key - Get this from Firebase Console > Project Settings > Cloud Messaging > Server Key
      const String serverKey =
          'YOUR_FCM_SERVER_KEY_HERE'; // Replace with actual server key

      for (String token in tokens) {
        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$serverKey',
          },
          body: jsonEncode({
            'to': token,
            'notification': {
              'title': 'New Message',
              'body': message.length > 100
                  ? '${message.substring(0, 100)}...'
                  : message,
              'sound': 'default',
              'badge': '1',
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'message_type': 'chat_message',
              'sender_id': _firebaseAuth.currentUser?.uid ?? '',
              'receiver_id': receiverId,
            },
            'priority': 'high',
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('Push notification sent successfully to $token');
        } else {
          debugPrint('Failed to send push notification: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
  }

  //UPDATE CHAT ROOM METADATA
  Future<void> _updateChatRoomMetadata(
    String chatRoomId,
    app_message.Message message,
  ) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'members': [message.senderId, message.receiverId],
        'lastMessage': message.toMap(),
        'lastActivity': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
        if (message.fileAttachment != null)
          'fileCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // Don't throw error for metadata update failure
      debugPrint('Failed to update chat room metadata: $e');
    }
  }

  //INCREMENT UNREAD COUNT FOR RECEIVER
  Future<void> _incrementUnreadCount(
    String chatRoomId,
    String receiverId,
  ) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'unreadCount': {receiverId: FieldValue.increment(1)},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to increment unread count: $e');
    }
  }

  //GET MESSAGES WITH ENHANCED PARSING
  Stream<List<app_message.Message>> getMessagesStream(
    String userId,
    String otherUserId,
  ) {
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
            return app_message.Message.fromMap(data);
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
  Future<List<app_message.Message>> searchMessages({
    required String chatRoomId,
    required String query,
    app_message_type.MessageType? type,
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

      List<app_message.Message> messages = snapshot.docs
          .where((doc) => doc.data() != null)
          .map(
            (doc) =>
                app_message.Message.fromMap(doc.data() as Map<String, dynamic>),
          )
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

  //GET UNREAD MESSAGE COUNT FOR A CHAT
  Future<int> getUnreadMessageCount(
    String chatRoomId,
    String currentUserId,
  ) async {
    try {
      final messages = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      return messages.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  //MARK MESSAGES AS READ
  Future<void> markMessagesAsRead(
    String chatRoomId,
    String currentUserId,
  ) async {
    try {
      final unreadMessages = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Reset unread count in parent chat room document
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'unreadCount': {currentUserId: 0},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  //GET FILES FROM CHAT
  Future<List<FileAttachment>> getChatFiles({
    required String chatRoomId,
    app_message_type.MessageType? fileType,
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
          .map(
            (doc) =>
                app_message.Message.fromMap(doc.data() as Map<String, dynamic>),
          )
          .where((message) => message.fileAttachment != null)
          .map((message) => message.fileAttachment!)
          .toList();

      return files;
    } catch (e) {
      throw Exception('Failed to get chat files: ${e.toString()}');
    }
  }

  // 📬 Show local notification for new message
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String chatRoomId,
    required String receiverId,
    required String receiverEmail,
  }) async {
    try {
      await NotificationService().showMessageNotification(
        chatRoomId: chatRoomId,
        senderName: senderName,
        messageText: message.length > 100
            ? '${message.substring(0, 100)}...'
            : message,
        receiverId: receiverId,
        receiverEmail: receiverEmail,
      );
    } catch (e) {
      debugPrint('Error showing message notification: $e');
    }
  }
}
