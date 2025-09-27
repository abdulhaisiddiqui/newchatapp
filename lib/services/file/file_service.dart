import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/services/file/file_upload_result.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants
  static const String CHAT_FILES_PATH = 'chat_files';
  static const String THUMBNAILS_PATH = 'thumbnails';
  static const int MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB
  static const Duration CACHE_DURATION = Duration(days: 7);

  /// Upload a file to Firebase Storage
  Future<FileUploadResult> uploadFile({
    required File file,
    required String chatRoomId,
    required String messageId,
    Function(double)? onProgress,
  }) async {
    try {
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return FileUploadResult.error('User not authenticated');
      }

      // Validate file size
      int fileSize = await file.length();
      if (fileSize > MAX_FILE_SIZE) {
        return FileUploadResult.error('File size exceeds 50MB limit');
      }

      // Generate unique file ID and name
      String fileId = _generateFileId();
      String originalFileName = path.basename(file.path);
      String fileExtension = path.extension(file.path).toLowerCase();
      String fileName = '$fileId$fileExtension';

      // Get MIME type
      String? mimeType =
          lookupMimeType(file.path) ?? 'application/octet-stream';

      // Create storage path
      String storagePath = '$CHAT_FILES_PATH/$chatRoomId/$fileName';

      // Upload file to Firebase Storage
      UploadTask uploadTask = _storage.ref(storagePath).putFile(file);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        }
      });

      // Wait for upload completion
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create FileAttachment object
      FileAttachment fileAttachment = FileAttachment(
        fileId: fileId,
        fileName: fileName,
        originalFileName: originalFileName,
        fileExtension: fileExtension,
        fileSizeBytes: fileSize,
        mimeType: mimeType,
        downloadUrl: downloadUrl,
        uploadedAt: Timestamp.now(),
        uploadedBy: currentUser.uid,
        status: FileStatus.uploaded,
      );

      // Store file metadata in Firestore
      await _storeFileMetadata(fileAttachment, chatRoomId, messageId);

      return FileUploadResult.success(downloadUrl: downloadUrl, fileId: fileId);
    } catch (e) {
      return FileUploadResult.error(
        'Upload failed: ${e.toString()}',
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Download a file from Firebase Storage
  Future<FileDownloadResult> downloadFile({
    required String downloadUrl,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      // Check if file is already cached
      File? cachedFile = await _getCachedFile(fileName);
      if (cachedFile != null && await cachedFile.exists()) {
        return FileDownloadResult.success(cachedFile.path);
      }

      // Get local file path
      String localPath = await _getLocalFilePath(fileName);
      File localFile = File(localPath);

      // Download from Firebase Storage
      Reference ref = _storage.refFromURL(downloadUrl);

      // Create download task
      DownloadTask downloadTask = ref.writeToFile(localFile);

      // Track progress
      downloadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        }
      });

      // Wait for download completion
      await downloadTask;

      // Cache the file
      await _cacheFile(localFile, fileName);

      return FileDownloadResult.success(localPath);
    } catch (e) {
      return FileDownloadResult.error(
        'Download failed: ${e.toString()}',
        e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Delete a file from Firebase Storage and Firestore
  Future<bool> deleteFile({
    required String fileId,
    required String chatRoomId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get file metadata
      DocumentSnapshot fileDoc = await _firestore
          .collection('files')
          .doc(fileId)
          .get();

      if (!fileDoc.exists) return false;

      Map<String, dynamic> fileData = fileDoc.data() as Map<String, dynamic>;

      // Check if user has permission to delete
      if (fileData['uploadedBy'] != currentUser.uid) {
        return false;
      }

      String fileName = fileData['fileName'];

      // Delete from Firebase Storage
      String storagePath = '$CHAT_FILES_PATH/$chatRoomId/$fileName';
      await _storage.ref(storagePath).delete();

      // Delete thumbnail if exists
      if (fileData['thumbnailUrl'] != null) {
        String thumbnailPath = '$THUMBNAILS_PATH/thumb_$fileName';
        try {
          await _storage.ref(thumbnailPath).delete();
        } catch (e) {
          // Thumbnail deletion failed, but continue
        }
      }

      // Update file status in Firestore
      await _firestore.collection('files').doc(fileId).update({
        'status': FileStatus.deleted.name,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // Remove from local cache
      await _removeCachedFile(fileName);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file metadata from Firestore
  Future<FileAttachment?> getFileMetadata(String fileId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('files')
          .doc(fileId)
          .get();

      if (doc.exists) {
        return FileAttachment.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Store file metadata in Firestore
  Future<void> _storeFileMetadata(
    FileAttachment fileAttachment,
    String chatRoomId,
    String messageId,
  ) async {
    await _firestore.collection('files').doc(fileAttachment.fileId).set({
      ...fileAttachment.toMap(),
      'chatRoomId': chatRoomId,
      'messageId': messageId,
    });
  }

  /// Generate unique file ID
  String _generateFileId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid ?? 'unknown'}';
  }

  /// Get local file path for downloads
  Future<String> _getLocalFilePath(String fileName) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    Directory downloadDir = Directory('${appDir.path}/downloads');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return '${downloadDir.path}/$fileName';
  }

  /// Get cached file if it exists and is still valid
  Future<File?> _getCachedFile(String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/file_cache');

      if (!await cacheDir.exists()) {
        return null;
      }

      File cachedFile = File('${cacheDir.path}/$fileName');

      if (await cachedFile.exists()) {
        // Check if cache is still valid
        DateTime lastModified = await cachedFile.lastModified();
        if (DateTime.now().difference(lastModified) < CACHE_DURATION) {
          return cachedFile;
        } else {
          // Cache expired, delete it
          await cachedFile.delete();
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cache a downloaded file
  Future<void> _cacheFile(File file, String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/file_cache');

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      File cachedFile = File('${cacheDir.path}/$fileName');
      await file.copy(cachedFile.path);
    } catch (e) {
      // Caching failed, but don't throw error
    }
  }

  /// Remove cached file
  Future<void> _removeCachedFile(String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      File cachedFile = File('${appDir.path}/file_cache/$fileName');

      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clean up old cached files
  Future<void> cleanupCache() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/file_cache');

      if (!await cacheDir.exists()) return;

      List<FileSystemEntity> files = await cacheDir.list().toList();
      DateTime now = DateTime.now();

      for (FileSystemEntity entity in files) {
        if (entity is File) {
          DateTime lastModified = await entity.lastModified();
          if (now.difference(lastModified) > CACHE_DURATION) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Get total cache size
  Future<int> getCacheSize() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      Directory cacheDir = Directory('${appDir.path}/file_cache');

      if (!await cacheDir.exists()) return 0;

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

  /// Format file size for display
  static String formatFileSize(int bytes) {
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
}
