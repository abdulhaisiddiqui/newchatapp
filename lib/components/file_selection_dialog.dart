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
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Share content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Selecting files...'),
                        ],
                      ),
                    )
                  : GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      padding: const EdgeInsets.all(20),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      children: [
                        _buildGridItem(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          color: Colors.blue,
                          onTap: () => _pickFromGallery(),
                        ),
                        _buildGridItem(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          color: Colors.red,
                          onTap: () => _pickFromCamera(),
                        ),
                        _buildGridItem(
                          icon: Icons.insert_drive_file,
                          label: 'Document',
                          color: Colors.green,
                          onTap: () => _pickDocuments(),
                        ),
                        _buildGridItem(
                          icon: Icons.audio_file,
                          label: 'Audio',
                          color: Colors.orange,
                          onTap: () => _pickAudioFiles(),
                        ),
                        _buildGridItem(
                          icon: Icons.contact_page,
                          label: 'Contact',
                          color: Colors.purple,
                          onTap: () => _pickContact(),
                        ),
                        _buildGridItem(
                          icon: Icons.location_on,
                          label: 'Location',
                          color: Colors.teal,
                          onTap: () => _pickLocation(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions - use photos permission for Android 13+, storage for older
      List<Permission> permissionsToCheck = [Permission.photos];
      if (Platform.isAndroid) {
        // For older Android versions, photos permission might not be available
        // so we fall back to storage permission
        try {
          await Permission.photos.status;
        } catch (e) {
          permissionsToCheck = [Permission.storage];
        }
      }

      if (!await _checkPermissions(permissionsToCheck)) {
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
      // Check permissions - for Android 13+, file_picker handles permissions internally
      // For older Android versions, we need storage permission
      if (Platform.isAndroid) {
        // Check Android version
        // For simplicity, we'll request storage permission which works for older versions
        // For Android 13+, the system file picker will handle permission requests
        if (!await _checkPermissions([Permission.storage])) {
          _showPermissionDeniedDialog();
          return;
        }
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

  Future<void> _pickAudioFiles() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions - for Android 13+, use audio permission
      List<Permission> permissionsToCheck = [Permission.storage];
      if (Platform.isAndroid) {
        // For Android 13+, we can use Permission.audio for audio files
        permissionsToCheck = [Permission.audio];
      }

      if (!await _checkPermissions(permissionsToCheck)) {
        _showPermissionDeniedDialog();
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
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
      _showErrorDialog('Failed to select audio files: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickContact() async {
    // For now, show a message that contact sharing is not implemented
    _showErrorDialog('Contact sharing is not yet implemented in this version.');
  }

  Future<void> _pickLocation() async {
    // For now, show a message that location sharing is not implemented
    _showErrorDialog(
      'Location sharing is not yet implemented in this version.',
    );
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

      if (status.isDenied || status.isLimited) {
        // For Android 13+, some permissions might be limited
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
