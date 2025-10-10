import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:flutter/foundation.dart';

class Message {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final MessageType type;
  final bool isRead;
  final String? replyToMessageId;
  final FileAttachment? fileAttachment;
  final bool isEdited;

  Message({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isRead,
    this.replyToMessageId,
    this.fileAttachment,
    required this.isEdited,
  });
  bool get hasText => message.isNotEmpty;
  factory Message.fromMap(Map<String, dynamic> map) {
    // Handle timestamp or createdAt
    Timestamp timestamp;
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        timestamp = map['timestamp'] as Timestamp;
      } else if (map['timestamp'] is int) {
        timestamp = Timestamp.fromMillisecondsSinceEpoch(map['timestamp'] as int);
        debugPrint('Converted int timestamp to Timestamp: ${map['timestamp']}');
      } else {
        timestamp = Timestamp.now();
        debugPrint('Invalid timestamp format: ${map['timestamp']}, using Timestamp.now()');
      }
    } else if (map['createdAt'] != null) {
      // Handle CustomMessage format
      if (map['createdAt'] is Timestamp) {
        timestamp = map['createdAt'] as Timestamp;
      } else if (map['createdAt'] is int) {
        timestamp = Timestamp.fromMillisecondsSinceEpoch(map['createdAt'] as int);
        debugPrint('Converted int createdAt to Timestamp: ${map['createdAt']}');
      } else {
        timestamp = Timestamp.now();
        debugPrint('Invalid createdAt format: ${map['createdAt']}, using Timestamp.now()');
      }
    } else {
      timestamp = Timestamp.now();
      debugPrint('No timestamp or createdAt found, using Timestamp.now()');
    }

    // Determine message type
    MessageType type;
    if (map['customType'] != null) {
      // Handle CustomMessage types
      switch (map['customType']) {
        case 'location':
          type = MessageType.location;
          break;
        case 'contact':
          type = MessageType.contact;
          break;
        default:
          type = MessageType.text;
      }
    } else {
      type = MessageType.values.firstWhere(
            (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      );
    }

    return Message(
      id: map['id'] as String? ?? map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? map['sender']?['id'] as String? ?? 'unknown',
      senderEmail: map['senderEmail'] as String? ?? map['sender']?['name'] as String? ?? 'unknown@example.com',
      receiverId: map['receiverId'] as String? ?? 'unknown',
      message: map['message'] as String? ?? '',
      timestamp: timestamp,
      type: type,
      isRead: map['isRead'] as bool? ?? false,
      replyToMessageId: map['replyToMessageId'] as String?,
      fileAttachment: map['fileAttachment'] != null
          ? FileAttachment.fromMap(map['fileAttachment'] as Map<String, dynamic>)
          : null,
      isEdited: map['isEdited'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': type.toString().split('.').last,
      'isRead': isRead,
      'replyToMessageId': replyToMessageId,
      'fileAttachment': fileAttachment?.toMap(),
      'isEdited': isEdited,
    };
  }
}