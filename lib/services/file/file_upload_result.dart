class FileUploadResult {
  final bool isSuccess;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? fileId;
  final String? error;
  final Exception? exception;

  FileUploadResult._({
    required this.isSuccess,
    this.downloadUrl,
    this.thumbnailUrl,
    this.fileId,
    this.error,
    this.exception,
  });

  factory FileUploadResult.success({
    required String downloadUrl,
    required String fileId,
    String? thumbnailUrl,
  }) {
    return FileUploadResult._(
      isSuccess: true,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      fileId: fileId,
    );
  }

  factory FileUploadResult.error(String error, [Exception? exception]) {
    return FileUploadResult._(
      isSuccess: false,
      error: error,
      exception: exception,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'FileUploadResult.success(fileId: $fileId, downloadUrl: $downloadUrl)';
    } else {
      return 'FileUploadResult.error(error: $error)';
    }
  }
}

class FileDownloadResult {
  final bool isSuccess;
  final String? localPath;
  final String? error;
  final Exception? exception;

  FileDownloadResult._({
    required this.isSuccess,
    this.localPath,
    this.error,
    this.exception,
  });

  factory FileDownloadResult.success(String localPath) {
    return FileDownloadResult._(isSuccess: true, localPath: localPath);
  }

  factory FileDownloadResult.error(String error, [Exception? exception]) {
    return FileDownloadResult._(
      isSuccess: false,
      error: error,
      exception: exception,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'FileDownloadResult.success(localPath: $localPath)';
    } else {
      return 'FileDownloadResult.error(error: $error)';
    }
  }
}
