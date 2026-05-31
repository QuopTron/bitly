/// JSON decoding, encoding and deep-copy helpers used by [PlatformBridge].
///
/// Extracted to keep business-logic methods in the main file lean.
library bridge_decoder;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const pbJsonResultFileKey = '__json_file';
const pbBackgroundJsonDecodeThresholdBytes = 128 * 1024;

Object? decodeJsonInBackground(String json) => jsonDecode(json);

Object? decodeJsonResult(dynamic result) {
  if (result is String) {
    if (result.isEmpty) return null;
    return jsonDecode(result);
  }
  return result;
}

Future<Object?> decodeJsonResultAsync(dynamic result) async {
  if (result is Map && result[pbJsonResultFileKey] is String) {
    final file = File(result[pbJsonResultFileKey] as String);
    try {
      final contents = await file.readAsString();
      if (contents.isEmpty) return null;
      return decodeJsonStringAsync(contents);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
  if (result is String &&
      result.length >= pbBackgroundJsonDecodeThresholdBytes) {
    return decodeJsonStringAsync(result);
  }
  return decodeJsonResult(result);
}

Future<Object?> decodeJsonStringAsync(String json) {
  if (json.length < pbBackgroundJsonDecodeThresholdBytes) {
    return Future<Object?>.value(jsonDecode(json));
  }
  return compute(decodeJsonInBackground, json);
}

Map<String, dynamic> decodeRequiredMapResult(
  dynamic result,
  String method,
) {
  final decoded = decodeJsonResult(result);
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw FormatException(
    'Expected map result from $method, got ${decoded.runtimeType}',
  );
}

Map<String, dynamic>? decodeNullableMapResult(
  dynamic result,
  String method,
) {
  final decoded = decodeJsonResult(result);
  if (decoded == null) return null;
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw FormatException(
    'Expected nullable map result from $method, got ${decoded.runtimeType}',
  );
}

Future<Map<String, dynamic>> decodeRequiredMapResultAsync(
  dynamic result,
  String method,
) async {
  final decoded = await decodeJsonResultAsync(result);
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  throw FormatException(
    'Expected map result from $method, got ${decoded.runtimeType}',
  );
}

List<dynamic> decodeRequiredListResult(
  dynamic result,
  String method,
) {
  final decoded = decodeJsonResult(result);
  if (decoded is List) return decoded;
  throw FormatException(
    'Expected list result from $method, got ${decoded.runtimeType}',
  );
}

Future<List<dynamic>> decodeRequiredListResultAsync(
  dynamic result,
  String method,
) async {
  final decoded = await decodeJsonResultAsync(result);
  if (decoded is List) return decoded;
  throw FormatException(
    'Expected list result from $method, got ${decoded.runtimeType}',
  );
}

List<Map<String, dynamic>> decodeMapListResult(
  dynamic result,
  String method,
) {
  return decodeRequiredListResult(result, method).map((entry) {
    if (entry is Map) return entry.cast<String, dynamic>();
    throw FormatException(
      'Expected map entry from $method, got ${entry.runtimeType}',
    );
  }).toList();
}

Future<List<Map<String, dynamic>>> decodeMapListResultAsync(
  dynamic result,
  String method,
) async {
  final decoded = await decodeRequiredListResultAsync(result, method);
  return decoded.map((entry) {
    if (entry is Map) return entry.cast<String, dynamic>();
    throw FormatException(
      'Expected map entry from $method, got ${entry.runtimeType}',
    );
  }).toList();
}

List<String> decodeStringListResult(dynamic result, String method) {
  return decodeRequiredListResult(result, method).map((entry) {
    if (entry is String) return entry;
    throw FormatException(
      'Expected string entry from $method, got ${entry.runtimeType}',
    );
  }).toList();
}

Map<String, dynamic> decodeMapResult(dynamic result) {
  if (result is Map) {
    return result.cast<String, dynamic>();
  }
  if (result is String) {
    if (result.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(result);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  }
  return const <String, dynamic>{};
}

/// Deep-copies a JSON-like value (maps, lists, primitives).
dynamic copyJsonLike(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): copyJsonLike(entry.value),
    };
  }
  if (value is List) {
    return value.map(copyJsonLike).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> copyStringMap(Map<String, dynamic> value) {
  return <String, dynamic>{
    for (final entry in value.entries) entry.key: copyJsonLike(entry.value),
  };
}

Map<String, dynamic>? copyNullableStringMap(
  Map<String, dynamic>? value,
) {
  if (value == null) return null;
  return copyStringMap(value);
}

List<Map<String, dynamic>> copyMapList(
  List<Map<String, dynamic>> value,
) {
  return value.map(copyStringMap).toList(growable: false);
}

dynamic canonicalizeJsonLike(dynamic value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return <String, dynamic>{
      for (final entry in entries)
        entry.key.toString(): canonicalizeJsonLike(entry.value),
    };
  }
  if (value is List) {
    return value.map(canonicalizeJsonLike).toList(growable: false);
  }
  return value;
}
