class DownloadProgressModel {
  final String itemId;
  final int bytesDownloaded;
  final int totalBytes;
  final double percentage;
  final double speed;
  final int eta;

  const DownloadProgressModel({
    required this.itemId,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.percentage = 0,
    this.speed = 0,
    this.eta = 0,
  });

  factory DownloadProgressModel.fromJson(Map<String, dynamic> json) =>
      DownloadProgressModel(
        itemId: json['item_id'] as String,
        bytesDownloaded: json['bytes_downloaded'] as int? ?? 0,
        totalBytes: json['total_bytes'] as int? ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0,
        eta: json['eta'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'bytes_downloaded': bytesDownloaded,
        'total_bytes': totalBytes,
        'percentage': percentage,
        'speed': speed,
        'eta': eta,
      };
}
