/// Servicio de procesamiento de audio con FFmpeg.
///
/// Proporciona métodos estáticos para conversión de formatos, descifrado,
/// streaming en vivo DASH, ReplayGain, incrustación de metadatos, división
/// de CUE y obtención de metadatos de audio.
///
/// Los modelos de datos están en [ffmpeg_models].
library servicio_ffmpeg;

export 'package:bitly/services/downloads/ffmpeg_models.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/session_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/services/downloads/ffmpeg_models.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/artist_utils.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('FFmpeg');

class FFmpegService {
  static const Duration _liveTunnelStartupTimeout = Duration(seconds: 8);
  static const Duration _liveTunnelStartupPollInterval = Duration(milliseconds: 200);
  static const Duration _liveTunnelStabilizationDelay = Duration(milliseconds: 900);
  static const String _genericMovKeyDecryptionStrategy = 'ffmpeg.mov_key';
  static int _tempEmbedCounter = 0;
  static FFmpegSession? _activeLiveDecryptSession;
  static String? _activeLiveDecryptUrl;
  static String? _activeLiveTempInputPath;
  static String? _activeNativeDashManifestPath;
  static String? _activeNativeDashManifestUrl;
  static final Set<String> _preparedNativeDashManifestPaths = <String>{};

  static String _buildOutputPath(String inputPath, String extension) {
    final normalizedExt = extension.startsWith('.') ? extension : '.$extension';
    final inputFile = File(inputPath);
    final dir = inputFile.parent.path;
    final filename = inputFile.uri.pathSegments.last;
    final dotIndex = filename.lastIndexOf('.');
    final baseName = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
    var outputPath = '$dir${Platform.pathSeparator}$baseName$normalizedExt';
    if (outputPath == inputPath) {
      outputPath = '$dir${Platform.pathSeparator}${baseName}_converted$normalizedExt';
    }
    return outputPath;
  }

  static String _nextTempEmbedPath(String tempDirPath, String extension) {
    final normalizedExt = extension.startsWith('.') ? extension : '.$extension';
    _tempEmbedCounter = (_tempEmbedCounter + 1) & 0x7fffffff;
    return '$tempDirPath${Platform.pathSeparator}temp_embed_${DateTime.now().microsecondsSinceEpoch}_$pid$_tempEmbedCounter$normalizedExt';
  }

  static List<String> _buildDecryptionKeyCandidates(String rawKey) {
    final candidates = <String>[];
    void addCandidate(String key) {
      final normalized = key.trim();
      if (normalized.isEmpty) return;
      if (!candidates.contains(normalized)) candidates.add(normalized);
    }
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return candidates;
    addCandidate(trimmed);
    final noPrefix = trimmed.startsWith(RegExp(r'0x', caseSensitive: false)) ? trimmed.substring(2) : trimmed;
    addCandidate(noPrefix);
    final compactHex = noPrefix.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (compactHex.isNotEmpty && compactHex.length.isEven) addCandidate(compactHex);
    try {
      final b64 = noPrefix.replaceAll(RegExp(r'\s+'), '');
      final decoded = base64Decode(b64);
      if (decoded.isNotEmpty) addCandidate(decoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
    } catch (_) {}
    return candidates;
  }

  // ─── Ejecución básica ─────────────────────────────────────────

  static Future<FFmpegResult> _execute(String command) async {
    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput() ?? '';
      return FFmpegResult(success: ReturnCode.isSuccess(returnCode), returnCode: returnCode?.getValue() ?? -1, output: output);
    } catch (e) {
      _log.e('FFmpeg execute error: $e');
      return FFmpegResult(success: false, returnCode: -1, output: e.toString());
    }
  }

  static Future<FFmpegResult> _executeWithArguments(List<String> arguments) async {
    try {
      final session = await FFmpegKit.executeWithArguments(arguments);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput() ?? '';
      return FFmpegResult(success: ReturnCode.isSuccess(returnCode), returnCode: returnCode?.getValue() ?? -1, output: output);
    } catch (e) {
      _log.e('FFmpeg executeWithArguments error: $e');
      return FFmpegResult(success: false, returnCode: -1, output: e.toString());
    }
  }

  // ─── Información / disponibilidad ────────────────────────────

  static Future<bool> isAvailable() async {
    try { final version = await FFmpegKitConfig.getFFmpegVersion(); return version?.isNotEmpty ?? false; }
    catch (e) { return false; }
  }

  static Future<String?> getVersion() async {
    try { return await FFmpegKitConfig.getFFmpegVersion(); }
    catch (e) { return null; }
  }

  static bool isActiveLiveDecryptedUrl(String url) {
    final active = _activeLiveDecryptUrl;
    if (active == null || active.isEmpty) return false;
    return active == url.trim();
  }

  static bool isActiveNativeDashManifestUrl(String url) {
    final activeUrl = _activeNativeDashManifestUrl;
    if (activeUrl == null || activeUrl.isEmpty) return false;
    final normalized = url.trim();
    if (activeUrl == normalized) return true;
    try { return Uri.parse(activeUrl).toFilePath() == Uri.parse(normalized).toFilePath(); }
    catch (_) { return false; }
  }

  // ─── Conversión M4A ──────────────────────────────────────────

  static Future<String?> convertM4aToFlac(String inputPath) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      try { final r = await PlatformBridge.convertAudioFile(inputPath); return r; } catch (_) { return null; }
    }
    final outputPath = _buildOutputPath(inputPath, '.flac');
    final cmd = '-v error -xerror -i "$inputPath" -c:a flac -compression_level 8 "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) {
      try { await File(inputPath).delete(); } catch (_) {}
      return outputPath;
    }
    _log.e('M4A to FLAC conversion failed: ${result.output}'); return null;
  }

  static Future<String?> convertM4aToLossy(String inputPath, {required String format, String? bitrate, bool deleteOriginal = true}) async {
    String bitrateValue = format == 'opus' ? '128k' : '320k';
    if (bitrate != null && bitrate.contains('_')) {
      final parts = bitrate.split('_');
      if (parts.length == 2) bitrateValue = '${parts[1]}k';
    }
    final ext = format == 'opus' ? '.opus' : '.mp3';
    final outputPath = _buildOutputPath(inputPath, ext);
    final cmd = format == 'opus'
        ? '-v error -hide_banner -i "$inputPath" -codec:a libopus -b:a $bitrateValue -vbr on -compression_level 10 -map 0:a "$outputPath" -y'
        : '-v error -hide_banner -i "$inputPath" -codec:a libmp3lame -b:a $bitrateValue -map 0:a -id3v2_version 3 "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) {
      if (deleteOriginal) { try { await File(inputPath).delete(); } catch (_) {} }
      return outputPath;
    }
    _log.e('M4A to $format conversion failed: ${result.output}'); return null;
  }

  // ─── Descifrado ──────────────────────────────────────────────

  static Future<String?> decryptAudioFile({required String inputPath, required String decryptionKey, bool deleteOriginal = true}) async {
    return decryptWithDescriptor(
      inputPath: inputPath,
      descriptor: DownloadDecryptionDescriptor(strategy: _genericMovKeyDecryptionStrategy, key: decryptionKey, inputFormat: 'mov'),
      deleteOriginal: deleteOriginal,
    );
  }

  static Future<String?> decryptWithDescriptor({required String inputPath, required DownloadDecryptionDescriptor descriptor, bool deleteOriginal = true}) async {
    final key = descriptor.key.trim();
    switch (descriptor.normalizedStrategy) {
      case _genericMovKeyDecryptionStrategy:
        if (key.isEmpty) return inputPath;
        return _decryptMovKeyFile(inputPath: inputPath, decryptionKey: key, inputFormat: descriptor.inputFormat, outputExtension: descriptor.outputExtension, deleteOriginal: deleteOriginal);
      default:
        _log.e('Unknown decryption strategy: ${descriptor.strategy}'); return null;
    }
  }

  static Future<String?> _decryptMovKeyFile({required String inputPath, required String decryptionKey, String? inputFormat, String? outputExtension, bool deleteOriginal = true}) async {
    final ext = outputExtension ?? (inputFormat ?? 'm4a');
    final outputPath = _buildOutputPath(inputPath, '.$ext');
    final cmd = '-v error -xerror -decryption_key $decryptionKey -i "$inputPath" -c copy "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) {
      if (deleteOriginal) { try { await File(inputPath).delete(); } catch (_) {} }
      return outputPath;
    }
    _log.e('MOV decryption failed: ${result.output}'); return null;
  }

  // ─── Conversión FLAC → MP3/Opus/M4a ─────────────────────────

  static Future<String?> convertFlacToMp3(String inputPath, {String bitrate = '320k', bool deleteOriginal = true}) async {
    final outputPath = _buildOutputPath(inputPath, '.mp3');
    final cmd = '-v error -hide_banner -i "$inputPath" -codec:a libmp3lame -b:a $bitrate -map 0:a -map_metadata 0 -id3v2_version 3 "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) { if (deleteOriginal) { try { await File(inputPath).delete(); } catch (_) {} } return outputPath; }
    _log.e('FLAC to MP3 conversion failed: ${result.output}'); return null;
  }

  static Future<String?> convertFlacToOpus(String inputPath, {String bitrate = '128k', bool deleteOriginal = true}) async {
    final outputPath = _buildOutputPath(inputPath, '.opus');
    final cmd = '-v error -hide_banner -i "$inputPath" -codec:a libopus -b:a $bitrate -vbr on -compression_level 10 -map 0:a -map_metadata 0 "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) { if (deleteOriginal) { try { await File(inputPath).delete(); } catch (_) {} } return outputPath; }
    _log.e('FLAC to Opus conversion failed: ${result.output}'); return null;
  }

  static Future<String?> convertFlacToLossy(String inputPath, {required String format, String? bitrate, bool deleteOriginal = true}) async {
    String bitrateValue = '320k';
    if (bitrate != null && bitrate.contains('_')) { final p = bitrate.split('_'); if (p.length == 2) bitrateValue = '${p[1]}k'; }
    switch (format.toLowerCase()) {
      case 'opus': return convertFlacToOpus(inputPath, bitrate: '128k', deleteOriginal: deleteOriginal);
      default: return convertFlacToMp3(inputPath, bitrate: bitrateValue, deleteOriginal: deleteOriginal);
    }
  }

  static Future<String?> convertFlacToM4a(String inputPath, {String codec = 'aac', String bitrate = '256k'}) async {
    final dir = File(inputPath).parent.path;
    final baseName = inputPath.split(Platform.pathSeparator).last.replaceAll('.flac', '');
    final outputDir = '$dir${Platform.pathSeparator}M4A';
    await Directory(outputDir).create(recursive: true);
    final outputPath = '$outputDir${Platform.pathSeparator}$baseName.m4a';
    final cmd = codec == 'alac'
        ? '-v error -hide_banner -i "$inputPath" -codec:a alac -map 0:a -map_metadata 0 "$outputPath" -y'
        : '-v error -hide_banner -i "$inputPath" -codec:a aac -b:a $bitrate -map 0:a -map_metadata 0 "$outputPath" -y';
    final result = await _execute(cmd);
    if (result.success) return outputPath;
    _log.e('FLAC to M4A conversion failed: ${result.output}'); return null;
  }

  // ─── Streaming DASH nativo ───────────────────────────────────

  static Future<String?> prepareTidalDashManifestForNativePlayback({required String manifestPayload, bool registerAsActive = true}) async {
    final raw = manifestPayload.trim();
    if (raw.isEmpty) return null;
    final payload = raw.startsWith('MANIFEST:') ? raw.substring('MANIFEST:'.length) : raw;
    final manifestPath = await _writeTempManifestFile(payload);
    if (manifestPath == null) { _log.e('Failed to prepare Tidal DASH manifest'); return null; }
    _preparedNativeDashManifestPaths.add(manifestPath);
    if (registerAsActive) await activatePreparedNativeDashManifest(Uri.file(manifestPath).toString());
    return Uri.file(manifestPath).toString();
  }

  static Future<void> activatePreparedNativeDashManifest(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final manifestPath = _nativeDashManifestPathFromUrl(normalized);
    if (manifestPath == null || !_preparedNativeDashManifestPaths.contains(manifestPath)) return;
    final prev = _activeNativeDashManifestPath;
    _activeNativeDashManifestPath = manifestPath;
    _activeNativeDashManifestUrl = Uri.file(manifestPath).toString();
    if (prev != null && prev.isNotEmpty && prev != manifestPath) {
      _preparedNativeDashManifestPaths.remove(prev);
      await _deleteNativeDashManifestFile(prev);
    }
  }

  static Future<void> stopNativeDashManifestPlayback() async {
    final path = _activeNativeDashManifestPath;
    _activeNativeDashManifestPath = null;
    _activeNativeDashManifestUrl = null;
    if (path == null || path.isEmpty) return;
    _preparedNativeDashManifestPaths.remove(path);
    await _deleteNativeDashManifestFile(path);
  }

  static Future<void> cleanupInactivePreparedNativeDashManifests() async {
    final active = _activeNativeDashManifestPath;
    for (final path in _preparedNativeDashManifestPaths.where((p) => p != active).toList(growable: false)) {
      _preparedNativeDashManifestPaths.remove(path);
      await _deleteNativeDashManifestFile(path);
    }
  }

  static String? _nativeDashManifestPathFromUrl(String url) {
    try { final uri = Uri.parse(url); if (uri.scheme.toLowerCase() != 'file') return null; final p = uri.toFilePath(); return p.trim().isEmpty ? null : p; }
    catch (_) { return null; }
  }

  static Future<void> _deleteNativeDashManifestFile(String path) async {
    try { final f = File(path); if (await f.exists()) await f.delete(); } catch (_) {}
  }

  static Future<void> stopLiveDecryptedStream() async {
    final session = _activeLiveDecryptSession;
    final tempPath = _activeLiveTempInputPath;
    _activeLiveDecryptSession = null;
    _activeLiveDecryptUrl = null;
    _activeLiveTempInputPath = null;
    if (session != null) {
      try { await session.cancel(); } catch (e) {
        final sid = session.getSessionId();
        if (sid != null) { try { await FFmpegKit.cancel(sid); } catch (_) {} }
        _log.w('Failed to stop live decrypt session: $e');
      }
    }
    if (tempPath != null && tempPath.isNotEmpty) { try { final f = File(tempPath); if (await f.exists()) await f.delete(); } catch (_) {} }
  }

  static Future<LiveDecryptedStreamResult?> startTidalDashLiveStream({required String manifestPayload, String preferredFormat = 'm4a'}) async {
    final raw = manifestPayload.trim();
    if (raw.isEmpty) return null;
    final payload = raw.startsWith('MANIFEST:') ? raw.substring('MANIFEST:'.length) : raw;
    final manifestPath = await _writeTempManifestFile(payload);
    if (manifestPath == null) { _log.e('Failed to prepare DASH manifest for live stream'); return null; }
    await stopLiveDecryptedStream();
    await stopNativeDashManifestPlayback();
    for (final fmt in _buildLiveDashFormatAttempts(preferredFormat)) {
      final stream = await _tryStartLiveDashAttempt(manifestPath: manifestPath, format: fmt);
      if (stream != null) {
        _activeLiveDecryptSession = stream.session;
        _activeLiveDecryptUrl = stream.localUrl;
        _activeLiveTempInputPath = manifestPath;
        return stream;
      }
    }
    try { final f = File(manifestPath); if (await f.exists()) await f.delete(); } catch (_) {}
    return null;
  }

  static Future<String?> _writeTempManifestFile(String payload) async {
    if (payload.trim().isEmpty) return null;
    Uint8List bytes;
    try { bytes = base64Decode(payload); } catch (_) { bytes = Uint8List.fromList(utf8.encode(payload)); }
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    final tmpDir = await getTemporaryDirectory();
    final p = '${tmpDir.path}${Platform.pathSeparator}tidal_dash_${DateTime.now().microsecondsSinceEpoch}.mpd';
    await File(p).writeAsString(text, flush: true);
    return p;
  }

  static List<LiveDecryptFormat> _buildLiveDashFormatAttempts(String preferredFormat) {
    final n = preferredFormat.trim().toLowerCase();
    return n == 'flac' ? const [LiveDecryptFormat.flac, LiveDecryptFormat.m4a] : const [LiveDecryptFormat.m4a, LiveDecryptFormat.flac];
  }

  static Future<bool> _awaitLiveTunnelReady(FFmpegSession session) async {
    final deadline = DateTime.now().add(_liveTunnelStartupTimeout);
    var seenRunning = false;
    while (DateTime.now().isBefore(deadline)) {
      final state = await session.getState();
      if (state == SessionState.running) { seenRunning = true; break; }
      if (state != SessionState.created) return false;
      await Future<void>.delayed(_liveTunnelStartupPollInterval);
    }
    if (!seenRunning) return false;
    await Future<void>.delayed(_liveTunnelStabilizationDelay);
    return (await session.getState()) == SessionState.running;
  }

  static Future<LiveDecryptedStreamResult?> _tryStartLiveDashAttempt({required String manifestPath, required LiveDecryptFormat format}) async {
    final port = await _allocateLoopbackPort();
    final ext = format == LiveDecryptFormat.flac ? 'flac' : 'm4a';
    final mime = format == LiveDecryptFormat.flac ? 'audio/flac' : 'audio/mp4';
    final localUrl = 'http://localhost:$port/stream.$ext';
    final args = <String>[
      '-nostdin', '-hide_banner', '-loglevel', 'error',
      '-protocol_whitelist', 'file,http,https,tcp,tls,crypto,data',
      '-i', manifestPath, '-map', '0:a:0', '-c:a', 'copy',
      if (format == LiveDecryptFormat.flac) ...['-f', 'flac'],
      if (format == LiveDecryptFormat.m4a) ...['-movflags', '+frag_keyframe+empty_moov+default_base_moof', '-f', 'mp4'],
      '-content_type', mime, '-listen', '1', localUrl,
    ];
    final session = await FFmpegKit.executeWithArgumentsAsync(args);
    if (await _awaitLiveTunnelReady(session)) return LiveDecryptedStreamResult(localUrl: localUrl, format: ext, session: session);
    try { await session.cancel(); } catch (_) {}
    return null;
  }

  static Future<LiveDecryptedStreamResult?> startEncryptedLiveDecryptedStream({required String encryptedStreamUrl, required String decryptionKey, String preferredFormat = 'flac'}) async {
    final inputUrl = encryptedStreamUrl.trim();
    if (inputUrl.isEmpty) return null;
    final keyCandidates = _buildDecryptionKeyCandidates(decryptionKey);
    if (keyCandidates.isEmpty) { _log.e('No usable decryption key candidates'); return null; }
    await stopLiveDecryptedStream();
    for (final fmt in _buildLiveDecryptFormatAttempts(preferredFormat)) {
      for (final kc in keyCandidates) {
        final stream = await _tryStartLiveDecryptAttempt(inputUrl: inputUrl, decryptionKey: kc, format: fmt);
        if (stream != null) {
          _activeLiveDecryptSession = stream.session;
          _activeLiveDecryptUrl = stream.localUrl;
          _activeLiveTempInputPath = null;
          return stream;
        }
      }
    }
    return null;
  }

  static List<LiveDecryptFormat> _buildLiveDecryptFormatAttempts(String preferredFormat) {
    final n = preferredFormat.trim().toLowerCase();
    return (n == 'm4a' || n == 'mp4' || n == 'aac') ? const [LiveDecryptFormat.m4a, LiveDecryptFormat.flac] : const [LiveDecryptFormat.flac, LiveDecryptFormat.m4a];
  }

  static Future<LiveDecryptedStreamResult?> _tryStartLiveDecryptAttempt({required String inputUrl, required String decryptionKey, required LiveDecryptFormat format}) async {
    final port = await _allocateLoopbackPort();
    final ext = format == LiveDecryptFormat.flac ? 'flac' : 'm4a';
    final mime = format == LiveDecryptFormat.flac ? 'audio/flac' : 'audio/mp4';
    final localUrl = 'http://localhost:$port/stream.$ext';
    final args = <String>[
      '-nostdin', '-hide_banner', '-loglevel', 'error',
      '-decryption_key', decryptionKey, '-i', inputUrl,
      '-map', '0:a:0', '-c:a', 'copy',
      if (format == LiveDecryptFormat.flac) ...['-f', 'flac'],
      if (format == LiveDecryptFormat.m4a) ...['-movflags', '+frag_keyframe+empty_moov+default_base_moof', '-f', 'mp4'],
      '-content_type', mime, '-listen', '1', localUrl,
    ];
    final session = await FFmpegKit.executeWithArgumentsAsync(args);
    if (await _awaitLiveTunnelReady(session)) return LiveDecryptedStreamResult(localUrl: localUrl, format: ext, session: session);
    try { await session.cancel(); } catch (_) {}
    return null;
  }

  static Future<int> _allocateLoopbackPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  // ─── ReplayGain ──────────────────────────────────────────────

  static Future<ReplayGainResult?> scanReplayGain(String filePath) async {
    final cmd = '-hide_banner -nostats -i "$filePath" -filter_complex ebur128=peak=true:framelog=quiet -f null -';
    final result = await _execute(cmd);
    final output = result.output;
    final im = RegExp(r'I:\s+(-?\d+\.?\d*)\s+LUFS').allMatches(output);
    if (im.isEmpty) { _log.w('ReplayGain: could not parse integrated loudness'); return null; }
    final integratedLufs = double.tryParse(im.last.group(1) ?? '');
    if (integratedLufs == null) { _log.w('ReplayGain: invalid integrated loudness'); return null; }
    double? peakDbfs;
    for (final m in RegExp(r'Peak:\s+(-?\d+\.?\d*)\s+dBFS').allMatches(output)) {
      final v = double.tryParse(m.group(1) ?? '');
      if (v != null && (peakDbfs == null || v > peakDbfs)) peakDbfs = v;
    }
    const ref = -18.0;
    final gainDb = ref - integratedLufs;
    final peakLinear = peakDbfs != null ? math.pow(10, peakDbfs / 20.0).toDouble() : 1.0;
    final trackGain = '${gainDb >= 0 ? "+" : ""}${gainDb.toStringAsFixed(2)} dB';
    return ReplayGainResult(trackGain: trackGain, trackPeak: peakLinear.toStringAsFixed(6), integratedLufs: integratedLufs, truePeakLinear: peakLinear);
  }

  static Future<bool> writeAlbumReplayGainTags(String filePath, String albumGain, String albumPeak, {bool returnTempPath = false, void Function(String tempPath)? onTempReady}) async {
    final ext = filePath.contains('.') ? '.${filePath.split('.').last}' : '.tmp';
    final tmpDir = await getTemporaryDirectory();
    final tmpOut = _nextTempEmbedPath(tmpDir.path, ext);
    final args = <String>['-v', 'error', '-hide_banner', '-i', filePath, '-map', '0', '-c', 'copy', '-map_metadata', '0', '-metadata', 'REPLAYGAIN_ALBUM_GAIN=$albumGain', '-metadata', 'REPLAYGAIN_ALBUM_PEAK=$albumPeak', tmpOut, '-y'];
    final result = await _executeWithArguments(args);
    if (result.success) {
      try {
        final tf = File(tmpOut);
        if (await tf.exists()) {
          if (returnTempPath) { onTempReady?.call(tmpOut); return true; }
          final of = File(filePath);
          if (await of.exists()) await of.delete();
          await tf.copy(filePath); await tf.delete(); return true;
        }
      } catch (e) { _log.w('Failed to replace file with ReplayGain: $e'); }
    }
    try { final tf = File(tmpOut); if (await tf.exists()) await tf.delete(); } catch (_) {}
    return false;
  }

  // ─── Incrustación de metadatos ───────────────────────────────

  static Future<String?> embedMetadata({required String flacPath, String? coverPath, Map<String, String>? metadata, String artistTagMode = 'joined'}) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpOut = _nextTempEmbedPath(tmpDir.path, '.flac');
    final args = <String>['-v', 'error', '-hide_banner', '-i', flacPath];
    if (coverPath != null) { args..add('-i')..add(coverPath); }
    args..add('-map')..add('0:a');
    if (coverPath != null) {
      args..add('-map')..add('1:0')..add('-c:v')..add('copy')..add('-disposition:v')..add('attached_pic')
        ..add('-metadata:s:v')..add('title=Album cover')..add('-metadata:s:v')..add('comment=Cover (front)');
    }
    args..add('-c:a')..add('copy');
    if (metadata != null) _appendVorbisMetadataToArguments(args, metadata, artistTagMode: artistTagMode);
    args..add(tmpOut)..add('-y');
    final result = await _executeWithArguments(args);
    if (result.success) {
      try {
        final tf = File(tmpOut); final of = File(flacPath);
        if (await tf.exists()) { if (await of.exists()) await of.delete(); await tf.copy(flacPath); await tf.delete(); return flacPath; }
      } catch (e) { _log.e('Failed to replace after embed: $e'); return null; }
    }
    try { final tf = File(tmpOut); if (await tf.exists()) await tf.delete(); } catch (e) { _log.w('Cleanup error: $e'); }
    _log.e('FLAC embed failed: ${result.output}'); return null;
  }

  static Future<String?> embedMetadataToMp3({required String mp3Path, String? coverPath, Map<String, String>? metadata, bool preserveMetadata = false}) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpOut = _nextTempEmbedPath(tmpDir.path, '.mp3');
    var result = await _runMp3Embed(mp3Path: mp3Path, tempOutput: tmpOut, coverPath: coverPath, metadata: metadata, preserveMetadata: preserveMetadata, audioCodec: 'copy');
    if (result.success) return await _finalizeMp3Embed(mp3Path, tmpOut);
    if (result.output.contains('Invalid audio stream') || result.output.contains('incorrect codec parameters')) {
      try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (_) {}
      final reOut = _nextTempEmbedPath(tmpDir.path, '.mp3');
      result = await _runMp3Embed(mp3Path: mp3Path, tempOutput: reOut, coverPath: coverPath, metadata: metadata, preserveMetadata: preserveMetadata, audioCodec: 'libmp3lame', audioBitrate: '192k');
      if (result.success) return await _finalizeMp3Embed(mp3Path, reOut);
      try { final f = File(reOut); if (await f.exists()) await f.delete(); } catch (_) {}
      _log.e('MP3 re-encode failed: ${result.output}'); return null;
    }
    try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (e) { _log.w('Cleanup MP3: $e'); }
    _log.e('MP3 embed failed: ${result.output}'); return null;
  }

  static Future<FFmpegResult> _runMp3Embed({required String mp3Path, required String tempOutput, String? coverPath, Map<String, String>? metadata, bool preserveMetadata = false, required String audioCodec, String? audioBitrate}) async {
    final args = <String>['-v', 'error', '-hide_banner', '-i', mp3Path];
    if (coverPath != null) { args..add('-i')..add(coverPath); }
    args..add('-map')..add('0:a')..add('-map_metadata')..add(preserveMetadata ? '0' : '-1');
    if (coverPath != null) { args..add('-map')..add('1:0')..add('-c:v:0')..add('copy')..add('-id3v2_version')..add('3')..add('-metadata:s:v')..add('title=Album cover')..add('-metadata:s:v')..add('comment=Cover (front)'); }
    args..add('-c:a')..add(audioCodec);
    if (audioBitrate != null) { args..add('-b:a')..add(audioBitrate); }
    if (metadata != null) _appendMappedMetadataToArguments(args, _convertToId3Tags(metadata));
    args..add('-id3v2_version')..add('3')..add(tempOutput)..add('-y');
    return await _executeWithArguments(args);
  }

  static Future<String?> _finalizeMp3Embed(String mp3Path, String tempOutput) async {
    try {
      final tf = File(tempOutput); final of = File(mp3Path);
      if (await tf.exists()) { if (await of.exists()) await of.delete(); await tf.copy(mp3Path); await tf.delete(); return mp3Path; }
    } catch (e) { _log.e('Failed to finalize MP3 embed: $e'); }
    return null;
  }

  static Future<String?> embedMetadataToOpus({required String opusPath, String? coverPath, Map<String, String>? metadata, String artistTagMode = 'joined', bool preserveMetadata = false}) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpOut = _nextTempEmbedPath(tmpDir.path, '.opus');
    final mapMeta = preserveMetadata ? '0' : '-1';
    final args = <String>['-v', 'error', '-hide_banner', '-i', opusPath, '-map', '0:a', '-map_metadata', mapMeta, '-map_metadata:s:a', mapMeta, '-c:a', 'copy'];
    if (metadata != null) _appendVorbisMetadataToArguments(args, metadata, artistTagMode: artistTagMode);
    if (coverPath != null) {
      try {
        final pb = await _createMetadataBlockPicture(coverPath);
        if (pb != null) { args..add('-metadata')..add('METADATA_BLOCK_PICTURE=$pb'); } else { _log.w('Failed to create METADATA_BLOCK_PICTURE'); }
      } catch (e) { _log.e('Error creating block picture: $e'); }
    }
    args..add(tmpOut)..add('-y');
    final result = await _executeWithArguments(args);
    if (result.success) {
      try {
        final tf = File(tmpOut); final of = File(opusPath);
        if (await tf.exists()) { if (await of.exists()) await of.delete(); await tf.copy(opusPath); await tf.delete(); return opusPath; }
      } catch (e) { _log.e('Failed to replace Opus: $e'); return null; }
    }
    try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (e) { _log.w('Cleanup Opus: $e'); }
    _log.e('Opus embed failed: ${result.output}'); return null;
  }

  static Future<String?> embedMetadataToM4a({required String m4aPath, String? coverPath, Map<String, String>? metadata, bool preserveMetadata = true}) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpOut = _nextTempEmbedPath(tmpDir.path, '.m4a');
    final args = <String>['-v', 'error', '-hide_banner', '-i', m4aPath];
    final hasCover = coverPath != null && coverPath.trim().isNotEmpty && await File(coverPath).exists();
    if (hasCover) { args..add('-i')..add(coverPath!); }
    if (preserveMetadata && !hasCover) { args..add('-map')..add('0')..add('-c')..add('copy'); }
    else { args..add('-map')..add('0:a')..add('-c:a')..add('copy'); }
    args..add('-map_metadata')..add(preserveMetadata ? '0' : '-1');
    if (hasCover) { args..add('-map')..add('1:v')..add('-c:v')..add('copy')..add('-disposition:v:0')..add('attached_pic')..add('-metadata:s:v')..add('title=Album cover')..add('-metadata:s:v')..add('comment=Cover (front)')..add('-f')..add('mp4'); }
    if (metadata != null) _appendMappedMetadataToArguments(args, _convertToM4aTags(metadata));
    args..add(tmpOut)..add('-y');
    final result = await _executeWithArguments(args);
    if (result.success) {
      try {
        final tf = File(tmpOut); final of = File(m4aPath);
        if (await tf.exists()) { if (await of.exists()) await of.delete(); await tf.copy(m4aPath); await tf.delete(); return m4aPath; }
      } catch (e) { _log.e('Failed to replace M4A: $e'); return null; }
    }
    try { final f = File(tmpOut); if (await f.exists()) await f.delete(); } catch (e) { _log.w('Cleanup M4A: $e'); }
    _log.e('M4A embed failed: ${result.output}'); return null;
  }

  static Future<String?> _createMetadataBlockPicture(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) { _log.e('Cover not found: $imagePath'); return null; }
      final data = await file.readAsBytes();
      String mime;
      if (imagePath.toLowerCase().endsWith('.png')) { mime = 'image/png'; }
      else if (imagePath.toLowerCase().endsWith('.jpg') || imagePath.toLowerCase().endsWith('.jpeg')) { mime = 'image/jpeg'; }
      else if (data.length >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) { mime = 'image/png'; }
      else { mime = 'image/jpeg'; }
      final mimeB = utf8.encode(mime);
      const desc = ''; final descB = utf8.encode(desc);
      final size = 4 + 4 + mimeB.length + 4 + descB.length + 4 + 4 + 4 + 4 + 4 + data.length;
      final bytes = Uint8List(size);
      var off = 0;
      var buf = ByteData(4); buf.setUint32(0, 3, Endian.big); bytes.setRange(off, off + 4, buf.buffer.asUint8List()); off += 4;
      buf = ByteData(4); buf.setUint32(0, mimeB.length, Endian.big); bytes.setRange(off, off + 4, buf.buffer.asUint8List()); off += 4;
      bytes.setRange(off, off + mimeB.length, mimeB); off += mimeB.length;
      buf = ByteData(4); buf.setUint32(0, descB.length, Endian.big); bytes.setRange(off, off + 4, buf.buffer.asUint8List()); off += 4;
      bytes.setRange(off, off + descB.length, descB); off += descB.length;
      for (var i = 0; i < 4; i++) { buf = ByteData(4); buf.setUint32(0, 0, Endian.big); bytes.setRange(off, off + 4, buf.buffer.asUint8List()); off += 4; }
      buf = ByteData(4); buf.setUint32(0, data.length, Endian.big); bytes.setRange(off, off + 4, buf.buffer.asUint8List()); off += 4;
      bytes.setRange(off, off + data.length, data);
      return base64Encode(bytes);
    } catch (e) { _log.e('Error creating METADATA_BLOCK_PICTURE: $e'); return null; }
  }

  // ─── Helpers de metadatos ────────────────────────────────────

  static Map<String, String> _normalizeToVorbisComments(Map<String, String> metadata) {
    final v = <String, String>{};
    for (final e in metadata.entries) {
      final k = e.key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final val = e.value;
      switch (k) {
        case 'TITLE': v['TITLE'] = val; break;
        case 'ARTIST': v['ARTIST'] = val; break;
        case 'ALBUM': v['ALBUM'] = val; break;
        case 'ALBUMARTIST': v['ALBUMARTIST'] = val; break;
        case 'TRACKNUMBER': case 'TRACKNBR': case 'TRACK': case 'TRCK': if (val != '0') v['TRACKNUMBER'] = val; break;
        case 'DISCNUMBER': case 'DISC': case 'TPOS': if (val != '0') v['DISCNUMBER'] = val; break;
        case 'DATE':
          v['DATE'] = val;
          final ym = RegExp(r'^(\d{4})').firstMatch(val);
          if (ym != null && (!v.containsKey('YEAR') || v['YEAR']!.isEmpty)) v['YEAR'] = ym.group(1)!;
          break;
        case 'YEAR':
          v['YEAR'] = val;
          if (!v.containsKey('DATE') || v['DATE']!.isEmpty) v['DATE'] = val;
          break;
        case 'GENRE': v['GENRE'] = val; break;
        case 'ISRC': v['ISRC'] = val; break;
        case 'LABEL': case 'ORGANIZATION': v['ORGANIZATION'] = val; break;
        case 'COPYRIGHT': v['COPYRIGHT'] = val; break;
        case 'COMPOSER': v['COMPOSER'] = val; break;
        case 'COMMENT': v['COMMENT'] = val; break;
        case 'LYRICS': case 'UNSYNCEDLYRICS': v['LYRICS'] = val; v['UNSYNCEDLYRICS'] = val; break;
        case 'REPLAYGAINTRACKGAIN': v['REPLAYGAIN_TRACK_GAIN'] = val; break;
        case 'REPLAYGAINTRACKPEAK': v['REPLAYGAIN_TRACK_PEAK'] = val; break;
        case 'REPLAYGAINALBUMGAIN': v['REPLAYGAIN_ALBUM_GAIN'] = val; break;
        case 'REPLAYGAINALBUMPEAK': v['REPLAYGAIN_ALBUM_PEAK'] = val; break;
      }
    }
    return v;
  }

  static void _appendVorbisMetadataToArguments(List<String> args, Map<String, String> metadata, {String artistTagMode = 'joined'}) {
    for (final e in _buildVorbisMetadataEntries(metadata, artistTagMode: artistTagMode)) { args..add('-metadata')..add('${e.key}=${e.value}'); }
  }

  static void _appendMappedMetadataToArguments(List<String> args, Map<String, String> metadata) {
    for (final e in metadata.entries) { args..add('-metadata')..add('${e.key}=${e.value}'); }
  }

  static List<MapEntry<String, String>> _buildVorbisMetadataEntries(Map<String, String> metadata, {String artistTagMode = 'joined'}) {
    final v = _normalizeToVorbisComments(metadata);
    final entries = <MapEntry<String, String>>[];
    for (final e in v.entries) { if (e.key == 'ARTIST' || e.key == 'ALBUMARTIST') continue; entries.add(e); }
    _appendVorbisArtistEntries(entries, 'ARTIST', v['ARTIST'], artistTagMode: artistTagMode);
    _appendVorbisArtistEntries(entries, 'ALBUMARTIST', v['ALBUMARTIST'], artistTagMode: artistTagMode);
    return entries;
  }

  static void _appendVorbisArtistEntries(List<MapEntry<String, String>> entries, String key, String? rawValue, {String artistTagMode = 'joined'}) {
    if (rawValue == null) return;
    final v = rawValue.trim();
    if (v.isEmpty) { entries.add(MapEntry(key, '')); return; }
    if (!shouldSplitVorbisArtistTags(artistTagMode)) { entries.add(MapEntry(key, v)); return; }
    for (final a in splitArtistTagValues(v)) { entries.add(MapEntry(key, a)); }
  }

  static Map<String, String> _convertToM4aTags(Map<String, String> metadata) {
    final m = <String, String>{};
    for (final e in metadata.entries) {
      final k = e.key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final v = e.value;
      switch (k) {
        case 'TITLE': m['title'] = v; break;
        case 'ARTIST': m['artist'] = v; break;
        case 'ALBUM': m['album'] = v; break;
        case 'ALBUMARTIST': m['album_artist'] = v; break;
        case 'TRACKNUMBER': case 'TRACK': case 'TRCK': m['track'] = v; break;
        case 'DISCNUMBER': case 'DISC': case 'TPOS': m['disc'] = v; break;
        case 'DATE': m['date'] = v; break;
        case 'YEAR': if (!m.containsKey('date') || m['date']!.isEmpty) m['date'] = v; break;
        case 'GENRE': m['genre'] = v; break;
        case 'ISRC': m['isrc'] = v; break;
        case 'COMPOSER': m['composer'] = v; break;
        case 'COMMENT': m['comment'] = v; break;
        case 'COPYRIGHT': m['copyright'] = v; break;
        case 'LABEL': case 'ORGANIZATION': m['organization'] = v; break;
        case 'LYRICS': case 'UNSYNCEDLYRICS': m['lyrics'] = v; break;
      }
    }
    return m;
  }

  static Map<String, String> _convertToId3Tags(Map<String, String> vorbisMetadata) {
    final m = <String, String>{};
    for (final e in vorbisMetadata.entries) {
      final k = e.key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final v = e.value;
      switch (k) {
        case 'TITLE': m['title'] = v; break;
        case 'ARTIST': m['artist'] = v; break;
        case 'ALBUM': m['album'] = v; break;
        case 'ALBUMARTIST': m['album_artist'] = v; break;
        case 'TRACKNUMBER': case 'TRACK': case 'TRCK': if (v != '0') m['track'] = v; break;
        case 'DISCNUMBER': case 'DISC': case 'TPOS': if (v != '0') m['disc'] = v; break;
        case 'DATE': m['date'] = v; break;
        case 'YEAR': if (!m.containsKey('date') || m['date']!.isEmpty) m['date'] = v; break;
        case 'ISRC': m['TSRC'] = v; break;
        case 'LYRICS': case 'UNSYNCEDLYRICS': m['lyrics'] = v; break;
        case 'COMPOSER': m['composer'] = v; break;
        case 'COMMENT': m['comment'] = v; break;
        case 'REPLAYGAINTRACKGAIN': m['REPLAYGAIN_TRACK_GAIN'] = v; break;
        case 'REPLAYGAINTRACKPEAK': m['REPLAYGAIN_TRACK_PEAK'] = v; break;
        case 'REPLAYGAINALBUMGAIN': m['REPLAYGAIN_ALBUM_GAIN'] = v; break;
        case 'REPLAYGAINALBUMPEAK': m['REPLAYGAIN_ALBUM_PEAK'] = v; break;
        default: m[e.key.toLowerCase()] = v;
      }
    }
    return m;
  }

  // ─── Conversión unificada ────────────────────────────────────

  static Future<String?> convertAudioFormat({required String inputPath, required String targetFormat, required String bitrate, required Map<String, String> metadata, String? coverPath, String artistTagMode = 'joined', bool deleteOriginal = true}) async {
    final fmt = targetFormat.toLowerCase();
    if (!const {'mp3', 'opus', 'alac', 'flac'}.contains(fmt)) { _log.e('Unsupported target format: $targetFormat'); return null; }
    if (fmt == 'alac') return _convertToAlac(inputPath: inputPath, metadata: metadata, coverPath: coverPath, deleteOriginal: deleteOriginal);
    if (fmt == 'flac') return _convertToFlac(inputPath: inputPath, metadata: metadata, coverPath: coverPath, artistTagMode: artistTagMode, deleteOriginal: deleteOriginal);
    final ext = fmt == 'opus' ? '.opus' : '.mp3';
    final outPath = _buildOutputPath(inputPath, ext);
    final cmd = fmt == 'opus'
        ? '-v error -hide_banner -i "$inputPath" -codec:a libopus -b:a $bitrate -vbr on -compression_level 10 -map 0:a "$outPath" -y'
        : '-v error -hide_banner -i "$inputPath" -codec:a libmp3lame -b:a $bitrate -map 0:a -id3v2_version 3 "$outPath" -y';
    final result = await _execute(cmd);
    if (!result.success) { _log.e('Conversion failed: ${result.output}'); return null; }
    final hasMeta = metadata.values.any((v) => v.trim().isNotEmpty);
    final hasCover = coverPath != null && coverPath.trim().isNotEmpty;
    if (hasMeta || hasCover) {
      String? embed;
      if (fmt == 'mp3') { embed = await embedMetadataToMp3(mp3Path: outPath, coverPath: coverPath, metadata: metadata); }
      else { embed = await embedMetadataToOpus(opusPath: outPath, coverPath: coverPath, metadata: metadata, artistTagMode: artistTagMode); }
      if (embed == null) { try { final f = File(outPath); if (await f.exists()) await f.delete(); } catch (e) { _log.w('Cleanup: $e'); } return null; }
    }
    if (deleteOriginal) { try { await File(inputPath).delete(); } catch (e) { _log.w('Failed to delete original: $e'); } }
    return outPath;
  }

  static Future<String?> _convertToAlac({required String inputPath, required Map<String, String> metadata, String? coverPath, bool deleteOriginal = true}) async {
    final outPath = _buildOutputPath(inputPath, '.m4a');
    final args = <String>['-v', 'error', '-hide_banner', '-i', inputPath];
    final hasCover = coverPath != null && coverPath.trim().isNotEmpty && await File(coverPath).exists();
    if (hasCover) { args..add('-i')..add(coverPath); }
    args..add('-map')..add('0:a');
    if (hasCover) { args..add('-map')..add('1:v')..add('-c:v')..add('copy')..add('-disposition:v:0')..add('attached_pic')..add('-metadata:s:v')..add('title=Album cover')..add('-metadata:s:v')..add('comment=Cover (front)'); }
    args..add('-c:a')..add('alac')..add('-map_metadata')..add('-1');
    _appendMappedMetadataToArguments(args, _convertToM4aTags(metadata));
    args..add(outPath)..add('-y');
    final result = await _executeWithArguments(args);
    if (!result.success) { _log.e('ALAC conversion failed: ${result.output}'); return null; }
    if (deleteOriginal) { try { await File(inputPath).delete(); } catch (e) { _log.w('Failed to delete original: $e'); } }
    return outPath;
  }

  static Future<String?> _convertToFlac({required String inputPath, required Map<String, String> metadata, String? coverPath, String artistTagMode = 'joined', bool deleteOriginal = true}) async {
    final outPath = _buildOutputPath(inputPath, '.flac');
    final args = <String>['-v', 'error', '-hide_banner', '-i', inputPath];
    final hasCover = coverPath != null && coverPath.trim().isNotEmpty && await File(coverPath).exists();
    if (hasCover) { args..add('-i')..add(coverPath); }
    args..add('-map')..add('0:a');
    if (hasCover) { args..add('-map')..add('1:v')..add('-c:v')..add('copy')..add('-disposition:v:0')..add('attached_pic')..add('-metadata:s:v')..add('title=Album cover')..add('-metadata:s:v')..add('comment=Cover (front)'); }
    args..add('-c:a')..add('flac')..add('-compression_level')..add('8')..add('-map_metadata')..add('0');
    _appendVorbisMetadataToArguments(args, metadata, artistTagMode: artistTagMode);
    args..add(outPath)..add('-y');
    final result = await _executeWithArguments(args);
    if (!result.success) { _log.e('FLAC conversion failed: ${result.output}'); return null; }
    if (deleteOriginal) { try { await File(inputPath).delete(); } catch (e) { _log.w('Failed to delete original: $e'); } }
    return outPath;
  }

  // ─── División CUE ────────────────────────────────────────────

  static Future<List<String>?> splitCueToTracks({required String audioPath, required String outputDir, required List<CueSplitTrackInfo> tracks, required Map<String, String> albumMetadata, String? coverPath, void Function(int current, int total)? onProgress}) async {
    if (tracks.isEmpty) { _log.e('No tracks to split'); return null; }
    final paths = <String>[];
    final inputExt = audioPath.toLowerCase().split('.').last;
    final outExt = (inputExt == 'flac' || inputExt == 'wav' || inputExt == 'ape' || inputExt == 'wv') ? 'flac' : inputExt;
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      onProgress?.call(i + 1, tracks.length);
      final safeTitle = t.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
      final tn = t.number.toString().padLeft(2, '0');
      final outPath = '$outputDir${Platform.pathSeparator}$tn - $safeTitle.$outExt';
      final args = <String>['-v', 'error', '-hide_banner', '-i', audioPath, '-ss', _formatSeconds(t.startSec)];
      if (t.endSec > 0) { args..add('-to')..add(_formatSeconds(t.endSec)); }
      if (outExt == 'flac') { args..add('-c:a')..add('flac')..add('-compression_level')..add('8'); } else { args..add('-c:a')..add('copy'); }
      final meta = <String, String>{};
      void addMeta(String k, String v) { if (v.isNotEmpty) meta[k] = v; }
      addMeta('TITLE', t.title); addMeta('ARTIST', t.artist.isNotEmpty ? t.artist : (albumMetadata['artist'] ?? ''));
      addMeta('ALBUM', albumMetadata['album'] ?? ''); addMeta('ALBUMARTIST', albumMetadata['artist'] ?? '');
      addMeta('TRACKNUMBER', t.number.toString()); addMeta('GENRE', albumMetadata['genre'] ?? '');
      addMeta('DATE', albumMetadata['date'] ?? '');
      if (t.isrc.isNotEmpty) addMeta('ISRC', t.isrc);
      if (t.composer.isNotEmpty) addMeta('COMPOSER', t.composer);
      _appendMappedMetadataToArguments(args, meta);
      args..add(outPath)..add('-y');
      final result = await _executeWithArguments(args);
      if (!result.success) { _log.e('CUE split failed track ${t.number}: ${result.output}'); continue; }
      paths.add(outPath);
    }
    if (paths.isEmpty) { _log.e('CUE split: no tracks extracted'); return null; }
    return paths;
  }

  static String _formatSeconds(double seconds) {
    if (seconds < 0) return '0';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds - (h * 3600) - (m * 60);
    return '${h.toString().padLeft(2, '0')}:${m.toInt().toString().padLeft(2, '0')}:${s.toStringAsFixed(3).padLeft(6, '0')}';
  }

  // ─── Metadatos de audio ──────────────────────────────────────

  static Future<AudioMetadataResult> getAudioMetadata(String filePath) async {
    try {
      String wp = filePath;
      String? tmp;
      if (filePath.startsWith('content://')) { tmp = await PlatformBridge.copyContentUriToTemp(filePath); if (tmp == null) return const AudioMetadataResult(success: false, error: 'Failed to copy SAF file'); wp = tmp; }
      try {
        final session = await FFprobeKit.getMediaInformation(wp);
        final info = session.getMediaInformation();
        if (info == null) return const AudioMetadataResult(success: false, error: 'No media info');
        final audio = info.getStreams().firstWhere((s) => s.getAllProperties()?['codec_type'] == 'audio', orElse: () => throw Exception('No audio stream'));
        final p = audio.getAllProperties() ?? {};
        final codec = (p['codec_name'] as String? ?? 'unknown').toUpperCase();
        final sr = int.tryParse(p['sample_rate']?.toString() ?? '') ?? 0;
        final ch = int.tryParse(p['channels']?.toString() ?? '') ?? 0;
        final br = int.tryParse(info.getBitrate() ?? p['bit_rate']?.toString() ?? '') ?? 0;
        var bd = int.tryParse((p['bits_per_raw_sample'] ?? p['bits_per_sample'] ?? '').toString()) ?? 0;
        if (bd == 0) {
          final sf = (p['sample_fmt'] as String? ?? '');
          if (sf.contains('16') || sf == 's16' || sf == 's16p') bd = 16;
          else if (sf.contains('32') || sf == 'flt' || sf == 'fltp') bd = 32;
          else if (sf.contains('24') || sf == 's24') bd = 24;
        }
        return AudioMetadataResult(success: true, metadata: AudioMetadata(codec: codec, bitDepth: bd, sampleRate: sr, channels: ch, bitrate: br));
      } finally { if (tmp != null) { try { await File(tmp).delete(); } catch (_) {} } }
    } catch (e) { return AudioMetadataResult(success: false, error: e.toString()); }
  }
}
