import 'package:flutter/material.dart';
import 'package:chatapp/model/file_attachment.dart';

class FileProgressIndicator extends StatelessWidget {
  final double progress;
  final FileStatus status;
  final String fileName;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const FileProgressIndicator({
    Key? key,
    required this.progress,
    required this.status,
    required this.fileName,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(),
              ],
            ),
            if (status == FileStatus.uploading ||
                status == FileStatus.processing) ...[
              const SizedBox(height: 8),
              _buildProgressBar(),
            ],
            if (status == FileStatus.failed && errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (status) {
      case FileStatus.uploading:
      case FileStatus.processing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case FileStatus.uploaded:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case FileStatus.failed:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        );
      case FileStatus.deleted:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
          child: const Icon(Icons.delete, color: Colors.white, size: 16),
        );
    }
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    switch (status) {
      case FileStatus.uploading:
      case FileStatus.processing:
        if (onCancel != null) {
          return IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
            tooltip: 'Cancel',
          );
        }
        break;
      case FileStatus.failed:
        if (onRetry != null) {
          return IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRetry,
            tooltip: 'Retry',
          );
        }
        break;
      case FileStatus.uploaded:
        return Icon(Icons.done, color: Colors.green, size: 20);
      case FileStatus.deleted:
        return Icon(Icons.delete, color: Colors.grey, size: 20);
    }
    return const SizedBox.shrink();
  }

  String _getStatusText() {
    switch (status) {
      case FileStatus.uploading:
        return 'Uploading...';
      case FileStatus.processing:
        return 'Processing...';
      case FileStatus.uploaded:
        return 'Upload complete';
      case FileStatus.failed:
        return 'Upload failed';
      case FileStatus.deleted:
        return 'Deleted';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case FileStatus.uploading:
      case FileStatus.processing:
        return Colors.blue;
      case FileStatus.uploaded:
        return Colors.green;
      case FileStatus.failed:
        return Colors.red;
      case FileStatus.deleted:
        return Colors.grey;
    }
  }
}

// Compact progress indicator for inline use
class CompactProgressIndicator extends StatelessWidget {
  final double progress;
  final FileStatus status;
  final double size;

  const CompactProgressIndicator({
    Key? key,
    required this.progress,
    required this.status,
    this.size = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case FileStatus.uploading:
      case FileStatus.processing:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case FileStatus.uploaded:
        return Icon(Icons.check_circle, color: Colors.green, size: size);
      case FileStatus.failed:
        return Icon(Icons.error, color: Colors.red, size: size);
      case FileStatus.deleted:
        return Icon(Icons.delete, color: Colors.grey, size: size);
    }
  }
}

// Progress overlay for full-screen operations
class ProgressOverlay extends StatelessWidget {
  final String message;
  final double? progress;
  final bool canCancel;
  final VoidCallback? onCancel;

  const ProgressOverlay({
    Key? key,
    required this.message,
    this.progress,
    this.canCancel = false,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress != null) ...[
                  CircularProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text(
                    '${(progress! * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                ],
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (canCancel && onCancel != null) ...[
                  const SizedBox(height: 16),
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Multiple file upload progress
class MultiFileProgressIndicator extends StatelessWidget {
  final List<FileProgressData> files;
  final VoidCallback? onCancelAll;

  const MultiFileProgressIndicator({
    Key? key,
    required this.files,
    this.onCancelAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int completedFiles = files
        .where((f) => f.status == FileStatus.uploaded)
        .length;
    int failedFiles = files.where((f) => f.status == FileStatus.failed).length;
    double overallProgress = files.isEmpty
        ? 0.0
        : files.map((f) => f.progress).reduce((a, b) => a + b) / files.length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Uploading ${files.length} files',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (onCancelAll != null)
                  TextButton(
                    onPressed: onCancelAll,
                    child: const Text('Cancel All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              '$completedFiles of ${files.length} completed'
              '${failedFiles > 0 ? ' • $failedFiles failed' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FileProgressIndicator(
                  progress: file.progress,
                  status: file.status,
                  fileName: file.fileName,
                  errorMessage: file.errorMessage,
                  onCancel: file.onCancel,
                  onRetry: file.onRetry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data class for file progress
class FileProgressData {
  final String fileName;
  final double progress;
  final FileStatus status;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  FileProgressData({
    required this.fileName,
    required this.progress,
    required this.status,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
  });
}
