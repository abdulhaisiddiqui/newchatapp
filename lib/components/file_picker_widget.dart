import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chatapp/components/file_selection_dialog.dart';
import 'package:chatapp/services/file/file_security_service.dart';
import 'package:chatapp/components/file_status_monitor.dart';

class FilePickerWidget extends StatefulWidget {
  final Function(List<File>) onFilesSelected;
  final int maxFiles;
  final List<String>? allowedExtensions;
  final String? hintText;
  final bool showPreview;
  final Widget? child;
  final bool isUploading;
  final double uploadProgress;
  final String? statusMessage;

  const FilePickerWidget({
    Key? key,
    required this.onFilesSelected,
    this.maxFiles = 10,
    this.allowedExtensions,
    this.hintText,
    this.showPreview = true,
    this.child,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.statusMessage,
  }) : super(key: key);

  @override
  State<FilePickerWidget> createState() => _FilePickerWidgetState();
}

class _FilePickerWidgetState extends State<FilePickerWidget> {
  bool _isDragOver = false;
  List<File> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDropZone(),
        if (widget.statusMessage != null) ...[          FileStatusMonitor(
            status: widget.statusMessage!,
            progress: widget.uploadProgress,
            isError: widget.statusMessage!.startsWith('Error'),
            onRetry: widget.statusMessage!.startsWith('Error') ? _showFileSelectionDialog : null,
          ),
          const SizedBox(height: 8),
        ] else if (widget.isUploading) ...[          LinearProgressIndicator(value: widget.uploadProgress),
          const SizedBox(height: 8),
        ],
        if (widget.showPreview && _selectedFiles.isNotEmpty) ...[          const SizedBox(height: 16),
          _buildFilePreview(),
        ],
      ],
    );
  }

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: _showFileSelectionDialog,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isDragOver
                ? Theme.of(context).primaryColor
                : Colors.grey.shade400,
            width: _isDragOver ? 2 : 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _isDragOver
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey.shade50,
        ),
        child: widget.child ?? _buildDefaultDropZone(),
      ),
    );
  }

  Widget _buildDefaultDropZone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 48,
            color: _isDragOver
                ? Theme.of(context).primaryColor
                : Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            widget.hintText ?? 'Tap to select files',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _isDragOver
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _buildSupportedFormatsText(),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (widget.maxFiles > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Maximum ${widget.maxFiles} files',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'Selected Files (${_selectedFiles.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFiles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _buildFileItem(_selectedFiles[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(File file, int index) {
    String fileName = file.path.split('/').last;
    String fileExtension = fileName.split('.').last.toLowerCase();
    String fileCategory = FileSecurityService.getFileCategory(
      '.$fileExtension',
    );

    return ListTile(
      leading: _buildFileIcon(fileCategory),
      title: Text(
        fileName,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: FutureBuilder<int>(
        future: file.length(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Text(
              _formatFileSize(snapshot.data!),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            );
          }
          return const Text('...');
        },
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => _removeFile(index),
        tooltip: 'Remove file',
      ),
    );
  }

  Widget _buildFileIcon(String category) {
    IconData iconData;
    Color color;

    switch (category) {
      case 'image':
        iconData = Icons.image;
        color = Colors.blue;
        break;
      case 'video':
        iconData = Icons.video_file;
        color = Colors.red;
        break;
      case 'audio':
        iconData = Icons.audio_file;
        color = Colors.orange;
        break;
      case 'document':
        iconData = Icons.description;
        color = Colors.green;
        break;
      case 'archive':
        iconData = Icons.archive;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(iconData, color: color, size: 32);
  }

  String _buildSupportedFormatsText() {
    if (widget.allowedExtensions != null) {
      return 'Supported: ${widget.allowedExtensions!.join(', ')}';
    }

    return 'Supports images, videos, documents, and more';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _showFileSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => FileSelectionDialog(
        onFilesSelected: _handleFilesSelected,
        maxFiles: widget.maxFiles,
        allowedExtensions: widget.allowedExtensions,
      ),
    );
  }

  void _handleFilesSelected(List<File> files) {
    setState(() {
      if (widget.maxFiles == 1) {
        _selectedFiles = files;
      } else {
        // Add new files, but respect max limit
        _selectedFiles.addAll(files);
        if (_selectedFiles.length > widget.maxFiles) {
          _selectedFiles = _selectedFiles.take(widget.maxFiles).toList();
        }
      }
    });

    widget.onFilesSelected(_selectedFiles);
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });

    widget.onFilesSelected(_selectedFiles);
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
    });

    widget.onFilesSelected(_selectedFiles);
  }
}

// Extension widget for easy integration in chat input
class ChatFilePickerButton extends StatelessWidget {
  final Function(List<File>) onFilesSelected;
  final int maxFiles;
  final List<String>? allowedExtensions;

  const ChatFilePickerButton({
    Key? key,
    required this.onFilesSelected,
    this.maxFiles = 10,
    this.allowedExtensions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.attach_file),
      onPressed: () => _showFileSelectionDialog(context),
      tooltip: 'Attach files',
    );
  }

  void _showFileSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FileSelectionDialog(
        onFilesSelected: onFilesSelected,
        maxFiles: maxFiles,
        allowedExtensions: allowedExtensions,
      ),
    );
  }
}

// Compact file picker for inline use
class CompactFilePicker extends StatelessWidget {
  final Function(List<File>) onFilesSelected;
  final int maxFiles;
  final String? buttonText;
  final IconData? icon;

  const CompactFilePicker({
    Key? key,
    required this.onFilesSelected,
    this.maxFiles = 1,
    this.buttonText,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showFileSelectionDialog(context),
      icon: Icon(icon ?? Icons.attach_file),
      label: Text(buttonText ?? 'Select File${maxFiles > 1 ? 's' : ''}'),
    );
  }

  void _showFileSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FileSelectionDialog(
        onFilesSelected: onFilesSelected,
        maxFiles: maxFiles,
      ),
    );
  }
}
