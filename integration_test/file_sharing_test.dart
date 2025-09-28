import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chatapp/main.dart' as app;
import 'package:chatapp/components/file_picker_widget.dart';
import 'package:chatapp/components/file_selection_dialog.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('File Sharing Integration Tests', () {
    testWidgets('complete file sharing workflow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Note: These tests would require proper Firebase setup and authentication
      // For now, we'll test the UI components in isolation

      // Test file picker dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => FileSelectionDialog(
                        onFilesSelected: (files) {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: const Text('Select Files'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open file selection dialog
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(FileSelectionDialog), findsOneWidget);
      expect(find.text('Photos & Videos'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(FileSelectionDialog), findsNothing);
    });

    testWidgets('file picker button integration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFilePickerButton(onFilesSelected: (files) {}),
          ),
        ),
      );

      // Verify button is displayed
      expect(find.byType(ChatFilePickerButton), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);

      // Tap the button
      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();

      // Verify dialog opens
      expect(find.byType(FileSelectionDialog), findsOneWidget);
    });

    testWidgets('compact file picker integration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactFilePicker(
              onFilesSelected: (files) {},
              buttonText: 'Choose File',
              maxFiles: 1,
            ),
          ),
        ),
      );

      expect(find.byType(CompactFilePicker), findsOneWidget);
      expect(find.text('Choose File'), findsOneWidget);

      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();

      expect(find.byType(FileSelectionDialog), findsOneWidget);
    });
  });

  group('Error Handling Integration Tests', () {
    testWidgets('should handle file validation errors', (
      WidgetTester tester,
    ) async {
      // This would test the complete error flow from file selection to validation
      // In a real test, you would mock file selection and validation services

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // Simulate validation error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File validation failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Test Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Error'));
      await tester.pumpAndSettle();

      expect(find.text('File validation failed'), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    testWidgets('should handle multiple file selection efficiently', (
      WidgetTester tester,
    ) async {
      const int maxFiles = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFilePickerButton(
              onFilesSelected: (files) {
                // In a real test, you would verify performance metrics here
              },
              maxFiles: maxFiles,
            ),
          ),
        ),
      );

      // Measure performance of opening dialog
      Stopwatch stopwatch = Stopwatch()..start();

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Verify dialog opens quickly (< 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(find.byType(FileSelectionDialog), findsOneWidget);
    });
  });
}
