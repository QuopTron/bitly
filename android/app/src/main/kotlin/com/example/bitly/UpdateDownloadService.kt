package com.example.bitly

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * UpdateDownloadService — Baja el APK de una versión nueva EN SEGUNDO PLANO y
 * lo anuncia en la barra de notificaciones, igual que hace el reproductor con
 * la canción que suena.
 *
 * Por qué un servicio y no un `http.get` en Dart: la descarga anterior traía el
 * APK entero a memoria (`resp.bodyBytes`) y lo escribía en la carpeta temporal.
 * Eso significa (a) que el archivo se perdía al cerrar la app —o sea que
 * "instalarlo luego" era imposible—, (b) que no había progreso y (c) que si el
 * usuario salía de la pantalla, la descarga moría. Acá el trabajo vive en un
 * foreground service: sobrevive a que el usuario se vaya, se ve el avance en la
 * notificación y el APK queda guardado para instalarlo cuando quiera.
 *
 * Contrato con Dart (ver UpdateDownloader.kt y el puente de Flutter):
 *   · iniciar()   → arranca (o reusa) la descarga de una versión;
 *   · cancelar()  → corta y borra el archivo a medias;
 *   · estado()    → JSON con lo que está pasando ahora;
 *   · descargados() → JSON con las versiones que YA están en disco;
 *   · borrarAntiguos(version) → deja solo el APK de esa versión;
 *   · instalar(version) → abre el instalador del APK ya bajado;
 *   · notificarNueva() → avisa que hay una versión nueva (sin descargarla).
 *
 * Se conecta con: UpdateDownloader.kt (el puente) y AndroidManifest.xml (el
 * servicio y el FileProvider que expone el APK al instalador).
 */
class UpdateDownloadService : Service() {

  /** Lado hilo de descarga: no toca la UI ni el NotificationManager directo. */
  private var hilo: Thread? = null

  /** Corta la descarga en curso; lo revisa el bucle de lectura. */
  @Volatile private var cancelado = false

  /** Conexión viva, para poder cerrarla al cancelar. */
  @Volatile private var conexion: HttpURLConnection? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_CANCELAR -> cancelarYCerrar()
      ACTION_DESCARGAR -> {
        val url = intent.getStringExtra(EXTRA_URL).orEmpty()
        val version = intent.getStringExtra(EXTRA_VERSION).orEmpty()
        val nombre = intent.getStringExtra(EXTRA_NOMBRE).orEmpty()
        if (url.isEmpty() || version.isEmpty()) {
          detener()
          return START_NOT_STICKY
        }
        // Un reintento/una segunda pulsación no arranca dos descargas.
        if (hilo?.isAlive == true) return START_NOT_STICKY
        // Un servicio en foreground NO puede arrancar sin notificación: se
        // publica antes de empezar a trabajar (Android 8+ tira si no).
        arrancarForeground(notificationProgreso(version, 0, 0))
        cancelado = false
        Estado.iniciar(version, nombre, destino(this, version, nombre).absolutePath)
        hilo = Thread { descargar(url, version, nombre) }.also { it.start() }
      }
    }
    // START_NOT_STICKY: si el sistema mata el proceso, no queremos que reviva
    // una descarga a medias sin que el usuario lo haya pedido.
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    cancelado = true
    conexion?.disconnect()
    super.onDestroy()
  }

  // ── Descarga ────────────────────────────────────────────────────────────

  private fun descargar(url: String, version: String, nombre: String) {
    val destino = destino(this, version, nombre)
    val parcial = File(destino.absolutePath + ".parcial")
    try {
      val total = tamanoRemoto(url)
      // Ya está bajada y completa: no se vuelve a pedir (esto es lo que
      // permite reabrir la hoja y ver "descargada" en vez de bajar de nuevo).
      if (destino.exists() && total > 0 && destino.length() == total) {
        Estado.listo(version, nombre, destino.absolutePath, total)
        publicar(notificationListo(version, destino))
        detener()
        return
      }
      val conexionLocal = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 30_000
        instanceFollowRedirects = true
        setRequestProperty("Accept", "application/octet-stream")
      }
      conexion = conexionLocal
      conexionLocal.connect()
      val codigo = conexionLocal.responseCode
      if (codigo !in 200..299) {
        throw IllegalStateException("el servidor respondió $codigo")
      }
      // Content-Length puede venir vacío (chunked): en ese caso el progreso se
      // muestra sin porcentaje en vez de mentir con un total inventado.
      val totalBytes = if (total > 0) total else conexionLocal.contentLength.toLong()
      var leidos = 0L
      var ultimoAviso = 0L
      FileOutputStream(parcial).use { salida ->
        conexionLocal.inputStream.use { entrada ->
          val buffer = ByteArray(64 * 1024)
          while (true) {
            if (cancelado) throw InterruptedException("cancelada")
            val leidosAhora = entrada.read(buffer)
            if (leidosAhora < 0) break
            salida.write(buffer, 0, leidosAhora)
            leidos += leidosAhora
            // La notificación se actualiza ~4 veces por segundo: más seguido no
            // se ve y castiga al sistema.
            val ahora = System.currentTimeMillis()
            if (ahora - ultimoAviso >= 250) {
              ultimoAviso = ahora
              Estado.progreso(version, nombre, leidos, totalBytes)
              publicar(notificationProgreso(version, leidos, totalBytes))
            }
          }
        }
      }
      if (cancelado) throw InterruptedException("cancelada")
      // El reemplazo es atómico para no dejar nunca un APK truncado con nombre
      // de bueno (el instalador lo rechazaría y el archivo quedaría envenenado).
      if (destino.exists()) destino.delete()
      if (!parcial.renameTo(destino)) throw IllegalStateException("no se pudo guardar el APK")
      Estado.listo(version, nombre, destino.absolutePath, leidos)
      publicar(notificationListo(version, destino))
    } catch (e: InterruptedException) {
      parcial.delete()
      Estado.cancelada()
      cancelarNotificacion()
    } catch (e: Exception) {
      parcial.delete()
      Estado.fallo(version, nombre, e.message ?: "error desconocido")
      publicar(notificationFallo(version))
    } finally {
      conexion?.disconnect()
      conexion = null
      detener()
    }
  }

  /** Tamaño del archivo remoto (0 si el servidor no lo declara). */
  private fun tamanoRemoto(url: String): Long {
    return try {
      val c = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 15_000
        requestMethod = "HEAD"
        instanceFollowRedirects = true
      }
      c.connect()
      // contentLength (int) y no contentLengthLong: ese último pide API 24+ y
      // acá un APK nunca pasa de 2 GB.
      val largo = c.contentLength.toLong()
      c.disconnect()
      if (largo > 0) largo else 0L
    } catch (e: Exception) {
      0L
    }
  }

  // ── Ciclo de vida del servicio ──────────────────────────────────────────

  private fun cancelarYCerrar() {
    cancelado = true
    conexion?.disconnect()
    Estado.cancelada()
    cancelarNotificacion()
    detener()
  }

  /** Deja el servicio como estaba: sin foreground y sin proceso colgado. */
  private fun detener() {
    try {
      // DETACH: la notificación final (lista para instalar) tiene que QUEDAR
      // visible aunque el servicio ya no exista — es todo el punto de
      // "instalarlo luego".
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_DETACH)
      } else {
        @Suppress("DEPRECATION")
        stopForeground(false)
      }
    } catch (e: Exception) {
      // Si nunca llegó a ser foreground, no hay nada que soltar.
    }
    stopSelf()
  }

  private fun arrancarForeground(n: Notification) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(
          ID_NOTIFICACION,
          n,
          android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        )
      } else {
        startForeground(ID_NOTIFICACION, n)
      }
    } catch (e: Exception) {
      // En Android 14+ un arranque desde segundo plano sin tipo declarado tira
      // ForegroundServiceStartNotAllowedException: se cae a la descarga sin
      // foreground en vez de matar la app (el archivo igual se baja).
      publicar(n)
    }
  }

  // ── Notificaciones ──────────────────────────────────────────────────────

  private fun publicar(n: Notification) {
    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    try {
      mgr.notify(ID_NOTIFICACION, n)
    } catch (e: Exception) {
      // Android 13+ sin permiso de notificaciones: la descarga sigue igual.
    }
  }

  private fun cancelarNotificacion() {
    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    mgr.cancel(ID_NOTIFICACION)
  }

  /**
   * Notificación de progreso con el mismo espíritu que la del reproductor:
   * título, estado, avance y un botón para cancelar.
   */
  private fun notificationProgreso(version: String, leidos: Long, total: Long): Notification {
    crearCanal()
    val porcentaje =
      if (total > 0) ((leidos * 100) / total).toInt().coerceIn(0, 100) else 0
    val texto =
      if (total > 0) "${megas(leidos)} / ${megas(total)} MB"
      else "${megas(leidos)} MB"
    return base(TextosActualizacion.DESCARGANDO, "Bitly $version · $texto")
      .setProgress(100, porcentaje, total <= 0)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .addAction(0, TextosActualizacion.CANCELAR, pendingServicio(ACTION_CANCELAR, 1))
      .build()
  }

  /** "Listo para instalar" — con el botón que abre el instalador del sistema. */
  private fun notificationListo(version: String, apk: File): Notification {
    crearCanal()
    return base(TextosActualizacion.LISTA, "Bitly $version · ${TextosActualizacion.TOCA_INSTALAR}")
      // Sin ongoing: se puede descartar, y NO se autocancela para que el aviso
      // siga ahí hasta que el usuario decida instalar.
      .setAutoCancel(false)
      .setOngoing(false)
      .setProgress(0, 0, false)
      .addAction(0, TextosActualizacion.INSTALAR, pendingInstalar(apk, 2))
      .setContentIntent(pendingInstalar(apk, 3))
      .build()
  }

  private fun notificationFallo(version: String): Notification {
    crearCanal()
    return base(TextosActualizacion.FALLO, "Bitly $version · ${TextosActualizacion.TOCA_REINTENTAR}")
      .setAutoCancel(true)
      .build()
  }

  private fun base(titulo: String, texto: String): NotificationCompat.Builder {
    return NotificationCompat.Builder(this, CANAL)
      .setSmallIcon(android.R.drawable.stat_sys_download)
      .setContentTitle(titulo)
      .setContentText(texto)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      // Al tocar el cuerpo se abre la app (ahí está la hoja de versión con el
      // estado y el botón de instalar).
      .setContentIntent(pendingActividad())
  }

  private fun crearCanal() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (mgr.getNotificationChannel(CANAL) != null) return
    val canal = NotificationChannel(CANAL, TextosActualizacion.CANAL, NotificationManager.IMPORTANCE_LOW)
    canal.description = TextosActualizacion.CANAL_DESCRIPCION
    canal.setShowBadge(false)
    mgr.createNotificationChannel(canal)
  }

  private fun pendingActividad(): PendingIntent {
    val intent = packageManager.getLaunchIntentForPackage(packageName)
      ?: Intent(this, MainActivity::class.java)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    return PendingIntent.getActivity(
      this,
      0,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or flagsInmutables()
    )
  }

  private fun pendingServicio(action: String, codigo: Int): PendingIntent {
    val intent = Intent(this, UpdateDownloadService::class.java).setAction(action)
    return PendingIntent.getService(
      this,
      codigo,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or flagsInmutables()
    )
  }

  /**
   * PendingIntent que abre el INSTALADOR del sistema con el APK ya bajado.
   * La URI va por el FileProvider porque Android 7+ rechaza `file://`.
   */
  private fun pendingInstalar(apk: File, codigo: Int): PendingIntent {
    val uri =
      FileProvider.getUriForFile(this, "$packageName.updateprovider", apk)
    val intent = Intent(Intent.ACTION_VIEW).apply {
      setDataAndType(uri, TipoApk)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return PendingIntent.getActivity(
      this,
      codigo,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or flagsInmutables()
    )
  }

  private fun megas(bytes: Long): String =
    String.format(java.util.Locale.US, "%.1f", bytes / 1048576.0)

  companion object {
    const val ACTION_DESCARGAR = "com.example.bitly.update.DESCARGAR"
    const val ACTION_CANCELAR = "com.example.bitly.update.CANCELAR"
    const val EXTRA_URL = "url"
    const val EXTRA_VERSION = "version"
    const val EXTRA_NOMBRE = "nombre"

    private const val CANAL = "com.example.bitly.channel.update"
    private const val ID_NOTIFICACION = 4201
    private const val TipoApk = "application/vnd.android.package-archive"

    /** Carpeta donde viven los APKs descargados, dentro de la app. */
    fun carpeta(context: Context): File {
      val base = context.getExternalFilesDir(null) ?: context.filesDir
      val dir = File(base, "updates")
      if (!dir.exists()) dir.mkdirs()
      return dir
    }

    /**
     * Nombre del archivo de una versión. Lleva la versión Y el nombre del asset
     * (que ya trae la arquitectura): sin lo segundo, un APK de arm64 y uno de
     * x86 con la misma versión se pisarían entre sí.
     */
    fun destino(context: Context, version: String, nombre: String): File {
      val limpio = nombre.ifEmpty { "app.apk" }.replace(Regex("[^A-Za-z0-9._-]"), "_")
      return File(carpeta(context), "bitly-v$version-$limpio")
    }

    /** Arranca la descarga (idempotente: si ya corre, no hace nada). */
    fun iniciar(context: Context, url: String, version: String, nombre: String) {
      val intent = Intent(context, UpdateDownloadService::class.java).apply {
        action = ACTION_DESCARGAR
        putExtra(EXTRA_URL, url)
        putExtra(EXTRA_VERSION, version)
        putExtra(EXTRA_NOMBRE, nombre)
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent)
      } else {
        context.startService(intent)
      }
    }

    fun cancelar(context: Context) {
      val intent = Intent(context, UpdateDownloadService::class.java).apply {
        action = ACTION_CANCELAR
      }
      try {
        context.startService(intent)
      } catch (e: Exception) {
        // Sin servicio no hay nada que cancelar.
      }
    }

    /** APK de [version] si YA está bajado y completo, o null. */
    fun apkDescargado(context: Context, version: String): File? {
      val dir = carpeta(context)
      val archivos = dir.listFiles() ?: return null
      return archivos.firstOrNull {
        it.isFile && !it.name.endsWith(".parcial") &&
          it.name.startsWith("bitly-v$version-") && it.length() > 0
      }
    }

    /**
     * Borra los APKs de versiones VIEJAS (y los `.parcial` de descargas
     * cortadas). Se conserva la versión indicada: lo demás ya no sirve y solo
     * ocupa lugar.
     */
    fun borrarAntiguos(context: Context, versionConservada: String): Int {
      val archivos = carpeta(context).listFiles() ?: return 0
      var borrados = 0
      for (a in archivos) {
        if (!a.isFile) continue
        val viejo = a.name.endsWith(".parcial") ||
          (!a.name.startsWith("bitly-v$versionConservada-") && a.name.startsWith("bitly-v"))
        if (viejo && a.delete()) borrados++
      }
      return borrados
    }

    /** Lista de versiones bajadas, para que la app sepa qué tiene en disco. */
    fun descargados(context: Context): JSONArray {
      val salida = JSONArray()
      for (a in (carpeta(context).listFiles() ?: emptyArray())) {
        if (!a.isFile || a.name.endsWith(".parcial")) continue
        val m = Regex("^bitly-v([0-9][^\\-]*)-").find(a.name) ?: continue
        salida.put(
          JSONObject()
            .put("version", m.groupValues[1])
            .put("nombre", a.name)
            .put("ruta", a.absolutePath)
            .put("bytes", a.length())
        )
      }
      return salida
    }

    /** Abre el instalador del sistema para el APK ya bajado de [version]. */
    fun instalar(context: Context, version: String): Boolean {
      val apk = apkDescargado(context, version) ?: return false
      val uri = FileProvider.getUriForFile(context, "${context.packageName}.updateprovider", apk)
      val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, TipoApk)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      return try {
        context.startActivity(intent)
        true
      } catch (e: Exception) {
        false
      }
    }

    /** Avisa que hay una versión nueva disponible (sin bajarla todavía). */
    fun notificarDisponible(context: Context, version: String, texto: String) {
      val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && mgr.getNotificationChannel(CANAL) == null) {
        val canal = NotificationChannel(CANAL, TextosActualizacion.CANAL, NotificationManager.IMPORTANCE_LOW)
        canal.description = TextosActualizacion.CANAL_DESCRIPCION
        canal.setShowBadge(false)
        mgr.createNotificationChannel(canal)
      }
      val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?: Intent(context, MainActivity::class.java)
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      val pi = PendingIntent.getActivity(
        context,
        4,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or flagsInmutables()
      )
      val n = NotificationCompat.Builder(context, CANAL)
        .setSmallIcon(android.R.drawable.stat_notify_sync)
        .setContentTitle(TextosActualizacion.DISPONIBLE)
        .setContentText(texto.ifEmpty { "Bitly $version" })
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setAutoCancel(true)
        .setContentIntent(pi)
        .build()
      try {
        mgr.notify(ID_NOTIFICACION_DISPONIBLE, n)
      } catch (e: Exception) {
        // Sin permiso de notificaciones: el aviso in-app sigue estando.
      }
    }

    private const val ID_NOTIFICACION_DISPONIBLE = 4202

    /** Un PendingIntent de Android 12+ sin esta bandera tira al crearse. */
    private fun flagsInmutables(): Int =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
  }
}

/**
 * Textos de las notificaciones de actualización.
 *
 * Van acá y no en el l10n de Flutter porque la notificación la dibuja Android,
 * sin el árbol de widgets: el puente (UpdateDownloader) le empuja los textos YA
 * traducidos y estos son el respaldo en español para cuando el servicio arranca
 * sin que la app haya pasado por el l10n (p. ej. al reintentar desde el botón
 * de la propia notificación).
 *
 * Es `object` de nivel de archivo y no un anidado del companion: en Kotlin un
 * object dentro de un companion NO se ve por el nombre de la clase
 * (`UpdateDownloadService.Textos` no compila), así que el puente lo alcanza
 * como `TextosActualizacion`.
 */
object TextosActualizacion {
  var DESCARGANDO = "Descargando actualización"
  var LISTA = "Actualización lista"
  var FALLO = "No se pudo descargar la actualización"
  var CANCELAR = "Cancelar"
  var INSTALAR = "Instalar"
  var TOCA_INSTALAR = "tocá para instalar"
  var TOCA_REINTENTAR = "tocá para reintentar"
  var CANAL = "Actualizaciones"
  var CANAL_DESCRIPCION = "Descargas de versiones nuevas de la app"
  var DISPONIBLE = "Hay una versión nueva"
}

/**
 * Estado de la descarga en curso, para que Dart pueda preguntar "¿cómo va?" sin
 * que el servicio tenga que empujar eventos (un EventChannel complica el ciclo
 * de vida y esto se consulta desde una hoja que está abierta o no lo está).
 */
object Estado {
  private val candado = Any()
  private var json: JSONObject = JSONObject().put("estado", "inactivo")

  fun iniciar(version: String, nombre: String, ruta: String) = fijar(
    JSONObject()
      .put("estado", "descargando")
      .put("version", version)
      .put("nombre", nombre)
      .put("ruta", ruta)
      .put("leidos", 0)
      .put("total", 0)
      .put("progreso", 0)
  )

  fun progreso(version: String, nombre: String, leidos: Long, total: Long) = fijar(
    JSONObject()
      .put("estado", "descargando")
      .put("version", version)
      .put("nombre", nombre)
      .put("leidos", leidos)
      .put("total", total)
      .put("progreso", if (total > 0) ((leidos * 100) / total).toInt() else 0)
  )

  fun listo(version: String, nombre: String, ruta: String, bytes: Long) = fijar(
    JSONObject()
      .put("estado", "listo")
      .put("version", version)
      .put("nombre", nombre)
      .put("ruta", ruta)
      .put("leidos", bytes)
      .put("total", bytes)
      .put("progreso", 100)
  )

  fun fallo(version: String, nombre: String, error: String) = fijar(
    JSONObject()
      .put("estado", "error")
      .put("version", version)
      .put("nombre", nombre)
      .put("error", error)
  )

  fun cancelada() = fijar(JSONObject().put("estado", "cancelado"))

  fun leer(): JSONObject = synchronized(candado) { JSONObject(json.toString()) }

  private fun fijar(nuevo: JSONObject) {
    synchronized(candado) { json = nuevo }
  }
}
