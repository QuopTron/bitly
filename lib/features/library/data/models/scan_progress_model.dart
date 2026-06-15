class ScanProgressModel {
  final int totalFiles;
  final int scannedFiles;
  final String currentFile;
  final bool isScanning;
  final double percentage;

  ScanProgressModel({
    required this.totalFiles,
    required this.scannedFiles,
    required this.currentFile,
    required this.isScanning,
    required this.percentage,
  });

  factory ScanProgressModel.fromJson(Map<String, dynamic> json) {
    return ScanProgressModel(
      totalFiles: json['total_files'] as int,
      scannedFiles: json['scanned_files'] as int,
      currentFile: json['current_file'] as String? ?? '',
      isScanning: json['is_scanning'] as bool,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_files': totalFiles,
      'scanned_files': scannedFiles,
      'current_file': currentFile,
      'is_scanning': isScanning,
      'percentage': percentage,
    };
  }
}
