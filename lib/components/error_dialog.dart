import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showRetry;

  const ErrorDialog({
    Key? key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.onDismiss,
    this.showRetry = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (details != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Details', style: TextStyle(fontSize: 14)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    details!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('OK'),
        ),
        if (showRetry && onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool showRetry = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        details: details,
        onRetry: onRetry,
        onDismiss: onDismiss,
        showRetry: showRetry,
      ),
    );
  }
}

// Specialized error dialogs for common scenarios
class FileErrorDialog {
  static void showUploadError(
    BuildContext context, {
    required String fileName,
    required String error,
    VoidCallback? onRetry,
  }) {
    ErrorDialog.show(
      context,
      title: 'Upload Failed',
      message: 'Failed to upload "$fileName"',
      details: error,
      showRetry: onRetry != null,
      onRetry: onRetry,
    );
  }

  static void showDownloadError(
    BuildContext context, {
    required String fileName,
    required String error,
    VoidCallback? onRetry,
  }) {
    ErrorDialog.show(
      context,
      title: 'Download Failed',
      message: 'Failed to download "$fileName"',
      details: error,
      showRetry: onRetry != null,
      onRetry: onRetry,
    );
  }

  static void showValidationError(
    BuildContext context, {
    required String fileName,
    required String error,
  }) {
    ErrorDialog.show(
      context,
      title: 'File Not Supported',
      message: 'Cannot upload "$fileName"',
      details: error,
    );
  }

  static void showPermissionError(
    BuildContext context, {
    required String permission,
    VoidCallback? onOpenSettings,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          'This app needs $permission permission to function properly. '
          'Please grant permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenSettings?.call();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}

// Success dialog for positive feedback
class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  const SuccessDialog({
    Key? key,
    required this.title,
    required this.message,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          SuccessDialog(title: title, message: message, onDismiss: onDismiss),
    );
  }
}

// Warning dialog for user confirmation
class WarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const WarningDialog({
    Key? key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_outlined, color: Colors.orange.shade600, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          style: isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => WarningDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
      ),
    );
  }
}

// Snackbar utilities for quick feedback
class AppSnackBar {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration,
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: duration,
      ),
    );
  }
}
