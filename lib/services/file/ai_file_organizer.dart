import 'package:chatapp/model/file_attachment.dart';

/// AI-powered file organization system that automatically categorizes files
/// based on content analysis, naming patterns, and metadata
class AIFileOrganizer {
  static final AIFileOrganizer _instance = AIFileOrganizer._internal();
  factory AIFileOrganizer() => _instance;
  AIFileOrganizer._internal();

  // File category definitions with keywords and patterns
  static const Map<String, FileCategory> _categories = {
    'documents': FileCategory(
      name: 'Documents',
      icon: '📄',
      keywords: [
        'doc',
        'document',
        'pdf',
        'txt',
        'rtf',
        'odt',
        'contract',
        'agreement',
        'report',
        'memo',
        'letter',
        'invoice',
        'receipt',
        'statement',
        'form',
      ],
      mimeTypes: ['application/pdf', 'text/plain', 'application/msword'],
      extensions: ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt'],
    ),

    'images': FileCategory(
      name: 'Images',
      icon: '🖼️',
      keywords: [
        'photo',
        'picture',
        'image',
        'img',
        'pic',
        'screenshot',
        'capture',
        'diagram',
        'chart',
        'graph',
        'artwork',
        'design',
        'logo',
        'banner',
      ],
      mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'],
    ),

    'videos': FileCategory(
      name: 'Videos',
      icon: '🎥',
      keywords: [
        'video',
        'movie',
        'film',
        'clip',
        'recording',
        'tutorial',
        'demo',
        'presentation',
        'lecture',
        'webinar',
        'meeting',
        'interview',
      ],
      mimeTypes: ['video/mp4', 'video/quicktime', 'video/x-msvideo'],
      extensions: ['.mp4', '.mov', '.avi', '.mkv', '.webm'],
    ),

    'audio': FileCategory(
      name: 'Audio',
      icon: '🎵',
      keywords: [
        'audio',
        'music',
        'song',
        'sound',
        'voice',
        'recording',
        'podcast',
        'interview',
        'speech',
        'lecture',
        'meeting',
        'call',
      ],
      mimeTypes: ['audio/mpeg', 'audio/wav', 'audio/aac'],
      extensions: ['.mp3', '.wav', '.aac', '.ogg', '.m4a'],
    ),

    'spreadsheets': FileCategory(
      name: 'Spreadsheets',
      icon: '📊',
      keywords: [
        'excel',
        'spreadsheet',
        'xls',
        'data',
        'table',
        'chart',
        'budget',
        'financial',
        'analysis',
        'report',
        'tracking',
        'inventory',
        'list',
      ],
      mimeTypes: [
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
      extensions: ['.xls', '.xlsx', '.csv'],
    ),

    'presentations': FileCategory(
      name: 'Presentations',
      icon: '📽️',
      keywords: [
        'powerpoint',
        'presentation',
        'ppt',
        'slide',
        'deck',
        'pitch',
        'demo',
        'training',
        'workshop',
        'conference',
        'meeting',
      ],
      mimeTypes: [
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ],
      extensions: ['.ppt', '.pptx'],
    ),

    'archives': FileCategory(
      name: 'Archives',
      icon: '📦',
      keywords: [
        'zip',
        'archive',
        'compressed',
        'backup',
        'bundle',
        'package',
        'collection',
        'folder',
        'directory',
      ],
      mimeTypes: ['application/zip', 'application/x-rar-compressed'],
      extensions: ['.zip', '.rar', '.7z', '.tar', '.gz'],
    ),

    'code': FileCategory(
      name: 'Code Files',
      icon: '💻',
      keywords: [
        'code',
        'script',
        'program',
        'source',
        'development',
        'programming',
        'config',
        'configuration',
        'settings',
        'json',
        'xml',
        'yaml',
      ],
      mimeTypes: ['application/json', 'text/x-python', 'text/x-java-source'],
      extensions: [
        '.dart',
        '.py',
        '.js',
        '.java',
        '.cpp',
        '.c',
        '.h',
        '.json',
        '.xml',
        '.yaml',
        '.yml',
      ],
    ),

    'certificates': FileCategory(
      name: 'Certificates',
      icon: '🏆',
      keywords: [
        'certificate',
        'certification',
        'diploma',
        'degree',
        'license',
        'award',
        'achievement',
        'qualification',
        'credential',
      ],
      mimeTypes: ['application/pdf'],
      extensions: ['.pdf'],
    ),

    'invoices': FileCategory(
      name: 'Invoices & Bills',
      icon: '💰',
      keywords: [
        'invoice',
        'bill',
        'receipt',
        'payment',
        'expense',
        'purchase',
        'order',
        'transaction',
        'billing',
        'statement',
        'account',
      ],
      mimeTypes: ['application/pdf'],
      extensions: ['.pdf'],
    ),
  };

  /// Analyze a file and suggest the best category
  Future<FileOrganizationResult> analyzeFile(
    FileAttachment fileAttachment,
  ) async {
    List<CategorySuggestion> suggestions = [];

    // Analyze by MIME type
    String mimeType = fileAttachment.mimeType;
    var mimeSuggestions = _analyzeByMimeType(mimeType);
    suggestions.addAll(mimeSuggestions);

    // Analyze by file extension
    String extension = fileAttachment.fileExtension.toLowerCase();
    var extensionSuggestions = _analyzeByExtension(extension);
    suggestions.addAll(extensionSuggestions);

    // Analyze by filename
    String fileName = fileAttachment.originalFileName.toLowerCase();
    var nameSuggestions = _analyzeByFileName(fileName);
    suggestions.addAll(nameSuggestions);

    // Analyze by file size patterns
    var sizeSuggestions = _analyzeByFileSize(fileAttachment.fileSizeBytes);
    suggestions.addAll(sizeSuggestions);

    // Remove duplicates and sort by confidence
    Map<String, CategorySuggestion> uniqueSuggestions = {};
    for (var suggestion in suggestions) {
      if (uniqueSuggestions.containsKey(suggestion.categoryId)) {
        // Merge confidence scores
        var existing = uniqueSuggestions[suggestion.categoryId]!;
        uniqueSuggestions[suggestion.categoryId] = CategorySuggestion(
          categoryId: suggestion.categoryId,
          category: suggestion.category,
          confidence: (existing.confidence + suggestion.confidence) / 2,
          reasoning: '${existing.reasoning}, ${suggestion.reasoning}',
        );
      } else {
        uniqueSuggestions[suggestion.categoryId] = suggestion;
      }
    }

    var sortedSuggestions = uniqueSuggestions.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    // Take top 3 suggestions
    var topSuggestions = sortedSuggestions.take(3).toList();

    return FileOrganizationResult(
      fileAttachment: fileAttachment,
      primaryCategory: topSuggestions.isNotEmpty ? topSuggestions[0] : null,
      alternativeCategories: topSuggestions.length > 1
          ? topSuggestions.sublist(1)
          : [],
      allSuggestions: sortedSuggestions,
    );
  }

  /// Analyze multiple files and suggest organization
  Future<BatchOrganizationResult> analyzeFiles(
    List<FileAttachment> files,
  ) async {
    Map<String, List<FileAttachment>> categoryGroups = {};
    List<FileOrganizationResult> results = [];

    for (var file in files) {
      var result = await analyzeFile(file);
      results.add(result);

      if (result.primaryCategory != null) {
        String categoryId = result.primaryCategory!.categoryId;
        categoryGroups.putIfAbsent(categoryId, () => []).add(file);
      }
    }

    // Generate organization suggestions
    List<OrganizationSuggestion> suggestions = [];
    categoryGroups.forEach((categoryId, files) {
      if (files.length >= 2) {
        // Only suggest organization for categories with multiple files
        suggestions.add(
          OrganizationSuggestion(
            categoryId: categoryId,
            category: _categories[categoryId]!,
            fileCount: files.length,
            suggestion:
                'Create a "${_categories[categoryId]!.name}" folder with ${files.length} files',
          ),
        );
      }
    });

    suggestions.sort((a, b) => b.fileCount.compareTo(a.fileCount));

    return BatchOrganizationResult(
      results: results,
      organizationSuggestions: suggestions,
      totalFiles: files.length,
      organizedFiles: results.where((r) => r.primaryCategory != null).length,
    );
  }

  List<CategorySuggestion> _analyzeByMimeType(String mimeType) {
    List<CategorySuggestion> suggestions = [];

    _categories.forEach((categoryId, category) {
      if (category.mimeTypes.contains(mimeType)) {
        suggestions.add(
          CategorySuggestion(
            categoryId: categoryId,
            category: category,
            confidence: 0.9,
            reasoning: 'MIME type matches category',
          ),
        );
      }
    });

    return suggestions;
  }

  List<CategorySuggestion> _analyzeByExtension(String extension) {
    List<CategorySuggestion> suggestions = [];

    _categories.forEach((categoryId, category) {
      if (category.extensions.contains(extension)) {
        suggestions.add(
          CategorySuggestion(
            categoryId: categoryId,
            category: category,
            confidence: 0.8,
            reasoning: 'File extension matches category',
          ),
        );
      }
    });

    return suggestions;
  }

  List<CategorySuggestion> _analyzeByFileName(String fileName) {
    List<CategorySuggestion> suggestions = [];

    _categories.forEach((categoryId, category) {
      double confidence = 0.0;
      List<String> matches = [];

      for (var keyword in category.keywords) {
        if (fileName.contains(keyword)) {
          confidence += 0.3;
          matches.add(keyword);
        }
      }

      // Check for common patterns
      if (categoryId == 'invoices' && _containsInvoicePatterns(fileName)) {
        confidence += 0.5;
        matches.add('invoice pattern');
      }

      if (categoryId == 'certificates' &&
          _containsCertificatePatterns(fileName)) {
        confidence += 0.5;
        matches.add('certificate pattern');
      }

      if (confidence > 0.2) {
        suggestions.add(
          CategorySuggestion(
            categoryId: categoryId,
            category: category,
            confidence: confidence.clamp(0.0, 1.0),
            reasoning: 'Filename contains: ${matches.join(", ")}',
          ),
        );
      }
    });

    return suggestions;
  }

  List<CategorySuggestion> _analyzeByFileSize(int fileSizeBytes) {
    List<CategorySuggestion> suggestions = [];

    // Large files are likely videos or archives
    if (fileSizeBytes > 50 * 1024 * 1024) {
      // > 50MB
      if (_categories.containsKey('videos')) {
        suggestions.add(
          CategorySuggestion(
            categoryId: 'videos',
            category: _categories['videos']!,
            confidence: 0.6,
            reasoning: 'Large file size suggests video content',
          ),
        );
      }
    }

    // Very small files are likely documents or text
    if (fileSizeBytes < 10 * 1024) {
      // < 10KB
      if (_categories.containsKey('documents')) {
        suggestions.add(
          CategorySuggestion(
            categoryId: 'documents',
            category: _categories['documents']!,
            confidence: 0.4,
            reasoning: 'Small file size suggests document or text content',
          ),
        );
      }
    }

    return suggestions;
  }

  bool _containsInvoicePatterns(String fileName) {
    var patterns = [
      'inv',
      'invoice',
      'bill',
      'receipt',
      'payment',
      'statement',
    ];
    return patterns.any((pattern) => fileName.contains(pattern));
  }

  bool _containsCertificatePatterns(String fileName) {
    var patterns = [
      'cert',
      'certificate',
      'diploma',
      'license',
      'award',
      'degree',
    ];
    return patterns.any((pattern) => fileName.contains(pattern));
  }

  /// Get all available categories
  static Map<String, FileCategory> getAllCategories() {
    return Map.from(_categories);
  }

  /// Get category by ID
  static FileCategory? getCategory(String categoryId) {
    return _categories[categoryId];
  }

  /// Search categories by name
  static List<FileCategory> searchCategories(String query) {
    query = query.toLowerCase();
    return _categories.values
        .where(
          (category) =>
              category.name.toLowerCase().contains(query) ||
              category.keywords.any((keyword) => keyword.contains(query)),
        )
        .toList();
  }
}

/// File category definition
class FileCategory {
  final String name;
  final String icon;
  final List<String> keywords;
  final List<String> mimeTypes;
  final List<String> extensions;

  const FileCategory({
    required this.name,
    required this.icon,
    required this.keywords,
    required this.mimeTypes,
    required this.extensions,
  });

  @override
  String toString() => '$icon $name';
}

/// Category suggestion for a file
class CategorySuggestion {
  final String categoryId;
  final FileCategory category;
  final double confidence; // 0.0 to 1.0
  final String reasoning;

  CategorySuggestion({
    required this.categoryId,
    required this.category,
    required this.confidence,
    required this.reasoning,
  });

  @override
  String toString() =>
      '${category.name} (${(confidence * 100).round()}% confidence)';
}

/// Result of analyzing a single file
class FileOrganizationResult {
  final FileAttachment fileAttachment;
  final CategorySuggestion? primaryCategory;
  final List<CategorySuggestion> alternativeCategories;
  final List<CategorySuggestion> allSuggestions;

  FileOrganizationResult({
    required this.fileAttachment,
    this.primaryCategory,
    this.alternativeCategories = const [],
    this.allSuggestions = const [],
  });

  bool get hasSuggestions => primaryCategory != null;
  bool get isWellCategorized =>
      primaryCategory != null && primaryCategory!.confidence > 0.7;

  @override
  String toString() {
    if (primaryCategory == null) {
      return 'No category suggestion for ${fileAttachment.originalFileName}';
    }
    return '${fileAttachment.originalFileName} → ${primaryCategory!.category.name} (${(primaryCategory!.confidence * 100).round()}%)';
  }
}

/// Organization suggestion for batch processing
class OrganizationSuggestion {
  final String categoryId;
  final FileCategory category;
  final int fileCount;
  final String suggestion;

  OrganizationSuggestion({
    required this.categoryId,
    required this.category,
    required this.fileCount,
    required this.suggestion,
  });

  @override
  String toString() => suggestion;
}

/// Result of analyzing multiple files
class BatchOrganizationResult {
  final List<FileOrganizationResult> results;
  final List<OrganizationSuggestion> organizationSuggestions;
  final int totalFiles;
  final int organizedFiles;

  BatchOrganizationResult({
    required this.results,
    required this.organizationSuggestions,
    required this.totalFiles,
    required this.organizedFiles,
  });

  double get organizationRate =>
      totalFiles > 0 ? organizedFiles / totalFiles : 0.0;

  Map<String, int> get categoryDistribution {
    Map<String, int> distribution = {};
    for (var result in results) {
      if (result.primaryCategory != null) {
        String categoryName = result.primaryCategory!.category.name;
        distribution[categoryName] = (distribution[categoryName] ?? 0) + 1;
      }
    }
    return distribution;
  }

  @override
  String toString() {
    return 'Organized $organizedFiles/$totalFiles files (${(organizationRate * 100).round()}%)\n'
        'Suggestions: ${organizationSuggestions.length}\n'
        'Categories: ${categoryDistribution.keys.join(", ")}';
  }
}
