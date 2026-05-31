class LyricsLine {
  final int startTimeMs;
  final String words;
  final int endTimeMs;
  final String? translation;

  const LyricsLine({
    required this.startTimeMs,
    required this.words,
    required this.endTimeMs,
    this.translation,
  });

  factory LyricsLine.fromJson(Map<String, dynamic> json) => LyricsLine(
    startTimeMs: (json['startTimeMs'] as num).toInt(),
    words: json['words'] as String,
    endTimeMs: (json['endTimeMs'] as num).toInt(),
    translation: json['translation'] as String?,
  );
}

class LyricsResponse {
  final List<LyricsLine> lines;
  final String syncType;
  final bool instrumental;
  final String source;

  const LyricsResponse({
    required this.lines,
    required this.syncType,
    this.instrumental = false,
    this.source = '',
  });

  bool get isSynced => syncType == 'LINE_SYNCED';

  factory LyricsResponse.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'] as List<dynamic>? ?? [];
    return LyricsResponse(
      lines: linesRaw
          .map((e) => LyricsLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      syncType: json['sync_type'] as String? ?? '',
      instrumental: json['instrumental'] as bool? ?? false,
      source: json['source'] as String? ?? '',
    );
  }

  factory LyricsResponse.fromFetchLyricsResult(Map<String, dynamic> result) {
    if (result['success'] != true) {
      return const LyricsResponse(lines: [], syncType: '');
    }
    return LyricsResponse.fromJson(result);
  }

  factory LyricsResponse.fromLRCWithSourceResult(Map<String, dynamic> result) {
    final lrcText = result['lyrics'] as String? ?? '';
    final syncType = result['sync_type'] as String? ?? '';
    final source = result['source'] as String? ?? '';
    final instrumental = result['instrumental'] as bool? ?? false;

    if (lrcText.isEmpty || lrcText == '[instrumental:true]') {
      return LyricsResponse(
        lines: [],
        syncType: syncType,
        instrumental: instrumental || lrcText == '[instrumental:true]',
        source: source,
      );
    }

    final lines = _parseLRCTimestamps(lrcText);
    return LyricsResponse(
      lines: lines,
      syncType: syncType,
      instrumental: instrumental,
      source: source,
    );
  }

  static List<LyricsLine> _parseLRCTimestamps(String lrc) {
    final linePattern = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$', multiLine: true);
    final matches = linePattern.allMatches(lrc);
    if (matches.isEmpty) return [];

    final parsed = <LyricsLine>[];
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final cs = int.parse(m.group(3)!);
      final text = m.group(4)!.trim();
      if (text.isEmpty || text.startsWith('ti:') || text.startsWith('ar:') || text.startsWith('by:')) continue;

      final ms = min * 60000 + sec * 1000 + (m.group(3)!.length == 2 ? cs * 10 : cs);
      parsed.add(LyricsLine(startTimeMs: ms, words: text, endTimeMs: ms + 5000));
    }

    for (var i = 0; i < parsed.length - 1; i++) {
      parsed[i] = LyricsLine(
        startTimeMs: parsed[i].startTimeMs,
        words: parsed[i].words,
        endTimeMs: parsed[i + 1].startTimeMs,
      );
    }

    return parsed;
  }
}
