import 'dart:io';

class DatabaseBackup {
  final String filename;
  final DateTime timestamp;
  final int schemaVersion;
  final String reason;
  final int fileSizeBytes;
  final String checksum;
  final File file;
  final File metadataFile;
  final bool isValid;

  DatabaseBackup({
    required this.filename,
    required this.timestamp,
    required this.schemaVersion,
    required this.reason,
    required this.fileSizeBytes,
    required this.checksum,
    required this.file,
    required this.metadataFile,
    this.isValid = true,
  });

  String get formattedDate => _formatDateTime(timestamp);
  String get formattedTime => _formatTime(timestamp);
  String get formattedSize => _formatFileSize(fileSizeBytes);
  String get displayName => '$formattedDate $formattedTime - $reason';

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'timestamp': timestamp.toIso8601String(),
    'schema_version': schemaVersion,
    'reason': reason,
    'file_size': fileSizeBytes,
    'checksum': checksum,
    'is_valid': isValid,
  };

  factory DatabaseBackup.fromJson(Map<String, dynamic> json) {
    return DatabaseBackup(
      filename: json['filename'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      schemaVersion: json['schema_version'] as int,
      reason: json['reason'] as String,
      fileSizeBytes: json['file_size'] as int,
      checksum: json['checksum'] as String,
      isValid: json['is_valid'] as bool? ?? true,
      file: File(''), // Será definido posteriormente
      metadataFile: File(''), // Será definido posteriormente
    );
  }
}
