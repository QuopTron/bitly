class ScanProgress {
  final int totalFiles;
  final int scannedFiles;
  final String currentFile;
  final bool isScanning;
  final double percentage;

  ScanProgress({
    required this.totalFiles,
    required this.scannedFiles,
    required this.currentFile,
    required this.isScanning,
    required this.percentage,
  });
}
