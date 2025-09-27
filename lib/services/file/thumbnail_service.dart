import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chatapp/services/file/file_compression_service.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FileCompressionService _compressionService = FileCompressionService();

  // Thumbnail settings
  static const int defaultThumbnailSize = 300;
  static const int smallThumbnailSize = 150;
  static const int largeThumbnailSize = 500;
  static const int thumbnailQuality = 75;

  /// Generate and upload thumbnail for a file
  Future<ThumbnailUploadResult> generateAndUploadThumbnail({
    required File file,
    required String fileName,
    required String chatRoomId,
    String? mimeType,
    int size = defaultThumbnailSize,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0);

      // Generate thumbnail locally
      ThumbnailResult thumbnailResult = await _compressionService
          .generateThumbnail(file: file, mimeType: mimeType, size: size);

      onProgress?.call(0.5);

      if (!thumbnailResult.isSuccess) {
        return ThumbnailUploadResult.error(
          thumbnailResult.error ?? 'Failed to generate thumbnail',
        );
      }

      // Upload thumbnail to Firebase Storage
      String thumbnailPath = 'thumbnails/$chatRoomId/thumb_$fileName.jpg';
      UploadTask uploadTask = _storage
          .ref(thumbnailPath)
          .putFile(thumbnailResult.thumbnailFile!);

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          double uploadProgress =
              0.5 + (snapshot.bytesTransferred / snapshot.totalBytes) * 0.5;
          onProgress?.call(uploadProgress);
        }
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      onProgress?.call(1.0);

      // Clean up local thumbnail file
      await thumbnailResult.thumbnailFile!.delete();

      return ThumbnailUploadResult.success(
        thumbnailUrl: downloadUrl,
        thumbnailSize: thumbnailResult.thumbnailSize!,
      );
    } catch (e) {
      return ThumbnailUploadResult.error(
        'Thumbnail upload failed: ${e.toString()}',
      );
    }
  }

  /// Generate thumbnail for image file
  Future<ThumbnailResult> generateImageThumbnail({
    required File imageFile,
    int size = defaultThumbnailSize,
    int quality = thumbnailQuality,
  }) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Create thumbnail maintaining aspect ratio
      img.Image thumbnail;
      if (image.width > image.height) {
        // Landscape
        thumbnail = img.copyResize(image, width: size);
      } else {
        // Portrait or square
        thumbnail = img.copyResize(image, height: size);
      }

      // Encode as JPEG
      List<int> thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);

      // Save to temporary file
      String thumbnailPath = await _getTempThumbnailPath(imageFile.path);
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

  /// Generate thumbnail for video file
  Future<ThumbnailResult> generateVideoThumbnail({
    required File videoFile,
    int size = defaultThumbnailSize,
    int quality = thumbnailQuality,
  }) async {
    try {
      // Generate video thumbnail
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: size,
        maxHeight: size,
        quality: quality,
      );

      if (thumbnailPath == null) {
        throw Exception('Failed to generate video thumbnail');
      }

      File thumbnailFile = File(thumbnailPath);
      int thumbnailSize = await thumbnailFile.length();

      return ThumbnailResult.success(
        thumbnailFile: thumbnailFile,
        thumbnailSize: thumbnailSize,
      );
    } catch (e) {
      return ThumbnailResult.error(
        'Video thumbnail generation failed: ${e.toString()}',
      );
    }
  }

  /// Generate multiple thumbnail sizes
  Future<Map<String, ThumbnailResult>> generateMultipleThumbnails({
    required File file,
    String? mimeType,
    Map<String, int> sizes = const {
      'small': smallThumbnailSize,
      'medium': defaultThumbnailSize,
      'large': largeThumbnailSize,
    },
  }) async {
    Map<String, ThumbnailResult> results = {};

    for (String sizeKey in sizes.keys) {
      int size = sizes[sizeKey]!;

      ThumbnailResult result = await _compressionService.generateThumbnail(
        file: file,
        mimeType: mimeType,
        size: size,
      );

      results[sizeKey] = result;
    }

    return results;
  }

  /// Get temporary thumbnail path
  Future<String> _getTempThumbnailPath(String originalPath) async {
    Directory tempDir = await getTemporaryDirectory();
    String fileName = path.basenameWithoutExtension(originalPath);
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    return '${tempDir.path}/thumb_${fileName}_$timestamp.jpg';
  }

  /// Download and cache thumbnail from URL
  Future<File?> downloadThumbnail({
    required String thumbnailUrl,
    required String fileName,
  }) async {
    try {
      // Check if already cached
      File? cachedThumbnail = await _getCachedThumbnail(fileName);
      if (cachedThumbnail != null) {
        return cachedThumbnail;
      }

      // Download thumbnail
      Reference ref = _storage.refFromURL(thumbnailUrl);

      // Create cache path
      String cachePath = await _getThumbnailCachePath(fileName);
      File cacheFile = File(cachePath);

      // Download to cache
      await ref.writeToFile(cacheFile);

      return cacheFile;
    } catch (e) {
      debugPrint('Failed to download thumbnail: $e');
      return null;
    }
  }

  /// Get cached thumbnail file
  Future<File?> _getCachedThumbnail(String fileName) async {
    try {
      String cachePath = await _getThumbnailCachePath(fileName);
      File cacheFile = File(cachePath);

      if (await cacheFile.exists()) {
        // Check if cache is still valid (7 days)
        DateTime lastModified = await cacheFile.lastModified();
        if (DateTime.now().difference(lastModified).inDays < 7) {
          return cacheFile;
        } else {
          await cacheFile.delete();
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get thumbnail cache path
  Future<String> _getThumbnailCachePath(String fileName) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    Directory cacheDir = Directory('${appDir.path}/thumbnail_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return '${cacheDir.path}/thumb_$fileName.jpg';
  }

  /// Clear thumbnail cache
  Future<void> clearThumbnailCache() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/thumbnail_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to clear thumbnail cache: $e');
    }
  }

  /// Get thumbnail cache size
  Future<int> getThumbnailCacheSize() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/thumbnail_cache');

      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      List<FileSystemEntity> files = await cacheDir.list().toList();

      for (FileSystemEntity entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}

// Thumbnail upload result
class ThumbnailUploadResult {
  final bool isSuccess;
  final String? thumbnailUrl;
  final int? thumbnailSize;
  final String? error;

  ThumbnailUploadResult._({
    required this.isSuccess,
    this.thumbnailUrl,
    this.thumbnailSize,
    this.error,
  });

  factory ThumbnailUploadResult.success({
    required String thumbnailUrl,
    required int thumbnailSize,
  }) {
    return ThumbnailUploadResult._(
      isSuccess: true,
      thumbnailUrl: thumbnailUrl,
      thumbnailSize: thumbnailSize,
    );
  }

  factory ThumbnailUploadResult.error(String error) {
    return ThumbnailUploadResult._(isSuccess: false, error: error);
  }
}
