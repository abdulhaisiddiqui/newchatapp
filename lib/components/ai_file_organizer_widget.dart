import 'package:flutter/material.dart';
import 'package:chatapp/model/file_attachment.dart';
import 'package:chatapp/services/file/ai_file_organizer.dart';

class AIFileOrganizerWidget extends StatefulWidget {
  final List<FileAttachment> files;
  final Function(Map<String, List<FileAttachment>>)? onOrganizationApplied;

  const AIFileOrganizerWidget({
    super.key,
    required this.files,
    this.onOrganizationApplied,
  });

  @override
  State<AIFileOrganizerWidget> createState() => _AIFileOrganizerWidgetState();
}

class _AIFileOrganizerWidgetState extends State<AIFileOrganizerWidget> {
  BatchOrganizationResult? _organizationResult;
  bool _isAnalyzing = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _analyzeFiles();
  }

  Future<void> _analyzeFiles() async {
    if (widget.files.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      final result = await AIFileOrganizer().analyzeFiles(widget.files);
      setState(() {
        _organizationResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showError('Failed to analyze files: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return _buildAnalyzingView();
    }

    if (_organizationResult == null) {
      return _buildEmptyView();
    }

    return _buildResultsView();
  }

  Widget _buildAnalyzingView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.psychology, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'AI File Organizer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Analyzing your files with AI...'),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Processing ${widget.files.length} files',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No files to organize',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final result = _organizationResult!;
    final organizationRate = (result.organizationRate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'AI File Organizer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showDetails ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    organizationRate > 80 ? Icons.check_circle : Icons.info,
                    color: organizationRate > 80 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$organizationRate% of your files were automatically categorized',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Organization suggestions
            if (result.organizationSuggestions.isNotEmpty) ...[
              const Text(
                'Organization Suggestions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.organizationSuggestions.map(
                (suggestion) => _buildSuggestionCard(suggestion),
              ),
            ],

            // Detailed results
            if (_showDetails) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'File Analysis Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.results.map(
                (fileResult) => _buildFileResultCard(fileResult),
              ),
            ],

            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzeFiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-analyze'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: result.organizationSuggestions.isNotEmpty
                        ? _applyOrganization
                        : null,
                    icon: const Icon(Icons.folder),
                    label: const Text('Apply Organization'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(OrganizationSuggestion suggestion) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              suggestion.category.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${suggestion.fileCount} files',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildFileResultCard(FileOrganizationResult fileResult) {
    final file = fileResult.fileAttachment;
    final category = fileResult.primaryCategory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // File icon
            const Icon(Icons.insert_drive_file, size: 32),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.originalFileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file.formattedFileSize,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),

            // Category suggestion
            if (category != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(category.confidence),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      category.category.icon,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      category.category.name,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(category.confidence * 100).round()}%',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(width: 12),
              const Text(
                'No suggestion',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  void _applyOrganization() {
    if (_organizationResult == null) return;

    // Group files by category
    Map<String, List<FileAttachment>> organizedFiles = {};

    for (var result in _organizationResult!.results) {
      if (result.primaryCategory != null) {
        String categoryName = result.primaryCategory!.category.name;
        organizedFiles
            .putIfAbsent(categoryName, () => [])
            .add(result.fileAttachment);
      }
    }

    widget.onOrganizationApplied?.call(organizedFiles);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Organized ${organizedFiles.length} categories!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Quick access widget for file organization
class QuickFileOrganizer extends StatelessWidget {
  final List<FileAttachment> files;

  const QuickFileOrganizer({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.psychology),
      tooltip: 'AI File Organizer',
      onPressed: () => _showOrganizerDialog(context),
    );
  }

  void _showOrganizerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'AI File Organizer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AIFileOrganizerWidget(
                  files: files,
                  onOrganizationApplied: (organizedFiles) {
                    Navigator.of(context).pop();
                    // Handle organization application
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
