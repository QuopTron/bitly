/// Modelos de datos para el servicio FFmpeg.
///
/// Contiene las clases de modelo usadas por [FFmpegService] y sus
/// sub-servicios: descriptores de descifrado, resultados de conversión,
/// metadatos de audio e información de streaming.
library ffmpeg_models;

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';

enum LiveDecryptFormat { flac, m4a }

class DownloadDecryptionDescriptor {
  final String strategy;
  final String key;
  final String? iv;
  final String? inputFormat;
  final String? outputExtension;
  final Map<String, dynamic> options;

  const DownloadDecryptionDescriptor({
    required this.strategy,
    required this.key,
    this.iv,
    this.inputFormat,
    this.outputExtension,
    this.options = const {},
  });

  factory DownloadDecryptionDescriptor.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return DownloadDecryptionDescriptor(
      strategy: (json['strategy'] as String? ?? '').trim(),
      key: (json['key'] as String? ?? '').trim(),
      iv: (json['iv'] as String?)?.trim(),
      inputFormat: (json['input_format'] as String?)?.trim(),
      outputExtension: (json['output_extension'] as String?)?.trim(),
      options: rawOptions is Map ? Map<String, dynamic>.from(rawOptions) : const {},
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'strategy': strategy, 'key': key};
    if (iv != null) json['iv'] = iv;
    if (inputFormat != null) json['input_format'] = inputFormat;
    if (outputExtension != null) json['output_extension'] = outputExtension;
    if (options.isNotEmpty) json['options'] = Map<String, dynamic>.from(options);
    return json;
  }

  factory DownloadDecryptionDescriptor.fromDownloadResult(Map<String, dynamic> result) {
    final strategy = (result['decryption_strategy'] as String? ?? '').trim();
    if (strategy.isEmpty) return DownloadDecryptionDescriptor(strategy: '', key: '');
    return DownloadDecryptionDescriptor(
      strategy: strategy,
      key: (result['decryption_key'] as String? ?? result['key_id'] as String? ?? '').trim(),
      iv: (result['decryption_iv'] as String?)?.trim(),
      inputFormat: (result['input_format'] as String?)?.trim(),
      outputExtension: (result['output_extension'] as String?)?.trim(),
      options: result['decryption_options'] is Map ? Map<String, dynamic>.from(result['decryption_options']) : const {},
    );
  }

  String get normalizedStrategy {
    final s = strategy.trim().toLowerCase();
    switch (s) {
      case 'ffmpeg': case 'ffmpeg_mov_key': case 'custom_ffmpeg': case 'mov_key':
        return 'ffmpeg.mov_key';
      default:
        return strategy.trim();
    }
  }
}

class CueSplitTrackInfo {
  final int number;
  final String title;
  final String artist;
  final String isrc;
  final String composer;
  final double startSec;
  final double endSec;

  CueSplitTrackInfo({
    required this.number,
    required this.title,
    required this.artist,
    this.isrc = '',
    this.composer = '',
    required this.startSec,
    required this.endSec,
  });

  factory CueSplitTrackInfo.fromJson(Map<String, dynamic> json) {
    return CueSplitTrackInfo(
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      isrc: json['isrc'] as String? ?? '',
      composer: json['composer'] as String? ?? '',
      startSec: (json['start_sec'] as num?)?.toDouble() ?? 0.0,
      endSec: (json['end_sec'] as num?)?.toDouble() ?? -1.0,
    );
  }
}

class FFmpegResult {
  final bool success;
  final int returnCode;
  final String output;

  FFmpegResult({required this.success, required this.returnCode, required this.output});
}

class LiveDecryptedStreamResult {
  final String localUrl;
  final String format;
  final FFmpegSession session;

  LiveDecryptedStreamResult({required this.localUrl, required this.format, required this.session});
}

class ReplayGainResult {
  final String trackGain;
  final String trackPeak;
  final double integratedLufs;
  final double truePeakLinear;

  const ReplayGainResult({
    required this.trackGain,
    required this.trackPeak,
    required this.integratedLufs,
    required this.truePeakLinear,
  });

  @override
  String toString() => 'ReplayGainResult(trackGain: $trackGain, trackPeak: $trackPeak)';
}

class AudioMetadata {
  final String codec;
  final int bitDepth;
  final int sampleRate;
  final int channels;
  final int bitrate;

  const AudioMetadata({
    required this.codec,
    required this.bitDepth,
    required this.sampleRate,
    required this.channels,
    required this.bitrate,
  });
}

class AudioMetadataResult {
  final bool success;
  final AudioMetadata? metadata;
  final String? error;

  const AudioMetadataResult({required this.success, this.metadata, this.error});
}
