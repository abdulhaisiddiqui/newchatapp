import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ThumbnailGenerator {
  static final ThumbnailGenerator _instance = ThumbnailGenerator._internal();
  factory ThumbnailGenerator() => _instance;
  ThumbnailGenerator._internal();

  static const int thumbnailSize = 200;
  static const int thumbnailQuality = 70;

  /// Generate thumbnail for any supported file type
  Future<String?> generateThumbnail({
    required File file,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      if (mimeType == null) {
        // Try to determine from file extension
        String extension = path.extension(file.path).toLowerCase();
        if ([
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
        ].contains(extension)) {
          mimeType = 'image/$extension';
        } else if ([
          '.mp4',
          '.mov',
          '.avi',
          '.mkv',
          '.webm',
        ].contains(extension)) {
          mimeType = 'video/$extension';
        }
      }

      if (mimeType?.startsWith('image/') == true) {
        return await _generateImageThumbnail(file, fileName);
      } else if (mimeType?.startsWith('video/') == true) {
        return await _generateVideoThumbnail(file, fileName);
      }

      return null;
    } catch (e) {
      debugPrint('Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// Generate thumbnail for image files
  Future<String?> _generateImageThumbnail(
    File imageFile,
    String fileName,
  ) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to thumbnail size while maintaining aspect ratio
      img.Image thumbnail = img.copyResize(
        image,
        width: thumbnailSize,
        height: thumbnailSize,
        maintainAspect: true,
      );

      // Encode as JPEG with quality compression
      List<int> thumbnailBytes = img.encodeJpg(
        thumbnail,
        quality: thumbnailQuality,
      );

      // Save thumbnail to cache directory
      String thumbnailPath = await _saveThumbnailToCache(
        Uint8List.fromList(thumbnailBytes),
        'thumb_$fileName.jpg',
      );

      return thumbnailPath;
    } catch (e) {
      debugPrint('Failed to generate image thumbnail: $e');
      return null;
    }
  }

  /// Generate thumbnail for video files
  Future<String?> _generateVideoThumbnail(
    File videoFile,
    String fileName,
  ) async {
    try {
      // Generate video thumbnail using video_thumbnail package
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: thumbnailSize,
        maxHeight: thumbnailSize,
        quality: thumbnailQuality,
      );

      if (thumbnailPath != null) {
        // Move thumbnail to cache directory with proper naming
        File tempThumbnail = File(thumbnailPath);
        String cachedPath = await _saveThumbnailToCache(
          await tempThumbnail.readAsBytes(),
          'thumb_$fileName.jpg',
        );

        // Clean up temporary file
        await tempThumbnail.delete();

        return cachedPath;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to generate video thumbnail: $e');
      return null;
    }
  }

  /// Save thumbnail bytes to cache directory
  Future<String> _saveThumbnailToCache(Uint8List bytes, String fileName) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    Directory thumbnailDir = Directory('${appDir.path}/thumbnails');

    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    File thumbnailFile = File('${thumbnailDir.path}/$fileName');
    await thumbnailFile.writeAsBytes(bytes);

    return thumbnailFile.path;
  }

  /// Get cached thumbnail if it exists
  Future<String?> getCachedThumbnail(String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      File thumbnailFile = File(
        '${appDir.path}/thumbnails/thumb_$fileName.jpg',
      );

      if (await thumbnailFile.exists()) {
        return thumbnailFile.path;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached thumbnails
  Future<void> clearThumbnailCache() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory thumbnailDir = Directory('${appDir.path}/thumbnails');

      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to clear thumbnail cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getThumbnailCacheSize() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory thumbnailDir = Directory('${appDir.path}/thumbnails');

      if (!await thumbnailDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      List<FileSystemEntity> files = await thumbnailDir.list().toList();

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
