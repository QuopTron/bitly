package com.example.bitly

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * UpdateDownloader — Puente entre Flutter y la descarga de actualizaciones.
 *
 * Por qué existe: la descarga vive en un servicio nativo (ver
 * UpdateDownloadService) porque tiene que sobrevivir a que el usuario salga de
 * la app y anunciarse en la barra de notificaciones. Dart no puede hablar con
 * un servicio del sistema, así que este canal es la única puerta:
 *
 *   descargar   {url, version, nombre} → "iniciado"
 *   cancelar                           → "ok"
 *   estado                             → JSON del progreso actual
 *   descargados                        → JSON con los APKs que ya hay en disco
 *   limpiar     {conservar}            → cuántos archivos viejos se borraron
 *   instalar    {version}              → true si se abrió el instalador
 *   notificar   {version, texto}       → avisa que hay una versión nueva
 *   textos      {…}                    → traduce los textos de la notificación
 *
 * Se conecta con: MainActivity (lo registra) y
 * lib/core/plataforma/actualizacion/actualizacion_servicio.dart (lo usa).
 */
object UpdateDownloader {
  private const val CANAL = "com.bitly/update"

  /** El canal va SIN tipo de dato: devuelve siempre un valor serializable. */
  fun registrar(messenger: BinaryMessenger, contexto: Context) {
    MethodChannel(messenger, CANAL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
      try {
        when (call.method) {
          "descargar" -> {
            val url = call.argument<String>("url").orEmpty()
            val version = call.argument<String>("version").orEmpty()
            val nombre = call.argument<String>("nombre").orEmpty()
            if (url.isEmpty() || version.isEmpty()) {
              result.error("DATOS", "faltan url o version", null)
            } else {
              UpdateDownloadService.iniciar(contexto, url, version, nombre)
              result.success("iniciado")
            }
          }
          "cancelar" -> {
            UpdateDownloadService.cancelar(contexto)
            result.success("ok")
          }
          "estado" -> result.success(Estado.leer().toString())
          "descargados" -> result.success(UpdateDownloadService.descargados(contexto).toString())
          "limpiar" -> {
            val conservar = call.argument<String>("conservar").orEmpty()
            result.success(UpdateDownloadService.borrarAntiguos(contexto, conservar))
          }
          "instalar" -> {
            val version = call.argument<String>("version").orEmpty()
            result.success(UpdateDownloadService.instalar(contexto, version))
          }
          "notificar" -> {
            val version = call.argument<String>("version").orEmpty()
            val texto = call.argument<String>("texto").orEmpty()
            UpdateDownloadService.notificarDisponible(contexto, version, texto)
            result.success("ok")
          }
          "textos" -> {
            // La notificación la dibuja Android, así que sus textos tienen que
            // llegar ya traducidos desde el l10n de Flutter.
            call.argument<String>("descargando")?.let { TextosActualizacion.DESCARGANDO = it }
            call.argument<String>("lista")?.let { TextosActualizacion.LISTA = it }
            call.argument<String>("fallo")?.let { TextosActualizacion.FALLO = it }
            call.argument<String>("cancelar")?.let { TextosActualizacion.CANCELAR = it }
            call.argument<String>("instalar")?.let { TextosActualizacion.INSTALAR = it }
            call.argument<String>("tocaInstalar")?.let { TextosActualizacion.TOCA_INSTALAR = it }
            call.argument<String>("tocaReintentar")?.let { TextosActualizacion.TOCA_REINTENTAR = it }
            call.argument<String>("canal")?.let { TextosActualizacion.CANAL = it }
            call.argument<String>("canalDescripcion")?.let { TextosActualizacion.CANAL_DESCRIPCION = it }
            call.argument<String>("disponible")?.let { TextosActualizacion.DISPONIBLE = it }
            result.success("ok")
          }
          else -> result.notImplemented()
        }
      } catch (e: Exception) {
        // Nunca dejar a Dart esperando: una excepción acá colgaría el Future.
        result.error("UPDATE", e.message, null)
      }
    }
  }
}
