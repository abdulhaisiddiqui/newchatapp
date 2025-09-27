import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:chatapp/services/file/validation_result.dart';

class FileSecurityService {
  static final FileSecurityService _instance = FileSecurityService._internal();
  factory FileSecurityService() => _instance;
  FileSecurityService._internal();

  // File size limits (in bytes)
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const int maxDocumentSize = 25 * 1024 * 1024; // 25MB
  static const int maxAudioSize = 20 * 1024 * 1024; // 20MB

  // Maximum files per message
  static const int maxFilesPerMessage = 10;

  // Allowed file extensions
  static const Map<String, List<String>> allowedExtensions = {
    'image': ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'],
    'video': ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'],
    'document': [
      '.pdf',
      '.doc',
      '.docx',
      '.txt',
      '.rtf',
      '.odt',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
    ],
    'audio': ['.mp3', '.wav', '.aac', '.ogg', '.m4a', '.flac'],
    'archive': ['.zip', '.rar', '.7z', '.tar', '.gz'],
  };

  // Allowed MIME types
  static const Map<String, List<String>> allowedMimeTypes = {
    'image': [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/svg+xml',
    ],
    'video': [
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo',
      'video/x-matroska',
      'video/webm',
      'video/3gpp',
    ],
    'document': [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'text/rtf',
      'application/vnd.oasis.opendocument.text',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ],
    'audio': [
      'audio/mpeg',
      'audio/wav',
      'audio/aac',
      'audio/ogg',
      'audio/mp4',
      'audio/flac',
    ],
    'archive': [
      'application/zip',
      'application/x-rar-compressed',
      'application/x-7z-compressed',
      'application/x-tar',
      'application/gzip',
    ],
  };

  // Dangerous file extensions (always blocked)
  static const List<String> blockedExtensions = [
    '.exe',
    '.bat',
    '.cmd',
    '.com',
    '.pif',
    '.scr',
    '.vbs',
    '.js',
    '.jar',
    '.app',
    '.deb',
    '.pkg',
    '.dmg',
    '.msi',
    '.run',
    '.sh',
    '.ps1',
    '.py',
    '.rb',
    '.pl',
    '.php',
    '.asp',
    '.jsp',
  ];

  // Known malware file signatures (simplified examples)
  static const List<List<int>> malwareSignatures = [
    [0x4D, 0x5A], // PE executable header
    [0x50, 0x4B, 0x03, 0x04], // ZIP file (could contain malware)
  ];

  /// Validate a single file
  Future<ValidationResult> validateFile(File file) async {
    try {
      List<String> warnings = [];
      Map<String, dynamic> metadata = {};

      // 1. Check if file exists
      if (!await file.exists()) {
        return ValidationResult.error('File does not exist');
      }

      // 2. Get file info
      String fileName = path.basename(file.path);
      String fileExtension = path.extension(file.path).toLowerCase();
      int fileSize = await file.length();
      String? mimeType = lookupMimeType(file.path);

      metadata['fileName'] = fileName;
      metadata['fileExtension'] = fileExtension;
      metadata['fileSize'] = fileSize;
      metadata['mimeType'] = mimeType;

      // 3. Check file size
      ValidationResult sizeCheck = _validateFileSize(fileSize, mimeType);
      if (!sizeCheck.isValid) {
        return sizeCheck;
      }
      warnings.addAll(sizeCheck.warnings);

      // 4. Check file extension
      ValidationResult extensionCheck = _validateFileExtension(fileExtension);
      if (!extensionCheck.isValid) {
        return extensionCheck;
      }
      warnings.addAll(extensionCheck.warnings);

      // 5. Check MIME type
      if (mimeType != null) {
        ValidationResult mimeCheck = _validateMimeType(mimeType);
        if (!mimeCheck.isValid) {
          return mimeCheck;
        }
        warnings.addAll(mimeCheck.warnings);
      } else {
        warnings.add('Could not determine file type');
      }

      // 6. Check file content integrity
      ValidationResult integrityCheck = await _validateFileIntegrity(file);
      if (!integrityCheck.isValid) {
        return integrityCheck;
      }
      warnings.addAll(integrityCheck.warnings);

      // 7. Basic malware scan
      ValidationResult malwareCheck = await _basicMalwareScan(file);
      if (!malwareCheck.isValid) {
        return malwareCheck;
      }
      warnings.addAll(malwareCheck.warnings);

      return ValidationResult.success(warnings: warnings, metadata: metadata);
    } catch (e) {
      return ValidationResult.error('File validation failed: ${e.toString()}');
    }
  }

  /// Validate multiple files
  Future<ValidationResult> validateFiles(List<File> files) async {
    if (files.isEmpty) {
      return ValidationResult.error('No files provided');
    }

    if (files.length > maxFilesPerMessage) {
      return ValidationResult.error(
        'Too many files. Maximum $maxFilesPerMessage files allowed per message',
      );
    }

    List<String> allWarnings = [];
    int totalSize = 0;

    for (int i = 0; i < files.length; i++) {
      ValidationResult result = await validateFile(files[i]);

      if (!result.isValid) {
        return ValidationResult.error(
          'File ${i + 1} validation failed: ${result.error}',
        );
      }

      allWarnings.addAll(result.warnings);

      if (result.metadata != null && result.metadata!['fileSize'] != null) {
        totalSize += result.metadata!['fileSize'] as int;
      }
    }

    // Check total size
    if (totalSize > maxFileSize * 2) {
      // Allow up to 2x single file limit for multiple files
      return ValidationResult.error(
        'Total file size too large. Maximum ${_formatFileSize(maxFileSize * 2)} allowed',
      );
    }

    return ValidationResult.success(
      warnings: allWarnings,
      metadata: {'totalSize': totalSize, 'fileCount': files.length},
    );
  }

  /// Validate file size based on type
  ValidationResult _validateFileSize(int fileSize, String? mimeType) {
    if (fileSize == 0) {
      return ValidationResult.error('File is empty');
    }

    if (fileSize > maxFileSize) {
      return ValidationResult.error(
        'File size exceeds maximum limit of ${_formatFileSize(maxFileSize)}',
      );
    }

    // Type-specific size limits
    if (mimeType != null) {
      if (mimeType.startsWith('image/') && fileSize > maxImageSize) {
        return ValidationResult.error(
          'Image size exceeds maximum limit of ${_formatFileSize(maxImageSize)}',
        );
      } else if (mimeType.startsWith('video/') && fileSize > maxVideoSize) {
        return ValidationResult.error(
          'Video size exceeds maximum limit of ${_formatFileSize(maxVideoSize)}',
        );
      } else if (mimeType.startsWith('audio/') && fileSize > maxAudioSize) {
        return ValidationResult.error(
          'Audio size exceeds maximum limit of ${_formatFileSize(maxAudioSize)}',
        );
      } else if (_isDocumentMimeType(mimeType) && fileSize > maxDocumentSize) {
        return ValidationResult.error(
          'Document size exceeds maximum limit of ${_formatFileSize(maxDocumentSize)}',
        );
      }
    }

    List<String> warnings = [];
    if (fileSize > maxFileSize * 0.8) {
      // Warn at 80% of limit
      warnings.add('File is quite large and may take longer to upload');
    }

    return ValidationResult.success(warnings: warnings);
  }

  /// Validate file extension
  ValidationResult _validateFileExtension(String extension) {
    // Check if extension is blocked
    if (blockedExtensions.contains(extension)) {
      return ValidationResult.error(
        'File type $extension is not allowed for security reasons',
      );
    }

    // Check if extension is in allowed list
    bool isAllowed = false;
    for (List<String> extensions in allowedExtensions.values) {
      if (extensions.contains(extension)) {
        isAllowed = true;
        break;
      }
    }

    if (!isAllowed) {
      return ValidationResult.error('File type $extension is not supported');
    }

    return ValidationResult.success();
  }

  /// Validate MIME type
  ValidationResult _validateMimeType(String mimeType) {
    // Check if MIME type is in allowed list
    bool isAllowed = false;
    for (List<String> mimeTypes in allowedMimeTypes.values) {
      if (mimeTypes.contains(mimeType)) {
        isAllowed = true;
        break;
      }
    }

    if (!isAllowed) {
      return ValidationResult.error('File format $mimeType is not supported');
    }

    return ValidationResult.success();
  }

  /// Basic file integrity check
  Future<ValidationResult> _validateFileIntegrity(File file) async {
    try {
      // Try to read the first few bytes to ensure file is readable
      RandomAccessFile raf = await file.open();
      await raf.read(
        Math.min(1024, await file.length()),
      ); // Read first 1KB or entire file
      await raf.close();

      return ValidationResult.success();
    } catch (e) {
      return ValidationResult.error(
        'File appears to be corrupted or unreadable',
      );
    }
  }

  /// Basic malware scan (simplified)
  Future<ValidationResult> _basicMalwareScan(File file) async {
    try {
      // Read first 1KB of file for signature checking
      RandomAccessFile raf = await file.open();
      int bytesToRead = Math.min(1024, await file.length());
      Uint8List bytes = await raf.read(bytesToRead);
      await raf.close();

      // Check for known malware signatures
      for (List<int> signature in malwareSignatures) {
        if (_containsSignature(bytes, signature)) {
          return ValidationResult.error(
            'File contains suspicious content and cannot be uploaded',
          );
        }
      }

      // Additional checks for executable files disguised as other types
      String fileName = path.basename(file.path).toLowerCase();
      if (_hasExecutableSignature(bytes) && !fileName.endsWith('.exe')) {
        return ValidationResult.error(
          'File appears to be an executable disguised as another file type',
        );
      }

      return ValidationResult.success();
    } catch (e) {
      // If scan fails, allow file but add warning
      return ValidationResult.success(
        warnings: ['Could not perform security scan on file'],
      );
    }
  }

  /// Check if bytes contain a specific signature
  bool _containsSignature(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;

    for (int i = 0; i <= bytes.length - signature.length; i++) {
      bool match = true;
      for (int j = 0; j < signature.length; j++) {
        if (bytes[i + j] != signature[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  /// Check if file has executable signature
  bool _hasExecutableSignature(Uint8List bytes) {
    if (bytes.length < 2) return false;

    // Check for PE header (Windows executable)
    if (bytes[0] == 0x4D && bytes[1] == 0x5A) return true;

    // Check for ELF header (Linux executable)
    if (bytes.length >= 4 &&
        bytes[0] == 0x7F &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4C &&
        bytes[3] == 0x46) {
      return true;
    }

    // Check for Mach-O header (macOS executable)
    if (bytes.length >= 4 &&
        ((bytes[0] == 0xFE &&
                bytes[1] == 0xED &&
                bytes[2] == 0xFA &&
                bytes[3] == 0xCE) ||
            (bytes[0] == 0xCE &&
                bytes[1] == 0xFA &&
                bytes[2] == 0xED &&
                bytes[3] == 0xFE))) {
      return true;
    }

    return false;
  }

  /// Check if MIME type is a document type
  bool _isDocumentMimeType(String mimeType) {
    return allowedMimeTypes['document']?.contains(mimeType) ?? false;
  }

  /// Format file size for display
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

  /// Get file category from extension
  static String getFileCategory(String extension) {
    extension = extension.toLowerCase();

    for (String category in allowedExtensions.keys) {
      if (allowedExtensions[category]!.contains(extension)) {
        return category;
      }
    }

    return 'other';
  }

  /// Check if file type is allowed
  static bool isFileTypeAllowed(String extension) {
    extension = extension.toLowerCase();

    if (blockedExtensions.contains(extension)) {
      return false;
    }

    for (List<String> extensions in allowedExtensions.values) {
      if (extensions.contains(extension)) {
        return true;
      }
    }

    return false;
  }

  /// Get maximum file size for a specific type
  static int getMaxFileSizeForType(String? mimeType) {
    if (mimeType == null) {
      return maxFileSize;
    }

    if (mimeType.startsWith('image/')) {
      return maxImageSize;
    } else if (mimeType.startsWith('video/')) {
      return maxVideoSize;
    } else if (mimeType.startsWith('audio/')) {
      return maxAudioSize;
    } else if (allowedMimeTypes['document']?.contains(mimeType) ?? false) {
      return maxDocumentSize;
    }

    return maxFileSize;
  }
}

// Helper class for Math.min since dart:math might not be imported
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
