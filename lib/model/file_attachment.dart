import 'package:cloud_firestore/cloud_firestore.dart';

enum FileStatus {
  uploading,
  uploaded,
  failed,
  deleted,
  processing;

  String get displayName {
    switch (this) {
      case FileStatus.uploading:
        return 'Uploading';
      case FileStatus.uploaded:
        return 'Uploaded';
      case FileStatus.failed:
        return 'Failed';
      case FileStatus.deleted:
        return 'Deleted';
      case FileStatus.processing:
        return 'Processing';
    }
  }

  static FileStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'uploading':
        return FileStatus.uploading;
      case 'uploaded':
        return FileStatus.uploaded;
      case 'failed':
        return FileStatus.failed;
      case 'deleted':
        return FileStatus.deleted;
      case 'processing':
        return FileStatus.processing;
      default:
        return FileStatus.failed;
    }
  }
}

class FileAttachment {
  final String fileId;
  final String fileName;
  final String originalFileName;
  final String fileExtension;
  final int fileSizeBytes;
  final String mimeType;
  final String downloadUrl;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;
  final Timestamp uploadedAt;
  final String uploadedBy;
  final bool isCompressed;
  final String? compressionRatio;
  final FileStatus status;

  FileAttachment({
    required this.fileId,
    required this.fileName,
    required this.originalFileName,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.downloadUrl,
    this.thumbnailUrl,
    this.metadata,
    required this.uploadedAt,
    required this.uploadedBy,
    this.isCompressed = false,
    this.compressionRatio,
    this.status = FileStatus.uploaded,
  });

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'originalFileName': originalFileName,
      'fileExtension': fileExtension,
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
      'uploadedAt': uploadedAt,
      'uploadedBy': uploadedBy,
      'isCompressed': isCompressed,
      'compressionRatio': compressionRatio,
      'status': status.name,
    };
  }

  // Create from Firestore map
  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    // Handle timestamp conversion safely
    Timestamp uploadedAt;
    final timestampValue = map['uploadedAt'];
    if (timestampValue is Timestamp) {
      uploadedAt = timestampValue;
    } else if (timestampValue is int) {
      uploadedAt = Timestamp.fromMillisecondsSinceEpoch(timestampValue);
    } else {
      uploadedAt = Timestamp.now();
    }

    // Handle metadata safely
    Map<String, dynamic>? metadata;
    if (map['metadata'] is Map<String, dynamic>) {
      metadata = map['metadata'] as Map<String, dynamic>;
    }

    return FileAttachment(
      fileId: map['fileId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      originalFileName: map['originalFileName'] as String? ?? '',
      fileExtension: map['fileExtension'] as String? ?? '',
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      mimeType: map['mimeType'] as String? ?? '',
      downloadUrl: map['downloadUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      metadata: metadata,
      uploadedAt: uploadedAt,
      uploadedBy: map['uploadedBy'] as String? ?? '',
      isCompressed: map['isCompressed'] as bool? ?? false,
      compressionRatio: map['compressionRatio'] as String?,
      status: FileStatus.fromString(map['status'] as String? ?? 'uploaded'),
    );
  }

  // Helper methods
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  bool get isImage => mimeType.isNotEmpty && mimeType.startsWith('image/');
  bool get isVideo => mimeType.isNotEmpty && mimeType.startsWith('video/');
  bool get isAudio => mimeType.isNotEmpty && mimeType.startsWith('audio/');
  bool get isDocument =>
      mimeType.isNotEmpty &&
      (mimeType.contains('pdf') ||
          mimeType.contains('document') ||
          mimeType.contains('text') ||
          mimeType.contains('word') ||
          mimeType.contains('excel') ||
          mimeType.contains('powerpoint'));

  // Copy with method for updates
  FileAttachment copyWith({
    String? fileId,
    String? fileName,
    String? originalFileName,
    String? fileExtension,
    int? fileSizeBytes,
    String? mimeType,
    String? downloadUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    Timestamp? uploadedAt,
    String? uploadedBy,
    bool? isCompressed,
    String? compressionRatio,
    FileStatus? status,
  }) {
    return FileAttachment(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      originalFileName: originalFileName ?? this.originalFileName,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      isCompressed: isCompressed ?? this.isCompressed,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'FileAttachment(fileId: $fileId, fileName: $fileName, size: $formattedFileSize, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileAttachment && other.fileId == fileId;
  }

  @override
  int get hashCode => fileId.hashCode;
}
