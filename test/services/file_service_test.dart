import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:chatapp/services/file/file_service.dart';
import 'package:chatapp/services/file/file_security_service.dart';
import 'package:chatapp/services/file/file_compression_service.dart';

void main() {
  group('FileService Tests', () {
    late FileSecurityService securityService;
    late FileCompressionService compressionService;

    setUp(() {
      securityService = FileSecurityService();
      compressionService = FileCompressionService();
    });

    group('File Validation Tests', () {
      test('should validate file size correctly', () async {
        // Create a test file with known size
        File testFile = await _createTestFile(size: 1024 * 1024); // 1MB

        var result = await securityService.validateFile(testFile);

        expect(result.isValid, true);
        expect(result.metadata?['fileSize'], equals(1024 * 1024));

        // Clean up
        await testFile.delete();
      });

      test('should reject oversized files', () async {
        // Create a test file that exceeds the limit
        File testFile = await _createTestFile(size: 100 * 1024 * 1024); // 100MB

        var result = await securityService.validateFile(testFile);

        expect(result.isValid, false);
        expect(result.error, contains('size exceeds'));

        // Clean up
        await testFile.delete();
      });

      test('should reject blocked file extensions', () async {
        File testFile = await _createTestFileWithExtension('.exe');

        var result = await securityService.validateFile(testFile);

        expect(result.isValid, false);
        expect(result.error, contains('not allowed for security reasons'));

        // Clean up
        await testFile.delete();
      });

      test('should accept allowed file extensions', () async {
        File testFile = await _createTestFileWithExtension('.jpg');

        var result = await securityService.validateFile(testFile);

        expect(result.isValid, true);

        // Clean up
        await testFile.delete();
      });
    });

    group('File Compression Tests', () {
      test('should compress images correctly', () async {
        File imageFile = await _createTestImage(width: 4000, height: 3000);

        var result = await compressionService.compressFile(
          file: imageFile,
          mimeType: 'image/jpeg',
        );

        expect(result.isSuccess, true);
        expect(result.compressedSize, lessThan(result.originalSize!));
        expect(result.compressionRatio, lessThan(1.0));

        // Clean up
        await imageFile.delete();
        if (result.compressedFile != null) {
          await result.compressedFile!.delete();
        }
      });

      test('should handle compression errors gracefully', () async {
        // Create an invalid image file
        File invalidFile = await _createTestFile(size: 100);

        var result = await compressionService.compressFile(
          file: invalidFile,
          mimeType: 'image/jpeg',
        );

        expect(result.isSuccess, false);
        expect(result.error, isNotNull);

        // Clean up
        await invalidFile.delete();
      });
    });

    group('File Security Tests', () {
      test('should detect executable files', () async {
        // Create a file with PE header (Windows executable signature)
        File execFile = await _createFileWithSignature([0x4D, 0x5A]);

        var result = await securityService.validateFile(execFile);

        expect(result.isValid, false);
        expect(result.error, contains('executable'));

        // Clean up
        await execFile.delete();
      });

      test('should validate multiple files', () async {
        List<File> testFiles = [
          await _createTestFileWithExtension('.jpg'),
          await _createTestFileWithExtension('.pdf'),
          await _createTestFileWithExtension('.mp4'),
        ];

        var result = await securityService.validateFiles(testFiles);

        expect(result.isValid, true);
        expect(result.metadata?['fileCount'], equals(3));

        // Clean up
        for (File file in testFiles) {
          await file.delete();
        }
      });

      test('should reject too many files', () async {
        List<File> tooManyFiles = [];
        for (int i = 0; i < 15; i++) {
          tooManyFiles.add(await _createTestFileWithExtension('.txt'));
        }

        var result = await securityService.validateFiles(tooManyFiles);

        expect(result.isValid, false);
        expect(result.error, contains('Too many files'));

        // Clean up
        for (File file in tooManyFiles) {
          await file.delete();
        }
      });
    });

    group('File Type Detection Tests', () {
      test('should correctly identify file categories', () {
        expect(FileSecurityService.getFileCategory('.jpg'), equals('image'));
        expect(FileSecurityService.getFileCategory('.pdf'), equals('document'));
        expect(FileSecurityService.getFileCategory('.mp4'), equals('video'));
        expect(FileSecurityService.getFileCategory('.mp3'), equals('audio'));
        expect(FileSecurityService.getFileCategory('.zip'), equals('archive'));
        expect(
          FileSecurityService.getFileCategory('.unknown'),
          equals('other'),
        );
      });

      test('should check if file types are allowed', () {
        expect(FileSecurityService.isFileTypeAllowed('.jpg'), true);
        expect(FileSecurityService.isFileTypeAllowed('.pdf'), true);
        expect(FileSecurityService.isFileTypeAllowed('.exe'), false);
        expect(FileSecurityService.isFileTypeAllowed('.bat'), false);
      });
    });

    group('File Size Formatting Tests', () {
      test('should format file sizes correctly', () {
        expect(FileService.formatFileSize(500), equals('500 B'));
        expect(FileService.formatFileSize(1536), equals('1.5 KB'));
        expect(FileService.formatFileSize(2097152), equals('2.0 MB'));
        expect(FileService.formatFileSize(1073741824), equals('1.0 GB'));
      });
    });
  });
}

// Helper functions for creating test files
Future<File> _createTestFile({int size = 1024}) async {
  Directory tempDir = Directory.systemTemp;
  File testFile = File(
    '${tempDir.path}/test_file_${DateTime.now().millisecondsSinceEpoch}.txt',
  );

  // Create file with specified size
  Uint8List data = Uint8List(size);
  for (int i = 0; i < size; i++) {
    data[i] = i % 256;
  }

  await testFile.writeAsBytes(data);
  return testFile;
}

Future<File> _createTestFileWithExtension(String extension) async {
  Directory tempDir = Directory.systemTemp;
  File testFile = File(
    '${tempDir.path}/test_file_${DateTime.now().millisecondsSinceEpoch}$extension',
  );

  await testFile.writeAsString('Test file content');
  return testFile;
}

Future<File> _createFileWithSignature(List<int> signature) async {
  Directory tempDir = Directory.systemTemp;
  File testFile = File(
    '${tempDir.path}/test_file_${DateTime.now().millisecondsSinceEpoch}.bin',
  );

  Uint8List data = Uint8List(1024);
  // Add signature at the beginning
  for (int i = 0; i < signature.length && i < data.length; i++) {
    data[i] = signature[i];
  }

  await testFile.writeAsBytes(data);
  return testFile;
}

Future<File> _createTestImage({int width = 100, int height = 100}) async {
  Directory tempDir = Directory.systemTemp;
  File testFile = File(
    '${tempDir.path}/test_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );

  // Create a simple test image using the image package
  var image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 0, 0)); // Red image

  List<int> jpegBytes = img.encodeJpg(image);
  await testFile.writeAsBytes(jpegBytes);

  return testFile;
}
