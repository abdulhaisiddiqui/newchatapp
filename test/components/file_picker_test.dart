import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatapp/components/file_picker_widget.dart';
import 'package:chatapp/components/file_selection_dialog.dart';
import 'package:chatapp/components/file_preview_widget.dart';
import 'package:chatapp/components/file_icon_widget.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('File Picker Widget Tests', () {
    testWidgets('should display file picker button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFilePickerButton(onFilesSelected: (files) {}),
          ),
        ),
      );

      // Verify the file picker button is displayed
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);

      // Tap the button
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(FileSelectionDialog), findsOneWidget);
    });

    testWidgets('should display compact file picker', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactFilePicker(
              onFilesSelected: (files) {},
              buttonText: 'Select Files',
            ),
          ),
        ),
      );

      // Verify the compact picker is displayed
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Select Files'), findsOneWidget);
    });
  });

  group('File Preview Widget Tests', () {
    late FileAttachment testFileAttachment;

    setUp(() {
      testFileAttachment = FileAttachment(
        fileId: 'test_file_id',
        fileName: 'test_image.jpg',
        originalFileName: 'test_image.jpg',
        fileExtension: '.jpg',
        fileSizeBytes: 1024 * 1024, // 1MB
        mimeType: 'image/jpeg',
        downloadUrl: 'https://example.com/test_image.jpg',
        uploadedAt: Timestamp.now(),
        uploadedBy: 'test_user',
        status: FileStatus.uploaded,
      );
    });

    testWidgets('should display file preview for image', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewWidget(fileAttachment: testFileAttachment),
          ),
        ),
      );

      // Verify the preview widget is displayed
      expect(find.byType(FilePreviewWidget), findsOneWidget);

      // Should show file info
      expect(find.text('test_image.jpg'), findsOneWidget);
      expect(find.text('1.0 MB'), findsOneWidget);
    });

    testWidgets('should display document preview', (WidgetTester tester) async {
      FileAttachment documentAttachment = testFileAttachment.copyWith(
        fileName: 'test_document.pdf',
        originalFileName: 'test_document.pdf',
        fileExtension: '.pdf',
        mimeType: 'application/pdf',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewWidget(fileAttachment: documentAttachment),
          ),
        ),
      );

      // Verify document preview
      expect(find.byType(FilePreviewWidget), findsOneWidget);
      expect(find.text('test_document.pdf'), findsOneWidget);
    });

    testWidgets('should handle download button tap', (
      WidgetTester tester,
    ) async {
      bool downloadCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewWidget(
              fileAttachment: testFileAttachment,
              onDownload: () {
                downloadCalled = true;
              },
            ),
          ),
        ),
      );

      // Find and tap download button
      final downloadButton = find.byIcon(Icons.download);
      if (downloadButton.evaluate().isNotEmpty) {
        await tester.tap(downloadButton);
        await tester.pumpAndSettle();

        expect(downloadCalled, true);
      }
    });
  });

  group('File Selection Dialog Tests', () {
    testWidgets('should display file selection options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        FileSelectionDialog(onFilesSelected: (files) {}),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is shown with options
      expect(find.byType(FileSelectionDialog), findsOneWidget);
      expect(find.text('Select Files'), findsOneWidget);
      expect(find.text('Photos & Videos'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('All Files'), findsOneWidget);
    });

    testWidgets('should close dialog when cancel is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        FileSelectionDialog(onFilesSelected: (files) {}),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(FileSelectionDialog), findsNothing);
    });
  });

  group('File Icon Widget Tests', () {
    testWidgets('should display correct icon for image files', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileIconWidget(fileName: 'test.jpg', mimeType: 'image/jpeg'),
          ),
        ),
      );

      expect(find.byType(FileIconWidget), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('should display correct icon for document files', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileIconWidget(
              fileName: 'test.pdf',
              mimeType: 'application/pdf',
            ),
          ),
        ),
      );

      expect(find.byType(FileIconWidget), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('should display file type icon with extension', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FileTypeIcon(fileExtension: '.pdf')),
        ),
      );

      expect(find.byType(FileTypeIcon), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
    });
  });
}
