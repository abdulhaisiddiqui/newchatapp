class ValidationResult {
  final bool isValid;
  final String? error;
  final List<String> warnings;
  final Map<String, dynamic>? metadata;

  ValidationResult._({
    required this.isValid,
    this.error,
    this.warnings = const [],
    this.metadata,
  });

  factory ValidationResult.success({
    List<String> warnings = const [],
    Map<String, dynamic>? metadata,
  }) {
    return ValidationResult._(
      isValid: true,
      warnings: warnings,
      metadata: metadata,
    );
  }

  factory ValidationResult.error(
    String error, {
    List<String> warnings = const [],
  }) {
    return ValidationResult._(isValid: false, error: error, warnings: warnings);
  }

  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult.success(warnings: ${warnings.length})';
    } else {
      return 'ValidationResult.error(error: $error, warnings: ${warnings.length})';
    }
  }
}
