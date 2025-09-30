import 'package:flutter/material.dart';

class FileStatusMonitor extends StatelessWidget {
  final String status;
  final double progress;
  final bool isError;
  final VoidCallback? onRetry;

  const FileStatusMonitor({
    Key? key,
    required this.status,
    this.progress = 0.0,
    this.isError = false,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: isError ? Colors.red : Colors.blue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: isError ? Colors.red.shade700 : Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isError && onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (progress > 0 && !isError) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.blue.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}