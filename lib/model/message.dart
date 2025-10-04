import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/model/file_attachment.dart';

class Message {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;

  // New file-related fields
  final MessageType type;
  final FileAttachment? fileAttachment;
  final String? replyToMessageId;
  final bool isEdited;
  final Timestamp? editedAt;
  final bool isRead;

  Message({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.type = MessageType.text,
    this.fileAttachment,
    this.replyToMessageId,
    this.isEdited = false,
    this.editedAt,
    this.isRead = false,
  });

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': type.name,
      'fileAttachment': fileAttachment?.toMap(),
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'isRead': isRead,
    };
  }

  // Create from Firestore map
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      type: MessageType.fromString(map['type'] ?? 'text'),
      fileAttachment: map['fileAttachment'] != null
          ? FileAttachment.fromMap(map['fileAttachment'])
          : null,
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'],
      isRead: map['isRead'] ?? false,
    );
  }

  // Helper methods
  bool get hasFileAttachment => fileAttachment != null;
  bool get isFileMessage => type != MessageType.text;
  bool get hasText => message.isNotEmpty;

  // Copy with method for updates
  Message copyWith({
    String? senderId,
    String? senderEmail,
    String? receiverId,
    String? message,
    Timestamp? timestamp,
    MessageType? type,
    FileAttachment? fileAttachment,
    String? replyToMessageId,
    bool? isEdited,
    Timestamp? editedAt,
    bool? isRead,
  }) {
    return Message(
      senderId: senderId ?? this.senderId,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      fileAttachment: fileAttachment ?? this.fileAttachment,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    final messagePreview = message.isNotEmpty && message.length > 50
        ? '${message.substring(0, 50)}...'
        : message;
    return 'Message(senderId: $senderId, type: ${type.displayName}, hasFile: $hasFileAttachment, message: $messagePreview)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.senderId == senderId &&
        other.receiverId == receiverId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      senderId.hashCode ^ receiverId.hashCode ^ timestamp.hashCode;
}
