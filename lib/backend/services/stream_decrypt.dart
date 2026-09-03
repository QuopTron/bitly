import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';

/// Serializes decrypt runs. ffmpeg-kit_full spawns a heavy native ffmpeg per
/// session; on memory-constrained devices running many decryptions at once
/// (a batch download + the startup repair scan + streaming preloads) OOMs the
/// processes mid-write — the tell-tale symptom is output truncated to a clean
/// 4096 multiple + a burst of unhandled `SESSION_NOT_FOUND` from the plugin's
/// async completion callback. Running them one at a time keeps a single
/// ffmpeg alive and ends the race.
final _decryptGate = <Future<void>>[Future.value()];

Future<T> _serialized<T>(Future<T> Function() run) async {
  final prev = _decryptGate.last;
  final completer = Completer<void>();
  _decryptGate.add(completer.future);
  try {
    await prev;
    return await run();
  } finally {
    completer.complete();
    _decryptGate.remove(completer.future);
  }
}

/// Outcome of a stream/download decryption attempt.
class StreamDecryptResult {
  final String? filePath;
  final bool success;
  final String output;

  const StreamDecryptResult({
    this.filePath,
    required this.success,
    this.output = '',
  });
}

/// Builds the candidate decryption keys for a provider key. Sources (e.g.
/// Amazon zarz.moe) may hand the key back with a `0x` prefix, as compact hex,
/// or base64-encoded; FFmpeg's MOV/MP4 demuxer expects `-decryption_key` to be
/// a plain hex string (it hex-decodes the value) of exactly 16 bytes for
/// AES-128, and REJECTS a `0x` prefix or any other length. So we only emit
/// unprefixed 32-hex-char keys and try them until one yields a playable file.
List<String> _decryptionKeyCandidates(String rawKey) {
  final candidates = <String>{};
  // FFmpeg's mov demuxer hex-decodes the binary `decryption_key` option; a key
  // of any length other than 16 bytes fails with "Invalid decryption key len".
  void addHex(String hex) {
    final normalized = hex.trim().toLowerCase();
    if (normalized.isEmpty || normalized.length != 32) return;
    if (RegExp(r'^[0-9a-f]+$').hasMatch(normalized)) candidates.add(normalized);
  }

  final trimmed = rawKey.trim();
  if (trimmed.isEmpty) return candidates.toList();

  final noPrefix = trimmed.startsWith(RegExp(r'0x', caseSensitive: false))
      ? trimmed.substring(2)
      : trimmed;

  // Plain hex: strip any non-hex junk and take the 16-byte (32 hex) form.
  final compactHex = noPrefix.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  addHex(compactHex);

  // The provider may hand the key back base64-encoded. Decode and emit the
  // 16-byte hex form (only keys that decode to exactly 16 bytes are valid).
  try {
    final decoded = base64Decode(noPrefix.replaceAll(RegExp(r'\s+'), ''));
    final hex = decoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    addHex(hex);
  } catch (_) {}

  // Some FFmpeg builds accept a raw 16-byte key string directly.
  addHex(noPrefix);
  if (trimmed.length == 32 || trimmed.length == 16) addHex(trimmed);

  return candidates.toList();
}

/// Resolves the preferred output extension for a decrypted file (mirrors the
/// upstream logic that prefers `.flac` unless the input format clearly needs
/// an MP4 container).
String _resolvePreferredExtension(String? requested) {
  final trimmed = (requested ?? '').trim();
  if (trimmed.isNotEmpty) {
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }
  return '.flac';
}

/// Runs a single ffmpeg decrypt command (argument-list form, no shell) and
/// returns the result. [mapAudioOnly] maps just the audio track (upstream
/// uses this when muxing to flac) so unrelated/garbage tracks in the source
/// are ignored.
/// True when [path] contains a plausible decrypted audio payload rather than
/// the still-encrypted CENC (`cmfc`/`cenc`) MP4 stream or an error page/empty
/// file. Used to accept an ffmpeg result even when the kit's return code is
/// unreliable (ffmpeg-kit on emulators can race its async completion callback
/// and report failure right after writing a perfectly valid output file).
Future<bool> _looksLikeDecryptedMedia(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return false;
    final st = await f.length();
    if (st < 10240) return false; // Reject files smaller than 10KB (truncated/empty)
    final raf = await f.open();
    List<int> head;
    try {
      head = await raf.read(64);
    } finally {
      await raf.close();
    }
    if (head.length < 4) return false;
    String ascii(int x) => String.fromCharCode(x);
    final magic4 = ascii(head[0]) + ascii(head[1]) + ascii(head[2]) + ascii(head[3]);
    if (magic4 == 'fLaC' || magic4 == 'ID3' || magic4 == 'OggS' || magic4 == 'RIFF') {
      return true;
    }
    // MP4/MOV: accept when it has an ftyp box AND is NOT a CENC-encrypted
    // brand ("cmfc"/"cenc" would mean it's still the raw DRM stream).
    // Also reject encryption markers (sinf/enca/encv) which indicate DRM containers.
    final asciis = head.map(ascii).join('');
    if (asciis.contains('ftyp')) {
      if (asciis.contains('cmfc') || asciis.contains('cenc')) return false;
      if (asciis.contains('sinf') || asciis.contains('enca') || asciis.contains('encv')) return false;
      return true;
    }
    // Unknown binary payload with content — give it the benefit of the doubt
    // (the fallback chain validates structure downstream when playing).
    return true;
  } catch (_) {
    return false;
  }
}

/// Waits a short while for [path] to appear with real content. ffmpeg-kit's
/// async completion callback can fire before the process' output file is
/// fully flushed, so a naive exists() check would reject a valid decrypt.
Future<bool> _waitForFile(String path, {int attempts = 12}) async {
  for (var i = 0; i < attempts; i++) {
    try {
      final f = File(path);
      if (await f.exists() && (await f.length()) > 0) return true;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

Future<StreamDecryptResult> _runDecrypt(
  List<String> args,
  String outputPath,
) async {
  try {
    final session = await FFmpegKit.executeWithArgumentsAsync(args);
    final code = await session.getReturnCode();
    String output = '';
    try {
      output = (await session.getOutput() ?? '').trim();
    } catch (_) {}
    final flushed = await _waitForFile(outputPath);
    // Prefer the actual file on disk over the kit's return code: on emulators
    // the callback can report failure right after a valid write. Only accept
    // a written file that looks like decrypted media (not the DRM stream).
    if (flushed && await _looksLikeDecryptedMedia(outputPath)) {
      return StreamDecryptResult(
        filePath: outputPath,
        success: true,
        output: output,
      );
    }
    return StreamDecryptResult(
      filePath: null,
      success: false,
      output: output.isEmpty
          ? 'ffmpeg decrypt failed (rc=$code)'
          : output,
    );
  } on Exception catch (e) {
    // ffmpeg-kit can throw (e.g. SESSION_NOT_FOUND during its async callback
    // race) even when the process itself produced output. Never let that
    // crash the download flow — fall back to the on-disk output check.
    final flushed = await _waitForFile(outputPath);
    if (flushed && await _looksLikeDecryptedMedia(outputPath)) {
      return StreamDecryptResult(
        filePath: outputPath,
        success: true,
        output: 'ffmpeg-kit error recovered: $e',
      );
    }
    return StreamDecryptResult(
      filePath: null,
      success: false,
      output: 'ffmpeg-kit error: $e',
    );
  }
}

/// Builds the ffmpeg decrypt argument list. Forces the MOV demuxer (the input
/// may carry a `.flac`/`.m4a` name while actually holding an encrypted MP4),
/// maps only the audio track, and forces the muxer that matches the output
/// extension — without it FFmpeg keeps the input's ISO-BMFF layout under a
/// `.flac` filename, which produces a truncated/undecodable file.
List<String> _buildDecryptArgs({
  required String demuxer,
  required String inputPath,
  required String outputPath,
  required String key,
  required bool mapAudioOnly,
  bool forceMovMuxer = false,
}) {
  final List<String> muxerOverride;
  if (forceMovMuxer) {
    muxerOverride = <String>['-f', 'mov'];
  } else if (outputPath.toLowerCase().endsWith('.flac')) {
    muxerOverride = <String>['-f', 'flac'];
  } else if (outputPath.toLowerCase().endsWith('.mp4') ||
      outputPath.toLowerCase().endsWith('.m4a') ||
      outputPath.toLowerCase().endsWith('.aac')) {
    // .m4a and .aac are ISO-BMFF variants — use the mp4 muxer, NOT ipod
    // (ipod muxer rejects FLAC codec, while mp4 supports it).
    muxerOverride = <String>['-f', 'mp4'];
  } else {
    muxerOverride = <String>['-f', 'ipod'];
  }
  return <String>[
    '-nostdin',
    '-hide_banner',
    '-v',
    'error',
    '-decryption_key',
    key,
    '-f',
    demuxer,
    '-i',
    inputPath,
    if (mapAudioOnly) ...<String>['-map', '0:a'],
    '-c',
    'copy',
    ...muxerOverride,
    '-y',
    outputPath,
  ];
}

/// Decrypts an encrypted/DRM stream file (e.g. an Amazon mov_key FLAC-in-MP4)
/// into a playable file via ffmpeg-kit. Writes the output next to the source
/// (or into [outputDir] with [outputBaseName] when provided) and returns the
/// path on success (null otherwise). Robust against key-format differences,
/// multiple container tracks, and codecs the flac muxer rejects (falling back
/// to `.m4a`/`.mp4`, and finally forcing the MOV muxer for AC-4/Atmos).
Future<StreamDecryptResult> decryptMovKeyFile({
  required String srcPath,
  required String key,
  String? inputFormat,
  String? outputExtension,
  String? outputDir,
  String? outputBaseName,
}) =>
    _serialized(() => _decryptMovKeyFileUnlocked(
          srcPath: srcPath,
          key: key,
          inputFormat: inputFormat,
          outputExtension: outputExtension,
          outputDir: outputDir,
          outputBaseName: outputBaseName,
        ));

Future<StreamDecryptResult> _decryptMovKeyFileUnlocked({
  required String srcPath,
  required String key,
  String? inputFormat,
  String? outputExtension,
  String? outputDir,
  String? outputBaseName,
}) async {
  final srcFile = File(srcPath);
  if (!await srcFile.exists()) {
    return const StreamDecryptResult(success: false, output: 'source not found');
  }

  final preferredExt = _resolvePreferredExtension(outputExtension);
  final demuxer = (inputFormat ?? '').trim().isNotEmpty
      ? inputFormat!.trim()
      : 'mov';

  final dir = outputDir ?? srcFile.parent.path;
  final sourceName = srcFile.uri.pathSegments.last;
  final baseName =
      (outputBaseName ?? sourceName).replaceFirst(RegExp(r'\.[^.]+$'), '');
  String outPath(String ext) =>
      '$dir${Platform.pathSeparator}$baseName.dec$ext';

  final keys = _decryptionKeyCandidates(key);
  if (keys.isEmpty) {
    return const StreamDecryptResult(success: false, output: 'no usable key');
  }

  String? lastFfmpegOutput;
  for (final keyCandidate in keys) {
    var outputPath = outPath(preferredExt);
    var result = await _runDecrypt(
      _buildDecryptArgs(
        demuxer: demuxer,
        inputPath: srcPath,
        outputPath: outputPath,
        key: keyCandidate,
        mapAudioOnly: true,
      ),
      outputPath,
    );
    if (!result.success) lastFfmpegOutput = result.output;

    // Fallback: FLAC-in-MP4 can't be remuxed to .flac by ffmpeg-kit's flac
    // muxer (it fails silently). The MP4 muxer IS able to hold FLAC codec,
    // but ipod is not — try mp4 first, then ipod, then mov.
    if (!result.success && preferredExt == '.flac') {
      outputPath = outPath('.mp4');
      result = await _runDecrypt(
        _buildDecryptArgs(
          demuxer: demuxer,
          inputPath: srcPath,
          outputPath: outputPath,
          key: keyCandidate,
          mapAudioOnly: true,
        ),
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Fallback: streams that can't be remuxed into FLAC get an .m4a container.
    if (!result.success && preferredExt == '.flac') {
      outputPath = outPath('.m4a');
      result = await _runDecrypt(
        _buildDecryptArgs(
          demuxer: demuxer,
          inputPath: srcPath,
          outputPath: outputPath,
          key: keyCandidate,
          mapAudioOnly: true,
        ),
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Fallback: mp4 muxer for codecs the ipod muxer rejects
    // (e.g. eac3, mha1/Dolby Atmos).
    if (!result.success) {
      outputPath = outPath('.mp4');
      result = await _runDecrypt(
        _buildDecryptArgs(
          demuxer: demuxer,
          inputPath: srcPath,
          outputPath: outputPath,
          key: keyCandidate,
          mapAudioOnly: true,
        ),
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Final fallback: force the MOV muxer for codecs the MP4 muxer rejects
    // (e.g. AC-4), keeping the .mp4 filename.
    if (!result.success) {
      outputPath = outPath('.mp4');
      result = await _runDecrypt(
        _buildDecryptArgs(
          demuxer: demuxer,
          inputPath: srcPath,
          outputPath: outputPath,
          key: keyCandidate,
          mapAudioOnly: true,
          forceMovMuxer: true,
        ),
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Re-encode fallback: FLAC is lossless, so re-encoding with -c:a flac
    // is safe and works when -c copy fails (e.g. FLAC-in-MP4 where the
    // container layout prevents a direct copy to .flac output).
    // Explicitly set the output muxer (-f flac / -f mp4) because ffmpeg
    // auto-detects 'ipod' for .m4a which rejects FLAC codec.
    if (!result.success && preferredExt == '.flac') {
      outputPath = outPath('.flac');
      result = await _runDecrypt(
        <String>[
          '-nostdin',
          '-hide_banner',
          '-v', 'error',
          '-decryption_key', keyCandidate,
          '-f', demuxer,
          '-i', srcPath,
          '-map', '0:a',
          '-c:a', 'flac',
          '-f', 'flac',
          '-y', outputPath,
        ],
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Re-encode to .m4a as last resort (FLAC re-encoded in MP4 container).
    // MUST use -f mp4 (not ipod) because ipod muxer rejects FLAC codec.
    if (!result.success && preferredExt == '.flac') {
      outputPath = outPath('.m4a');
      result = await _runDecrypt(
        <String>[
          '-nostdin',
          '-hide_banner',
          '-v', 'error',
          '-decryption_key', keyCandidate,
          '-f', demuxer,
          '-i', srcPath,
          '-map', '0:a',
          '-c:a', 'flac',
          '-f', 'mp4',
          '-y', outputPath,
        ],
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    // Nuclear option: decrypt to temp .mp4 first (copy, always works for
    // MP4-in-MP4), then re-encode from the decrypted temp file to the
    // desired format. This two-step path avoids demuxer/muxer mismatches
    // in single-pass mode.
    if (!result.success && preferredExt == '.flac') {
      final tmpMp4 = outPath('.tmp.mp4');
      final tmpResult = await _runDecrypt(
        _buildDecryptArgs(
          demuxer: demuxer,
          inputPath: srcPath,
          outputPath: tmpMp4,
          key: keyCandidate,
          mapAudioOnly: true,
        ),
        tmpMp4,
      );
      if (tmpResult.success && await File(tmpMp4).exists()) {
        // Re-encode the decrypted temp MP4 to .flac
        outputPath = outPath('.flac');
        result = await _runDecrypt(
          <String>[
            '-nostdin',
            '-hide_banner',
            '-v', 'error',
            '-i', tmpMp4,
            '-map', '0:a',
            '-c:a', 'flac',
            '-f', 'flac',
            '-y', outputPath,
          ],
          outputPath,
        );
        if (!result.success) lastFfmpegOutput = result.output;
        // If .flac re-encode also failed, try .m4a
        if (!result.success) {
          outputPath = outPath('.m4a');
          result = await _runDecrypt(
            <String>[
              '-nostdin',
              '-hide_banner',
              '-v', 'error',
              '-i', tmpMp4,
              '-map', '0:a',
              '-c:a', 'flac',
              '-f', 'mp4',
              '-y', outputPath,
            ],
            outputPath,
          );
          if (!result.success) lastFfmpegOutput = result.output;
        }
      }
      // Clean up temp file
      try { await File(tmpMp4).delete(); } catch (_) {}
    }

    // AAC re-encode fallback: when FLAC copy and FLAC re-encode both fail
    // (e.g. emulator ffmpeg-kit can't handle FLAC-in-MP4), fall back to AAC
    // which is universally supported. Produces a lossy file but that's
    // better than no file at all.
    if (!result.success) {
      outputPath = outPath('.m4a');
      result = await _runDecrypt(
        <String>[
          '-nostdin', '-hide_banner', '-v', 'error',
          '-decryption_key', keyCandidate,
          '-f', demuxer,
          '-i', srcPath,
          '-map', '0:a',
          '-c:a', 'aac', '-b:a', '256k',
          '-f', 'ipod',
          '-y', outputPath,
        ],
        outputPath,
      );
      if (!result.success) lastFfmpegOutput = result.output;
    }

    if (result.success) return result;
  }

  // Clean up any partial outputs.
  for (final ext in [preferredExt, '.m4a', '.mp4', '.tmp.mp4']) {
    try {
      final f = File(outPath(ext));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
  return StreamDecryptResult(
    success: false,
    // Include the last ffmpeg error plus what the file actually is so a failed
    // decrypt shows the real problem: a valid encrypted MP4 starts with an ftyp
    // box ("0000001866747970" / ...ftyp), a plain FLAC with "664c6143" (fLaC),
    // an HTML error page with "3c21444f" (<!), and a truncated file by its
    // (small) size.
    output: lastFfmpegOutput ?? 'decrypt failed: ${await _fileFingerprint(srcPath)}',
  );
}

/// Size plus first 16 bytes (hex) of [path] for decrypt-failure diagnostics.
Future<String> _fileFingerprint(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return 'file missing';
    final st = await f.length();
    final raf = await f.open();
    try {
      final head = await raf.read(16);
      return 'size=$st head=${head.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    } finally {
      await raf.close();
    }
  } catch (e) {
    return 'fingerprint error: $e';
  }
}