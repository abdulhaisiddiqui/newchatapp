enum MessageType {
  text,
  image,
  audio,
  video,
  document,
  contact,
  other,
  location;


  String get name => toString().split('.').last;

  String get displayName {
    switch (this) {
      case text:
        return 'Text';
      case image:
        return 'Image';
      case audio:
        return 'Audio';
      case video:
        return 'Video';
      case document:
        return 'Document';
      case contact:
        return 'Contact';
      case other:
        return 'other';
      case location:
        return 'Location';
    }
  }

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }

  static MessageType fromMimeType(String? mimeType) {
    if (mimeType == null) return MessageType.text;
    if (mimeType.startsWith('image/')) return MessageType.image;
    if (mimeType.startsWith('audio/')) return MessageType.audio;
    if (mimeType.startsWith('video/')) return MessageType.video;
    if (mimeType.contains('pdf') || mimeType.contains('document')) return MessageType.document;
    return MessageType.text;
  }
}