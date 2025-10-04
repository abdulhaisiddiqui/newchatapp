import 'package:flutter/material.dart';
import 'package:chatapp/model/message.dart';
import 'package:chatapp/model/message_type.dart';
import 'package:chatapp/components/file_preview_widget.dart';
import 'package:chatapp/components/voice_message_widget.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final VoidCallback? onFileDownload;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onFileDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: _getBorderRadius(),
                color: isCurrentUser
                    ? const Color(0xFF20A090)
                    : Colors.grey.shade200,
              ),
              child: _buildMessageContent(context),
            ),
            const SizedBox(height: 2),
            _buildMessageInfo(context),
          ],
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    if (isCurrentUser) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(4),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      );
    }
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.audio:
        return _buildAudioMessage();
      case MessageType.image:
      case MessageType.video:
      case MessageType.document:
      case MessageType.other:
        return _buildFileMessage(context);
    }
  }

  Widget _buildTextMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        message.message,
        style: TextStyle(
          fontSize: 16,
          color: isCurrentUser ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAudioMessage() {
    if (message.fileAttachment == null ||
        message.fileAttachment!.downloadUrl.isEmpty) {
      return _buildTextMessage(); // Fallback to text if no file attachment or URL
    }

    return VoiceMessageWidget(
      audioUrl: message.fileAttachment!.downloadUrl,
      isCurrentUser: isCurrentUser,
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    if (message.fileAttachment == null) {
      return _buildTextMessage(); // Fallback to text if no file attachment
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File preview
        Container(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 200),
          child: FilePreviewWidget(
            fileAttachment: message.fileAttachment!,
            showDownloadButton: true,
            showFileName: true,
            showFileSize: true,
            onDownload: onFileDownload,
            borderRadius: _getBorderRadius(),
          ),
        ),
        // Text caption if present
        if (message.hasText) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              message.message,
              style: TextStyle(
                fontSize: 14,
                color: isCurrentUser ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildMessageInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimestamp(message.timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (message.isEdited) ...[
            const SizedBox(width: 4),
            Text(
              '• edited',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isCurrentUser) ...[
            const SizedBox(width: 4),
            Icon(Icons.done_all, size: 14, color: Colors.grey.shade600),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      // Today - show time only
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime.year == now.year) {
      // This year - show month and day
      return '${dateTime.day}/${dateTime.month}';
    } else {
      // Different year - show full date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// Specialized chat bubble for different message types
class FileChatBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final VoidCallback? onFileDownload;
  final VoidCallback? onFileTap;

  const FileChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onFileDownload,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.fileAttachment == null) {
      return ChatBubble(
        message: message,
        isCurrentUser: isCurrentUser,
        onFileDownload: onFileDownload,
      );
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onFileTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isCurrentUser ? const Color(0xFF20A090) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File preview
                    FilePreviewWidget(
                      fileAttachment: message.fileAttachment!,
                      showDownloadButton: false,
                      showFileName: false,
                      showFileSize: false,
                      width:
                          message.fileAttachment!.isImage ||
                              message.fileAttachment!.isVideo
                          ? 200
                          : null,
                      height:
                          message.fileAttachment!.isImage ||
                              message.fileAttachment!.isVideo
                          ? 150
                          : null,
                    ),
                    // File info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.fileAttachment!.originalFileName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: isCurrentUser
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.fileAttachment!.formattedFileSize,
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurrentUser
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (message.hasText) ...[
                            const SizedBox(height: 8),
                            Text(
                              message.message,
                              style: TextStyle(
                                fontSize: 14,
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime.year == now.year) {
      return '${dateTime.day}/${dateTime.month}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
