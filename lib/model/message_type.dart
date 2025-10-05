enum MessageType {
  text,
  image,
  video,
  document,
  audio,
  location,
  contact,
  other;

  String get displayName {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.document:
        return 'Document';
      case MessageType.audio:
        return 'Audio';
      case MessageType.location:
        return 'Location';
      case MessageType.contact:
        return 'Contact';
      case MessageType.other:
        return 'File';
    }
  }

  static MessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'document':
        return MessageType.document;
      case 'audio':
        return MessageType.audio;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      default:
        return MessageType.other;
    }
  }

  static MessageType fromMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return MessageType.image;
    } else if (mimeType.startsWith('video/')) {
      return MessageType.video;
    } else if (mimeType.startsWith('audio/')) {
      return MessageType.audio;
    } else if (mimeType.contains('pdf') ||
        mimeType.contains('document') ||
        mimeType.contains('text') ||
        mimeType.contains('word') ||
        mimeType.contains('excel') ||
        mimeType.contains('powerpoint')) {
      return MessageType.document;
    } else {
      return MessageType.other;
    }
  }
}
