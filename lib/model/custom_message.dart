import 'package:chatview/chatview.dart';

enum CustomMessageType { text, image, location, contact, voice, document }

class CustomMessage {
  final String id;
  final String message;
  final ChatUser sender;
  final DateTime createdAt;
  final CustomMessageType customType;
  final Map<String, dynamic>? extraData;
  final MessageType messageType;
  final Reaction reaction;

  CustomMessage({
    required this.id,
    required this.message,
    required this.sender,
    required this.createdAt,
    this.customType = CustomMessageType.text,
    this.extraData,
    MessageType? messageType,
    Reaction? reaction,
  }) : messageType = messageType ?? _getMessageType(customType),
       reaction = reaction ?? Reaction(reactions: [], reactedUserIds: []);
  // Factory method to create from Firestore data
  factory CustomMessage.fromFirestore(
    Map<String, dynamic> data,
    ChatUser sender,
  ) {
    final customType = _parseCustomMessageType(data['customType'] ?? 'text');

    return CustomMessage(
      id: data['id'] ?? data['timestamp']?.toString() ?? '',
      message: data['message'] ?? '',
      sender: sender,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0),
      customType: customType,
      extraData: data['extraData'] as Map<String, dynamic>?,
      messageType: _getMessageType(customType),
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'message': message,
      'senderId': sender.id,
      'senderEmail': extraData?['senderEmail'] ?? '',
      'timestamp': createdAt.millisecondsSinceEpoch,
      'customType': customType.toString().split('.').last,
      'extraData': extraData,
      'type': _getFirestoreMessageType(),
    };
  }

  // Convert to chatview Message
  Message toChatViewMessage() {
    return Message(
      id: id,
      message: message,
      createdAt: createdAt,
      sentBy: sender.id,
      messageType: messageType,
      reaction: reaction,
    );
  }

  static CustomMessageType _parseCustomMessageType(String type) {
    switch (type) {
      case 'text':
        return CustomMessageType.text;
      case 'image':
        return CustomMessageType.image;
      case 'location':
        return CustomMessageType.location;
      case 'contact':
        return CustomMessageType.contact;
      case 'voice':
        return CustomMessageType.voice;
      case 'document':
        return CustomMessageType.document;
      default:
        return CustomMessageType.text;
    }
  }

  static MessageType _getMessageType(CustomMessageType customType) {
    switch (customType) {
      case CustomMessageType.image:
        return MessageType.image;
      case CustomMessageType.voice:
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }

  String _getFirestoreMessageType() {
    switch (customType) {
      case CustomMessageType.image:
        return 'image';
      case CustomMessageType.voice:
        return 'voice';
      case CustomMessageType.document:
        return 'document';
      default:
        return 'text';
    }
  }
}
