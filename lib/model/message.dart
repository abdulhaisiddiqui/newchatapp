import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/model/message_type.dart';

class Message {
  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final MessageType type;
  final FileAttachment? fileAttachment;
  final String? replyToMessageId;
  final bool isEdited;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.type,
    this.fileAttachment,
    this.replyToMessageId,
    this.isEdited = false,
    required this.isRead,
  });

  bool get hasText => message.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': type.name,
      'replyToMessageId': replyToMessageId,
      'fileAttachment': fileAttachment?.toMap(),
      'isRead': isRead,
      'isEdited': isEdited,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback ID
      senderId: map['senderId'] as String? ?? 'unknown', // Fallback senderId
      senderEmail: map['senderEmail'] as String? ?? 'unknown@example.com', // Fallback email
      receiverId: map['receiverId'] as String? ?? 'unknown', // Fallback receiverId
      message: map['message'] as String? ?? '', // Fallback to empty string
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(), // Fallback timestamp
      type: map['type'] != null
          ? MessageType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      )
          : MessageType.text,
      fileAttachment: map['fileAttachment'] != null
          ? FileAttachment.fromMap(map['fileAttachment'] as Map<String, dynamic>)
          : null,
      isRead: map['isRead'] as bool? ?? false,
      replyToMessageId: map['replyToMessageId'] as String?,
      isEdited: map['isEdited'] as bool? ?? false,
    );
  }
}