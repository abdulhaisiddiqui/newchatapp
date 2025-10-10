import 'package:chatapp/model/message.dart' as app_message;
import 'package:chatapp/model/message_type.dart' as app_message_type;
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/model/custom_message.dart';
import 'package:chatapp/services/notification_service.dart';
import 'package:chatview/chatview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rxdart/rxdart.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SEND TEXT MESSAGES
  Future<void> sendMessage(String receiverId, String message, {required String messageId}) async {
    await sendTextMessage(receiverId, message, messageId: messageId);
  }

  // CREATE GROUP CHAT
  Future<String?> createGroupChat({
    required List<String> memberIds,
    required String groupName,
    String? groupDescription,
    String? groupAvatar,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    if (memberIds.length < 2) {
      throw Exception('Group chat must have at least 2 members');
    }

    final allMembers = List<String>.from(memberIds);
    if (!allMembers.contains(currentUser.uid)) {
      allMembers.add(currentUser.uid);
    }

    allMembers.sort();
    final chatRoomId = allMembers.join("_");

    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'members': allMembers,
        'chatType': 'group',
        'groupName': groupName,
        'groupDescription': groupDescription,
        'groupAvatar': groupAvatar,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'memberCount': allMembers.length,
      }, SetOptions(merge: true));

      return chatRoomId;
    } catch (e) {
      throw Exception('Failed to create group chat: ${e.toString()}');
    }
  }

  // SEND TEXT MESSAGES (Enhanced)
  Future<void> sendTextMessage(String receiverId, String message, {required String messageId}) async {
    final currentUser = _firebaseAuth.currentUser!;
    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    final newMessage = app_message.Message(
      id: messageId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'unknown@example.com',
      receiverId: receiverId,
      message: message,
      timestamp: Timestamp.now(),
      type: app_message_type.MessageType.text,
      isRead: false,
      isEdited: false,
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, newMessage.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [currentUser.uid, receiverId],
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'hiddenFor': FieldValue.arrayRemove([currentUser.uid]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, message);
  }

  // SEND REPLY MESSAGE
  Future<void> sendReplyMessage({
    required String receiverId,
    required String message,
    required String replyToMessageId,
    required String messageId,
    app_message_type.MessageType type = app_message_type.MessageType.text,
    FileAttachment? fileAttachment,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    final messageType = fileAttachment != null
        ? app_message_type.MessageType.fromMimeType(fileAttachment.mimeType)
        : type;

    final newMessage = app_message.Message(
      id: messageId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'unknown@example.com',
      receiverId: receiverId,
      message: message.isNotEmpty ? message : '',
      timestamp: Timestamp.now(),
      type: messageType,
      fileAttachment: fileAttachment,
      isRead: false,
      replyToMessageId: replyToMessageId,
      isEdited: false,
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, newMessage.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [currentUser.uid, receiverId],
        'lastMessage': message.isNotEmpty ? message : 'Attachment',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'hiddenFor': FieldValue.arrayRemove([currentUser.uid]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, message.isNotEmpty ? message : 'Replied with attachment');
  }

  // SEND FILE MESSAGES
  Future<void> sendFileMessage({
    required String receiverId,
    required FileAttachment fileAttachment,
    String? textMessage,
    required String messageId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    final newMessage = app_message.Message(
      id: messageId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'unknown@example.com',
      receiverId: receiverId,
      message: textMessage ?? '',
      timestamp: Timestamp.now(),
      type: app_message_type.MessageType.fromMimeType(fileAttachment.mimeType),
      fileAttachment: fileAttachment,
      isRead: false,
      isEdited: false,
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, newMessage.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [currentUser.uid, receiverId],
        'lastMessage': textMessage ?? 'Attachment',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'fileCount': FieldValue.increment(1),
        'hiddenFor': FieldValue.arrayRemove([currentUser.uid]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, textMessage ?? 'Sent a file');
  }

  // SEND CONTACT MESSAGES
  Future<void> sendContactMessage({
    required String receiverId,
    required String contactName,
    required String contactPhone,
    required String messageId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    final newMessage = app_message.Message(
      id: messageId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'unknown@example.com',
      receiverId: receiverId,
      message: 'Shared contact: $contactName ($contactPhone)',
      timestamp: Timestamp.now(),
      type: app_message_type.MessageType.contact,
      isRead: false,
      isEdited: false,
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, newMessage.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [currentUser.uid, receiverId],
        'lastMessage': newMessage.message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'hiddenFor': FieldValue.arrayRemove([currentUser.uid]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, newMessage.message);
  }

  // SEND LOCATION MESSAGES
  Future<void> sendLocationMessage({
    required String receiverId,
    required double latitude,
    required double longitude,
    String? mapsUrl,
    required String messageId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    final messageContent = mapsUrl ?? 'Shared location: ($latitude, $longitude)';
    final newMessage = app_message.Message(
      id: messageId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'unknown@example.com',
      receiverId: receiverId,
      message: messageContent,
      timestamp: Timestamp.now(),
      type: app_message_type.MessageType.location,
      isRead: false,
      isEdited: false,
    );

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, newMessage.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [currentUser.uid, receiverId],
        'lastMessage': newMessage.message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'hiddenFor': FieldValue.arrayRemove([currentUser.uid]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, newMessage.message);
  }

  // EDIT MESSAGE
  Future<void> editMessage({
    required String messageId,
    required String chatRoomId,
    required String newMessage,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;
      if (messageData['senderId'] != currentUser.uid) {
        throw Exception('You can only edit your own messages');
      }

      final batch = _firestore.batch();
      batch.update(
        _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId),
        {
          'message': newMessage,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        _firestore.collection('chat_rooms').doc(chatRoomId),
        {
          'lastMessage': newMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUser.uid,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to edit message: ${e.toString()}');
    }
  }

  // DELETE MESSAGE
  Future<void> deleteMessage({
    required String messageId,
    required String chatRoomId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;
      if (messageData['senderId'] != currentUser.uid) {
        throw Exception('You can only delete your own messages');
      }

      final batch = _firestore.batch();
      batch.delete(
        _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId),
      );
      if (messageData['fileAttachment'] != null) {
        // Note: File deletion should be handled by FileService
        // final fileAttachment = FileAttachment.fromMap(messageData['fileAttachment']);
        // batch.delete(...); // Add file deletion logic if needed
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  // HELPER METHOD TO SEND MESSAGE TO FIRESTORE
  Future<void> _sendMessageToFirestore(
      app_message.Message message,
      String receiverId, {
        List<String>? additionalMembers,
      }) async {
    List<String> members;
    String chatRoomId;

    if (additionalMembers != null && additionalMembers.isNotEmpty) {
      members = [message.senderId, receiverId, ...additionalMembers];
      members.sort();
      chatRoomId = members.join("_");
    } else {
      members = [message.senderId, receiverId];
      members.sort();
      chatRoomId = members.join("_");
    }

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(message.id);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save message
    batch.set(messageRef, message.toMap());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': members,
        'lastMessage': message.message.isNotEmpty ? message.message : 'Attachment',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': message.senderId,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'messageCount': FieldValue.increment(1),
        if (message.fileAttachment != null) 'fileCount': FieldValue.increment(1),
        'chatType': members.length > 2 ? 'group' : 'direct',
        'hiddenFor': FieldValue.arrayRemove([message.senderId]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notifications to all receivers except sender
    final receivers = members.where((id) => id != message.senderId).toList();
    for (final receiver in receivers) {
      await _sendNotificationToReceiver(receiver, message.message.isNotEmpty ? message.message : 'Sent an attachment');
    }
  }

  // HELPER METHOD TO SEND CUSTOM MESSAGE TO FIRESTORE
  Future<void> _sendCustomMessageToFirestore(
      CustomMessage customMessage,
      String receiverId,
      ) async {
    final chatRoomId = getChatRoomId(customMessage.sender.id, receiverId);

    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(customMessage.id);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    // Save custom message
    batch.set(messageRef, customMessage.toFirestore());

    // Update chat room metadata
    batch.set(
      chatRoomRef,
      {
        'members': [customMessage.sender.id, receiverId],
        'lastMessage': customMessage.message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': customMessage.sender.id,
        'unreadCount': {receiverId: FieldValue.increment(1)},
        'chatType': 'direct',
        'hiddenFor': FieldValue.arrayRemove([customMessage.sender.id]),
      },
      SetOptions(merge: true),
    );

    // Commit batch
    await batch.commit();

    // Send notification
    await _sendNotificationToReceiver(receiverId, customMessage.message);
  }

  // SEND NOTIFICATION TO RECEIVER
  Future<void> _sendNotificationToReceiver(
      String receiverId,
      String message,
      ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!userDoc.exists) return;

      final tokens = userDoc['fcmTokens'] as List<dynamic>? ?? [];
      if (tokens.isEmpty) return;

      // Replace with your actual FCM server key from Firebase Console > Project Settings > Cloud Messaging
      const String serverKey = 'YOUR_ACTUAL_FCM_SERVER_KEY'; // TODO: Replace this

      for (final token in tokens) {
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
              'body': message.length > 100 ? '${message.substring(0, 100)}...' : message,
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
      debugPrint('Failed to send notification: $e');
    }
  }

  // UPDATE CHAT ROOM METADATA
  Future<void> _updateChatRoomMetadata(
      String chatRoomId,
      app_message.Message message, {
        List<String>? members,
      }) async {
    try {
      final batch = _firestore.batch();
      final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

      final metadata = {
        'members': members ?? [message.senderId, message.receiverId],
        'lastMessage': message.message.isNotEmpty ? message.message : 'Attachment',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': message.senderId,
        'messageCount': FieldValue.increment(1),
        if (message.fileAttachment != null) 'fileCount': FieldValue.increment(1),
        'hiddenFor': FieldValue.arrayRemove([message.senderId]),
      };

      if (members != null && members.length > 2) {
        metadata['memberCount'] = members.length;
        metadata['chatType'] = 'group';
      }

      batch.set(chatRoomRef, metadata, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to update chat room metadata: $e');
    }
  }

  // INCREMENT UNREAD COUNT FOR RECEIVER
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

  // GET MESSAGES WITH ENHANCED PARSING

  Stream<List<app_message.Message>> getMessagesStream(
      String userId,
      String otherUserId,
      ) {
    final chatRoomId = getChatRoomId(userId, otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .debounceTime(Duration(milliseconds: 200))
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Set default values for missing fields
        data['senderId'] ??= data['sender']?['id'] ?? 'unknown';
        data['senderEmail'] ??= data['sender']?['name'] ?? 'unknown@example.com';
        data['receiverId'] ??= 'unknown';
        data['message'] ??= '';
        data['isRead'] ??= false;
        data['isEdited'] ??= false;
        // Handle timestamp or createdAt
        if (data['timestamp'] == null && data['createdAt'] != null) {
          data['timestamp'] = data['createdAt'];
        }
        data['timestamp'] ??= Timestamp.now();
        // Handle type or customType
        if (data['type'] == null && data['customType'] != null) {
          data['type'] = data['customType'] == 'location'
              ? app_message_type.MessageType.location.name
              : data['customType'] == 'contact'
              ? app_message_type.MessageType.contact.name
              : app_message_type.MessageType.text.name;
        }
        data['type'] ??= app_message_type.MessageType.text.name;
        try {
          return app_message.Message.fromMap(data);
        } catch (e) {
          debugPrint('Error parsing message: $e, Data: $data');
          return app_message.Message(
            id: doc.id,
            senderId: 'unknown',
            senderEmail: 'unknown@example.com',
            receiverId: 'unknown',
            message: 'Error loading message',
            timestamp: Timestamp.now(),
            type: app_message_type.MessageType.text,
            isRead: false,
            isEdited: false,
          );
        }
      }).toList();
    });
  }

  // GET MESSAGES (Legacy)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    final chatRoomId = getChatRoomId(userId, otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // GET CHAT ROOM ID
  String getChatRoomId(String userId, String otherUserId) {
    final ids = [userId, otherUserId];
    ids.sort();
    return ids.join("_");
  }

  // SEARCH MESSAGES
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

      final snapshot = await messagesQuery.get();

      final messages = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return app_message.Message.fromMap(data);
      })
          .where(
            (message) =>
        message.message.toLowerCase().contains(query.toLowerCase()) ||
            (message.fileAttachment?.originalFileName
                ?.toLowerCase()
                .contains(query.toLowerCase()) ??
                false),
      )
          .toList();

      return messages;
    } catch (e) {
      throw Exception('Search failed: ${e.toString()}');
    }
  }

  // GET UNREAD MESSAGE COUNT
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

  // MARK MESSAGES AS READ
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
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.set(
        _firestore.collection('chat_rooms').doc(chatRoomId),
        {'unreadCount': {currentUserId: 0}},
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // GET CHAT FILES
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

      final snapshot = await messagesQuery.get();

      final files = snapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => app_message.Message.fromMap(doc.data() as Map<String, dynamic>))
          .where((message) => message.fileAttachment != null)
          .map((message) => message.fileAttachment!)
          .toList();

      return files;
    } catch (e) {
      throw Exception('Failed to get chat files: ${e.toString()}');
    }
  }

  // SHOW LOCAL NOTIFICATION
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
        messageText: message.length > 100 ? '${message.substring(0, 100)}...' : message,
        receiverId: receiverId,
        receiverEmail: receiverEmail,
      );
    } catch (e) {
      debugPrint('Error showing message notification: $e');
    }
  }
}