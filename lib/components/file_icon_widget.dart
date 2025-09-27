import 'package:flutter/material.dart';
import 'package:chatapp/services/file/file_security_service.dart';

class FileIconWidget extends StatelessWidget {
  final String fileName;
  final String? mimeType;
  final double size;
  final Color? color;

  const FileIconWidget({
    Key? key,
    required this.fileName,
    this.mimeType,
    this.size = 32,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String extension = fileName.split('.').last.toLowerCase();
    String category = FileSecurityService.getFileCategory('.$extension');

    return _buildIcon(category, extension);
  }

  Widget _buildIcon(String category, String extension) {
    IconData iconData;
    Color iconColor = color ?? _getDefaultColor(category);

    switch (category) {
      case 'image':
        iconData = _getImageIcon(extension);
        break;
      case 'video':
        iconData = _getVideoIcon(extension);
        break;
      case 'audio':
        iconData = _getAudioIcon(extension);
        break;
      case 'document':
        iconData = _getDocumentIcon(extension);
        break;
      case 'archive':
        iconData = Icons.archive;
        break;
      default:
        iconData = Icons.insert_drive_file;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: size * 0.6, color: iconColor),
    );
  }

  IconData _getImageIcon(String extension) {
    switch (extension) {
      case 'svg':
        return Icons.image_outlined;
      case 'gif':
        return Icons.gif;
      default:
        return Icons.image;
    }
  }

  IconData _getVideoIcon(String extension) {
    switch (extension) {
      case 'mp4':
        return Icons.video_file;
      case 'mov':
        return Icons.movie;
      default:
        return Icons.videocam;
    }
  }

  IconData _getAudioIcon(String extension) {
    switch (extension) {
      case 'mp3':
        return Icons.music_note;
      case 'wav':
        return Icons.audiotrack;
      default:
        return Icons.audio_file;
    }
  }

  IconData _getDocumentIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.description;
    }
  }

  Color _getDefaultColor(String category) {
    switch (category) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.orange;
      case 'document':
        return Colors.green;
      case 'archive':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Specialized file type icons
class FileTypeIcon extends StatelessWidget {
  final String fileExtension;
  final double size;
  final bool showBackground;

  const FileTypeIcon({
    Key? key,
    required this.fileExtension,
    this.size = 24,
    this.showBackground = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String ext = fileExtension.toLowerCase().replaceAll('.', '');

    return Container(
      width: size,
      height: size,
      decoration: showBackground
          ? BoxDecoration(
              color: _getBackgroundColor(ext),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Center(
        child: Text(
          ext.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
            color: showBackground ? Colors.white : _getBackgroundColor(ext),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(String extension) {
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Colors.pink;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.red.shade700;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

// Large file preview icon for full-screen previews
class LargeFileIcon extends StatelessWidget {
  final String fileName;
  final String? mimeType;
  final double size;

  const LargeFileIcon({
    Key? key,
    required this.fileName,
    this.mimeType,
    this.size = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String extension = fileName.split('.').last.toLowerCase();
    String category = FileSecurityService.getFileCategory('.$extension');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FileIconWidget(fileName: fileName, mimeType: mimeType, size: size),
        const SizedBox(height: 16),
        Text(
          fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          '${category.toUpperCase()} FILE',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
