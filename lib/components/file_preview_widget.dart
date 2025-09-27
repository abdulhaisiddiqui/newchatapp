import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/components/file_icon_widget.dart';
import 'package:chatapp/components/thumbnail_generator.dart';
import 'package:chatapp/services/file/file_service.dart';

class FilePreviewWidget extends StatefulWidget {
  final FileAttachment fileAttachment;
  final bool showDownloadButton;
  final bool showFileName;
  final bool showFileSize;
  final VoidCallback? onDownload;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const FilePreviewWidget({
    Key? key,
    required this.fileAttachment,
    this.showDownloadButton = true,
    this.showFileName = true,
    this.showFileSize = true,
    this.onDownload,
    this.onTap,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<FilePreviewWidget> createState() => _FilePreviewWidgetState();
}

class _FilePreviewWidgetState extends State<FilePreviewWidget> {
  String? _thumbnailPath;
  bool _isLoadingThumbnail = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? _handleTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade50,
        ),
        child: _buildPreviewContent(),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (widget.fileAttachment.isImage) {
      return _buildImagePreview();
    } else if (widget.fileAttachment.isVideo) {
      return _buildVideoPreview();
    } else if (widget.fileAttachment.isDocument) {
      return _buildDocumentPreview();
    } else if (widget.fileAttachment.isAudio) {
      return _buildAudioPreview();
    } else {
      return _buildGenericPreview();
    }
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: _thumbnailPath != null
              ? Image.file(
                  File(_thumbnailPath!),
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackIcon();
                  },
                )
              : _isLoadingThumbnail
              ? _buildLoadingIndicator()
              : _buildFallbackIcon(),
        ),
        if (widget.showDownloadButton) _buildDownloadButton(),
        if (widget.showFileName || widget.showFileSize) _buildInfoOverlay(),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: _thumbnailPath != null
              ? Stack(
                  children: [
                    Image.file(
                      File(_thumbnailPath!),
                      width: widget.width,
                      height: widget.height,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackIcon();
                      },
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                )
              : _isLoadingThumbnail
              ? _buildLoadingIndicator()
              : _buildFallbackIcon(),
        ),
        if (widget.showDownloadButton) _buildDownloadButton(),
        if (widget.showFileName || widget.showFileSize) _buildInfoOverlay(),
      ],
    );
  }

  Widget _buildDocumentPreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FileIconWidget(
            fileName: widget.fileAttachment.originalFileName,
            mimeType: widget.fileAttachment.mimeType,
            size: 64,
          ),
          if (widget.showFileName) ...[
            const SizedBox(height: 12),
            Text(
              widget.fileAttachment.originalFileName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.showFileSize) ...[
            const SizedBox(height: 4),
            Text(
              widget.fileAttachment.formattedFileSize,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (widget.showDownloadButton) ...[
            const SizedBox(height: 12),
            _buildDownloadButtonInline(),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note, size: 48, color: Colors.orange),
          ),
          if (widget.showFileName) ...[
            const SizedBox(height: 12),
            Text(
              widget.fileAttachment.originalFileName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.showFileSize) ...[
            const SizedBox(height: 4),
            Text(
              widget.fileAttachment.formattedFileSize,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (widget.showDownloadButton) ...[
            const SizedBox(height: 12),
            _buildDownloadButtonInline(),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericPreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FileIconWidget(
            fileName: widget.fileAttachment.originalFileName,
            mimeType: widget.fileAttachment.mimeType,
            size: 64,
          ),
          if (widget.showFileName) ...[
            const SizedBox(height: 12),
            Text(
              widget.fileAttachment.originalFileName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.showFileSize) ...[
            const SizedBox(height: 4),
            Text(
              widget.fileAttachment.formattedFileSize,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (widget.showDownloadButton) ...[
            const SizedBox(height: 12),
            _buildDownloadButtonInline(),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Center(
        child: FileIconWidget(
          fileName: widget.fileAttachment.originalFileName,
          mimeType: widget.fileAttachment.mimeType,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDownloadButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          icon: _isDownloading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: _downloadProgress,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Icon(Icons.download, color: Colors.white, size: 20),
          onPressed: _isDownloading ? null : _handleDownload,
        ),
      ),
    );
  }

  Widget _buildDownloadButtonInline() {
    return ElevatedButton.icon(
      onPressed: _isDownloading ? null : _handleDownload,
      icon: _isDownloading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.download, size: 16),
      label: Text(_isDownloading ? 'Downloading...' : 'Download'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showFileName)
              Text(
                widget.fileAttachment.originalFileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (widget.showFileSize)
              Text(
                widget.fileAttachment.formattedFileSize,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadThumbnail() async {
    if (!widget.fileAttachment.isImage && !widget.fileAttachment.isVideo) {
      return;
    }

    setState(() => _isLoadingThumbnail = true);

    try {
      final thumbnailGenerator = ThumbnailGenerator();

      // Check if thumbnail already exists
      String? cachedThumbnail = await thumbnailGenerator.getCachedThumbnail(
        widget.fileAttachment.fileName,
      );

      if (cachedThumbnail != null) {
        setState(() {
          _thumbnailPath = cachedThumbnail;
          _isLoadingThumbnail = false;
        });
        return;
      }

      // Generate thumbnail if file is available locally
      // This would typically be done during upload process
      // For now, we'll use the thumbnail URL if available
      if (widget.fileAttachment.thumbnailUrl != null) {
        // In a real implementation, you might download and cache the thumbnail
        setState(() => _isLoadingThumbnail = false);
      }
    } catch (e) {
      setState(() => _isLoadingThumbnail = false);
    }
  }

  void _handleTap() {
    // Open full-screen preview or download file
    _showFullScreenPreview();
  }

  void _handleDownload() {
    if (widget.onDownload != null) {
      widget.onDownload!();
    } else {
      _downloadFile();
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final fileService = FileService();
      final result = await fileService.downloadFile(
        downloadUrl: widget.fileAttachment.downloadUrl,
        fileName: widget.fileAttachment.fileName,
        onProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded ${widget.fileAttachment.originalFileName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  void _showFullScreenPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            FullScreenFilePreview(fileAttachment: widget.fileAttachment),
      ),
    );
  }
}

// Full-screen file preview
class FullScreenFilePreview extends StatelessWidget {
  final FileAttachment fileAttachment;

  const FullScreenFilePreview({Key? key, required this.fileAttachment})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileAttachment.originalFileName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context),
          ),
        ],
      ),
      body: Center(
        child: fileAttachment.isImage
            ? _buildFullScreenImage()
            : LargeFileIcon(
                fileName: fileAttachment.originalFileName,
                mimeType: fileAttachment.mimeType,
                size: 120,
              ),
      ),
    );
  }

  Widget _buildFullScreenImage() {
    if (fileAttachment.thumbnailUrl != null) {
      // In a real implementation, you would load the full-resolution image
      return InteractiveViewer(
        child: Image.network(
          fileAttachment.downloadUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return LargeFileIcon(
              fileName: fileAttachment.originalFileName,
              mimeType: fileAttachment.mimeType,
            );
          },
        ),
      );
    }

    return LargeFileIcon(
      fileName: fileAttachment.originalFileName,
      mimeType: fileAttachment.mimeType,
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      final fileService = FileService();
      final result = await fileService.downloadFile(
        downloadUrl: fileAttachment.downloadUrl,
        fileName: fileAttachment.fileName,
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${fileAttachment.originalFileName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
