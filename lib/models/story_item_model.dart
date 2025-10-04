import 'package:cloud_firestore/cloud_firestore.dart';

class StoryItemModel {
  final String url;
  final String type; // "image", "video", "text"
  final String? text;
  final DateTime timestamp;
  final String userId;
  final String username;
  final String? userAvatar;

  StoryItemModel({
    required this.url,
    required this.type,
    this.text,
    required this.timestamp,
    required this.userId,
    required this.username,
    this.userAvatar,
  });

  factory StoryItemModel.fromMap(Map<String, dynamic> data) {
    return StoryItemModel(
      url: data['url'] ?? '',
      type: data['type'] ?? 'text',
      text: data['text'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Unknown',
      userAvatar: data['userAvatar'],
    );
  }

  Map<String, dynamic> toMap() => {
    "url": url,
    "type": type,
    "text": text,
    "timestamp": timestamp,
    "userId": userId,
    "username": username,
    "userAvatar": userAvatar,
  };
}
