import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatapp/services/file/file_security_service.dart';

class FileSelectionDialog extends StatefulWidget {
  final Function(List<File>) onFilesSelected;
  final int maxFiles;
  final List<String>? allowedExtensions;

  const FileSelectionDialog({
    Key? key,
    required this.onFilesSelected,
    this.maxFiles = 10,
    this.allowedExtensions,
  }) : super(key: key);

  @override
  State<FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<FileSelectionDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Files'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            icon: Icons.photo_library,
            title: 'Photos & Videos',
            subtitle: 'Select from gallery',
            onTap: () => _pickFromGallery(),
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.camera_alt,
            title: 'Camera',
            subtitle: 'Take a photo',
            onTap: () => _pickFromCamera(),
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.insert_drive_file,
            title: 'Documents',
            subtitle: 'Select files',
            onTap: () => _pickDocuments(),
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.folder,
            title: 'All Files',
            subtitle: 'Browse all file types',
            onTap: () => _pickAllFiles(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Selecting files...'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      onTap: _isLoading ? null : onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      if (!await _checkPermissions([Permission.photos])) {
        _showPermissionDeniedDialog();
        return;
      }

      if (widget.maxFiles == 1) {
        // Single image selection
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image != null) {
          await _handleSelectedFiles([File(image.path)]);
        }
      } else {
        // Multiple image selection
        final List<XFile> images = await _imagePicker.pickMultipleMedia(
          imageQuality: 85,
        );

        if (images.isNotEmpty) {
          List<File> files = images.map((xFile) => File(xFile.path)).toList();
          await _handleSelectedFiles(files);
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to select from gallery: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      if (!await _checkPermissions([Permission.camera])) {
        _showPermissionDeniedDialog();
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleSelectedFiles([File(image.path)]);
      }
    } catch (e) {
      _showErrorDialog('Failed to take photo: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDocuments() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      if (!await _checkPermissions([Permission.storage])) {
        _showPermissionDeniedDialog();
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'odt',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ],
        allowMultiple: widget.maxFiles > 1,
      );

      if (result != null) {
        List<File> files = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        if (files.isNotEmpty) {
          await _handleSelectedFiles(files);
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to select documents: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAllFiles() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      if (!await _checkPermissions([Permission.storage])) {
        _showPermissionDeniedDialog();
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: widget.allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: widget.allowedExtensions,
        allowMultiple: widget.maxFiles > 1,
      );

      if (result != null) {
        List<File> files = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        if (files.isNotEmpty) {
          await _handleSelectedFiles(files);
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to select files: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSelectedFiles(List<File> files) async {
    try {
      // Limit number of files
      if (files.length > widget.maxFiles) {
        files = files.take(widget.maxFiles).toList();
        _showWarningDialog(
          'Only the first ${widget.maxFiles} files will be selected.',
        );
      }

      // Validate files
      final securityService = FileSecurityService();
      final validationResult = await securityService.validateFiles(files);

      if (!validationResult.isValid) {
        _showErrorDialog(validationResult.error!);
        return;
      }

      // Show warnings if any
      if (validationResult.hasWarnings) {
        _showWarningDialog(validationResult.warnings.join('\n'));
      }

      // Return selected files
      widget.onFilesSelected(files);
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog('File validation failed: ${e.toString()}');
    }
  }

  Future<bool> _checkPermissions(List<Permission> permissions) async {
    for (Permission permission in permissions) {
      PermissionStatus status = await permission.status;

      if (status.isDenied) {
        status = await permission.request();
      }

      if (status.isPermanentlyDenied) {
        return false;
      }

      if (!status.isGranted) {
        return false;
      }
    }

    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'This app needs permission to access your files. '
          'Please grant permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
