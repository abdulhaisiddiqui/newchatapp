import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileCompressionService {
  static final FileCompressionService _instance =
      FileCompressionService._internal();
  factory FileCompressionService() => _instance;
  FileCompressionService._internal();

  // Compression settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 85;
  static const int thumbnailSize = 300;
  static const int thumbnailQuality = 70;

  /// Compress a file based on its type
  Future<FileCompressionResult> compressFile({
    required File file,
    String? mimeType,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0);

      if (mimeType == null) {
        mimeType = _getMimeTypeFromExtension(file.path);
      }

      onProgress?.call(0.2);

      if (mimeType.startsWith('image/')) {
        return await _compressImage(file, onProgress);
      } else if (mimeType.startsWith('video/')) {
        return await _compressVideo(file, onProgress);
      } else {
        // For other file types, return original file
        onProgress?.call(1.0);
        return FileCompressionResult.success(
          compressedFile: file,
          originalSize: await file.length(),
          compressedSize: await file.length(),
          compressionRatio: 1.0,
        );
      }
    } catch (e) {
      return FileCompressionResult.error('Compression failed: ${e.toString()}');
    }
  }

  /// Compress an image file
  Future<FileCompressionResult> _compressImage(
    File imageFile,
    Function(double)? onProgress,
  ) async {
    try {
      onProgress?.call(0.3);

      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();
      int originalSize = imageBytes.length;

      onProgress?.call(0.4);

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      onProgress?.call(0.5);

      // Resize if too large
      bool wasResized = false;
      if (image.width > maxImageWidth || image.height > maxImageHeight) {
        image = img.copyResize(
          image,
          width: image.width > maxImageWidth ? maxImageWidth : null,
          height: image.height > maxImageHeight ? maxImageHeight : null,
          maintainAspect: true,
        );
        wasResized = true;
      }

      onProgress?.call(0.7);

      // Compress image
      List<int> compressedBytes;
      String extension = path.extension(imageFile.path).toLowerCase();

      if (extension == '.png' && !wasResized) {
        // For PNG, only compress if resized, otherwise keep original
        compressedBytes = imageBytes;
      } else {
        // Convert to JPEG for better compression
        compressedBytes = img.encodeJpg(image, quality: imageQuality);
      }

      onProgress?.call(0.9);

      // Save compressed image
      String compressedPath = await _getCompressedFilePath(
        imageFile.path,
        extension == '.png' && compressedBytes != imageBytes ? '.jpg' : null,
      );

      File compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      onProgress?.call(1.0);

      int compressedSize = compressedBytes.length;
      double compressionRatio = compressedSize / originalSize;

      return FileCompressionResult.success(
        compressedFile: compressedFile,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        wasResized: wasResized,
      );
    } catch (e) {
      return FileCompressionResult.error(
        'Image compression failed: ${e.toString()}',
      );
    }
  }

  /// Compress a video file (placeholder - would need video_compress package)
  Future<FileCompressionResult> _compressVideo(
    File videoFile,
    Function(double)? onProgress,
  ) async {
    try {
      // For now, return original file as video compression requires additional setup
      // In a real implementation, you would use video_compress package

      onProgress?.call(0.5);

      int originalSize = await videoFile.length();

      // Placeholder for video compression
      // final info = await VideoCompress.compressVideo(
      //   videoFile.path,
      //   quality: VideoQuality.MediumQuality,
      //   deleteOrigin: false,
      // );

      onProgress?.call(1.0);

      return FileCompressionResult.success(
        compressedFile: videoFile,
        originalSize: originalSize,
        compressedSize: originalSize,
        compressionRatio: 1.0,
        message: 'Video compression not implemented yet',
      );
    } catch (e) {
      return FileCompressionResult.error(
        'Video compression failed: ${e.toString()}',
      );
    }
  }

  /// Generate thumbnail for any file type
  Future<ThumbnailResult> generateThumbnail({
    required File file,
    String? mimeType,
    int size = thumbnailSize,
  }) async {
    try {
      if (mimeType == null) {
        mimeType = _getMimeTypeFromExtension(file.path);
      }

      if (mimeType.startsWith('image/')) {
        return await _generateImageThumbnail(file, size);
      } else if (mimeType.startsWith('video/')) {
        return await _generateVideoThumbnail(file, size);
      } else {
        return ThumbnailResult.notSupported(
          'Thumbnail not supported for this file type',
        );
      }
    } catch (e) {
      return ThumbnailResult.error(
        'Thumbnail generation failed: ${e.toString()}',
      );
    }
  }

  /// Generate thumbnail for image
  Future<ThumbnailResult> _generateImageThumbnail(
    File imageFile,
    int size,
  ) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Create thumbnail
      img.Image thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        maintainAspect: true,
      );

      // Encode as JPEG
      List<int> thumbnailBytes = img.encodeJpg(
        thumbnail,
        quality: thumbnailQuality,
      );

      // Save thumbnail
      String thumbnailPath = await _getThumbnailPath(imageFile.path);
      File thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return ThumbnailResult.success(
        thumbnailFile: thumbnailFile,
        thumbnailSize: thumbnailBytes.length,
      );
    } catch (e) {
      return ThumbnailResult.error(
        'Image thumbnail generation failed: ${e.toString()}',
      );
    }
  }

  /// Generate thumbnail for video (placeholder)
  Future<ThumbnailResult> _generateVideoThumbnail(
    File videoFile,
    int size,
  ) async {
    try {
      // Placeholder for video thumbnail generation
      // In a real implementation, you would use video_thumbnail package

      return ThumbnailResult.notSupported(
        'Video thumbnail generation not implemented yet',
      );
    } catch (e) {
      return ThumbnailResult.error(
        'Video thumbnail generation failed: ${e.toString()}',
      );
    }
  }

  /// Batch compress multiple files
  Future<BatchCompressionResult> compressFiles({
    required List<File> files,
    Function(int, int, double)? onProgress, // (current, total, fileProgress)
  }) async {
    List<FileCompressionResult> results = [];
    int totalOriginalSize = 0;
    int totalCompressedSize = 0;
    int successCount = 0;
    int errorCount = 0;

    for (int i = 0; i < files.length; i++) {
      File file = files[i];

      try {
        FileCompressionResult result = await compressFile(
          file: file,
          onProgress: (progress) {
            onProgress?.call(i, files.length, progress);
          },
        );

        results.add(result);

        if (result.isSuccess) {
          successCount++;
          totalOriginalSize += result.originalSize!;
          totalCompressedSize += result.compressedSize!;
        } else {
          errorCount++;
        }
      } catch (e) {
        results.add(
          FileCompressionResult.error('Failed to compress ${file.path}: $e'),
        );
        errorCount++;
      }
    }

    double overallCompressionRatio = totalOriginalSize > 0
        ? totalCompressedSize / totalOriginalSize
        : 1.0;

    return BatchCompressionResult(
      results: results,
      successCount: successCount,
      errorCount: errorCount,
      totalOriginalSize: totalOriginalSize,
      totalCompressedSize: totalCompressedSize,
      overallCompressionRatio: overallCompressionRatio,
    );
  }

  /// Get compressed file path
  Future<String> _getCompressedFilePath(
    String originalPath, [
    String? newExtension,
  ]) async {
    Directory tempDir = await getTemporaryDirectory();
    String fileName = path.basenameWithoutExtension(originalPath);
    String extension = newExtension ?? path.extension(originalPath);

    return '${tempDir.path}/compressed_${fileName}_${DateTime.now().millisecondsSinceEpoch}$extension';
  }

  /// Get thumbnail file path
  Future<String> _getThumbnailPath(String originalPath) async {
    Directory tempDir = await getTemporaryDirectory();
    String fileName = path.basenameWithoutExtension(originalPath);

    return '${tempDir.path}/thumb_${fileName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  /// Get MIME type from file extension
  String _getMimeTypeFromExtension(String filePath) {
    String extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  /// Clean up temporary compressed files
  Future<void> cleanupTempFiles() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      List<FileSystemEntity> files = await tempDir.list().toList();

      for (FileSystemEntity entity in files) {
        if (entity is File) {
          String fileName = path.basename(entity.path);
          if (fileName.startsWith('compressed_') ||
              fileName.startsWith('thumb_')) {
            // Delete files older than 1 hour
            DateTime lastModified = await entity.lastModified();
            if (DateTime.now().difference(lastModified).inHours > 1) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup temp files: $e');
    }
  }
}

// Result classes
class FileCompressionResult {
  final bool isSuccess;
  final File? compressedFile;
  final int? originalSize;
  final int? compressedSize;
  final double? compressionRatio;
  final bool wasResized;
  final String? error;
  final String? message;

  FileCompressionResult._({
    required this.isSuccess,
    this.compressedFile,
    this.originalSize,
    this.compressedSize,
    this.compressionRatio,
    this.wasResized = false,
    this.error,
    this.message,
  });

  factory FileCompressionResult.success({
    required File compressedFile,
    required int originalSize,
    required int compressedSize,
    required double compressionRatio,
    bool wasResized = false,
    String? message,
  }) {
    return FileCompressionResult._(
      isSuccess: true,
      compressedFile: compressedFile,
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionRatio: compressionRatio,
      wasResized: wasResized,
      message: message,
    );
  }

  factory FileCompressionResult.error(String error) {
    return FileCompressionResult._(isSuccess: false, error: error);
  }

  String get compressionInfo {
    if (!isSuccess || originalSize == null || compressedSize == null) {
      return 'No compression info available';
    }

    int savedBytes = originalSize! - compressedSize!;
    double savedPercentage = (savedBytes / originalSize!) * 100;

    return 'Saved ${_formatBytes(savedBytes)} (${savedPercentage.toStringAsFixed(1)}%)';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

class ThumbnailResult {
  final bool isSuccess;
  final File? thumbnailFile;
  final int? thumbnailSize;
  final String? error;
  final String? message;

  ThumbnailResult._({
    required this.isSuccess,
    this.thumbnailFile,
    this.thumbnailSize,
    this.error,
    this.message,
  });

  factory ThumbnailResult.success({
    required File thumbnailFile,
    required int thumbnailSize,
  }) {
    return ThumbnailResult._(
      isSuccess: true,
      thumbnailFile: thumbnailFile,
      thumbnailSize: thumbnailSize,
    );
  }

  factory ThumbnailResult.error(String error) {
    return ThumbnailResult._(isSuccess: false, error: error);
  }

  factory ThumbnailResult.notSupported(String message) {
    return ThumbnailResult._(isSuccess: false, message: message);
  }
}

class BatchCompressionResult {
  final List<FileCompressionResult> results;
  final int successCount;
  final int errorCount;
  final int totalOriginalSize;
  final int totalCompressedSize;
  final double overallCompressionRatio;

  BatchCompressionResult({
    required this.results,
    required this.successCount,
    required this.errorCount,
    required this.totalOriginalSize,
    required this.totalCompressedSize,
    required this.overallCompressionRatio,
  });

  int get totalFiles => results.length;

  String get summary {
    int savedBytes = totalOriginalSize - totalCompressedSize;
    double savedPercentage = totalOriginalSize > 0
        ? (savedBytes / totalOriginalSize) * 100
        : 0.0;

    return '$successCount/$totalFiles files compressed successfully. '
        'Saved ${_formatBytes(savedBytes)} (${savedPercentage.toStringAsFixed(1)}%)';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
