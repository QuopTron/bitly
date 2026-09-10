// ─────────────────────────────────────────────────────────────
// hoja_letras_parse.dart — PART de hoja_letras.dart: parseo de las
// letras — extrae las líneas con timestamp `[mm:ss.xx]` y las
// palabras con timestamps inline (enhanced LRC `<mm:ss.xx>word`),
// ordena por tiempo y deja el texto plano para el fallback.
// Se conecta con: hoja_letras.dart (misma library).
// Parte del flujo: reproductor (letras, parseo LRC).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Parsea un tag de tiempo `mm:ss.xx` a Duration.
Duration _parsearTag(String tag) {
  final minutos = int.parse(tag.substring(0, 2));
  final segundos = int.parse(tag.substring(3, 5));
  final millis =
      tag.length > 6 ? int.parse(tag.substring(6).padRight(3, '0')) : 0;
  return Duration(minutes: minutos, seconds: segundos, milliseconds: millis);
}

/// Llena `_lineas` y `_textoPlano` desde las letras crudas (LRC o plano).
void _parsear(_HojaLetrasState st) {
  final crudas = st.widget.letrasCrudas;
  st._textoPlano = _quitarLrc(crudas);
  final regexTiempo = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
  for (final lineaCruda in crudas.split('\n')) {
    final recortada = lineaCruda.trim();
    final match = regexTiempo.firstMatch(recortada);
    if (match == null) continue;
    final minutos = int.parse(match.group(1)!);
    final segundos = int.parse(match.group(2)!);
    final millis = int.parse(match.group(3)!.padRight(3, '0'));
    var texto = recortada.replaceAll(regexTiempo, '').trim();
    if (texto.isEmpty) continue;

    // Enhanced LRC: tags inline `<mm:ss.xx>word` → karaoke por palabra.
    final regexInline = RegExp(r'<(\d{1,2}:\d{2}(?:\.\d{1,3})?)>');
    final palabras = <(Duration, String)>[];
    final partes = texto.split(regexInline);
    if (partes.length >= 3) {
      var primerTiempo = Duration(
        minutes: minutos,
        seconds: segundos,
        milliseconds: millis,
      );
      for (var i = 0; i < partes.length - 1; i += 2) {
        final tag = partes[i + 1].trim();
        if (tag.isEmpty) continue;
        final palabra = partes[i].trim();
        if (palabra.isNotEmpty) {
          palabras.add((primerTiempo, palabra));
        }
        primerTiempo = _parsearTag(tag);
      }
      final cola = partes.last.trim();
      if (cola.isNotEmpty) palabras.add((primerTiempo, cola));
      texto = texto.replaceAll(regexInline, '').trim();
    }

    st._lineas.add(_KLine(
      Duration(minutes: minutos, seconds: segundos, milliseconds: millis),
      texto,
      palabras,
    ));
  }
  if (st._lineas.isNotEmpty) {
    st._lineas.sort((a, b) => a.tiempo.compareTo(b.tiempo));
  }
}

/// Quita los tags LRC y metadatos, dejando solo el texto plano.
String _quitarLrc(String lrc) {
  final salida = <String>[];
  for (final linea in lrc.split('\n')) {
    final recortada = linea.trim();
    if (recortada.isEmpty) continue;
    if (RegExp(r'^\[(ti|ar|al|by|offset|re|ve):').hasMatch(recortada)) {
      continue;
    }
    if (RegExp(r'^\[\d{2}:\d{2}\.\d{2,3}\]$').hasMatch(recortada)) {
      continue;
    }
    final texto =
        recortada.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim();
    if (texto.isNotEmpty) salida.add(texto);
  }
  return salida.join('\n');
}