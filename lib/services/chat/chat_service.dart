import 'package:chatapp/model/message.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email.toString();
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
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email.toString();
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
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email.toString();
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
    final String currentUserId = _firebaseAuth.currentUser!.uid;

    try {
      // Get the original message to verify ownership
      DocumentSnapshot messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('message')
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
          .collection('message')
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
    final String currentUserId = _firebaseAuth.currentUser!.uid;

    try {
      // Get the message to verify ownership and check for file attachments
      DocumentSnapshot messageDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('message')
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
        FileAttachment fileAttachment = FileAttachment.fromMap(
          messageData['fileAttachment'],
        );
        // Note: File deletion would be handled by FileService
        // await FileService().deleteFile(fileId: fileAttachment.fileId, chatRoomId: chatRoomId);
      }

      // Delete the message
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('message')
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
    //construct chat room id from current user id and receiver id (sorted to ensure uniqueness)
    List<String> ids = [message.senderId, receiverId];
    ids.sort(); // sort the ids (this ensures the chat room id is always the same for any pair of people)
    String chatRoomId = ids.join("_");

    //add a new message to database
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('message')
        .add(message.toMap());

    //update chat room metadata
    await _updateChatRoomMetadata(chatRoomId, message);
  }

  //UPDATE CHAT ROOM METADATA
  Future<void> _updateChatRoomMetadata(
    String chatRoomId,
    Message message,
  ) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'participants': [message.senderId, message.receiverId],
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
        .collection('message')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
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
        .collection('message')
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
          .collection('message')
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (type != null) {
        messagesQuery = messagesQuery.where('type', isEqualTo: type.name);
      }

      QuerySnapshot snapshot = await messagesQuery.get();

      List<Message> messages = snapshot.docs
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
          .collection('message')
          .where('type', whereNotIn: ['text'])
          .orderBy('timestamp', descending: true);

      if (fileType != null) {
        messagesQuery = messagesQuery.where('type', isEqualTo: fileType.name);
      }

      QuerySnapshot snapshot = await messagesQuery.get();

      List<FileAttachment> files = snapshot.docs
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
