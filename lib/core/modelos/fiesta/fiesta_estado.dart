// ─────────────────────────────────────────────────────────────
// fiesta_estado.dart — Lo que el aparato que MANDA la fiesta le cuenta a los
// demás: qué canción suena, en qué minuto va, si está sonando y —lo más
// importante— a qué hora era eso según su reloj.
//
// Es puro (mapa entra, mapa sale) y sin red: por eso el cálculo fino del modo
// fiesta —cuánto hay que corregir en cada aparato— se puede probar sin dos
// dispositivos ni un cable de por medio.
//
// El truco del reloj: cada aparato tiene su propia hora, así que los invitados
// calculan el DESFASE contra el reloj del que manda (mitad del viaje de ida y
// vuelta) y, con [posicionEsperada], saben en qué segundo tendría que estar
// sonando la canción en el momento exacto en que la van a arrancar.
//
// Se conecta con: servicio_fiesta (lo publica el host y lo lee el invitado).
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

/// Versión del formato del estado: si cambia, un aparato viejo no se mezcla.
const int versionFiesta = 1;

/// Cada cuánto el invitado pregunta cómo va la fiesta (milisegundos).
const int latidoFiestaMs = 1500;

/// Cuánta deriva se tolera antes de corregir (milisegundos). Menos de esto se
/// nota más el salto que el desfase; más, ya se escucha el eco entre aparatos.
const int derivaFiestaMs = 250;

class FiestaEstado {
  /// Identidad de la pista que suena (ISRC o id). Vacío = no hay nada.
  final String clave;

  final String titulo;
  final String artista;
  final String album;

  /// Duración total, si se conoce.
  final int duracionMs;

  /// Dónde iba la canción cuando el aparato que manda escribió este estado.
  final int posicionMs;

  /// El reloj de ese aparato en ese momento (milisegundos desde la época).
  final int enMs;

  final bool sonando;

  const FiestaEstado({
    this.clave = '',
    this.titulo = '',
    this.artista = '',
    this.album = '',
    this.duracionMs = 0,
    this.posicionMs = 0,
    this.enMs = 0,
    this.sonando = false,
  });

  /// Nada sonando (lo que ve un invitado que llega con la fiesta armada pero
  /// en pausa).
  static const vacio = FiestaEstado();

  /// ¿Hay una canción puesta?
  bool get hayPista => clave.isNotEmpty;

  Map<String, dynamic> aJson() => {
    'v': versionFiesta,
    'clave': clave,
    'titulo': titulo,
    'artista': artista,
    'album': album,
    'duracionMs': duracionMs,
    'posicionMs': posicionMs,
    'enMs': enMs,
    'sonando': sonando,
  };

  /// Lee el estado publicado. Un mapa roto no rompe la fiesta: queda el estado
  /// vacío (el invitado sigue esperando).
  factory FiestaEstado.desdeJson(Map<String, dynamic> json) => FiestaEstado(
    clave: json['clave'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    artista: json['artista'] as String? ?? '',
    album: json['album'] as String? ?? '',
    duracionMs: (json['duracionMs'] as num?)?.toInt() ?? 0,
    posicionMs: (json['posicionMs'] as num?)?.toInt() ?? 0,
    enMs: (json['enMs'] as num?)?.toInt() ?? 0,
    sonando: json['sonando'] == true,
  );

  /// ¿Es la misma canción que [otro]?
  bool mismaPistaQue(FiestaEstado otro) =>
      hayPista && otro.hayPista && clave == otro.clave;

  /// ¿Cambió la canción respecto de [otro]?
  bool cambioDePistaRespectoA(FiestaEstado otro) => clave != otro.clave;

  /// En qué milisegundo tendría que estar la canción AHORA, en el reloj del
  /// invitado. [desfaseMs] = relojDelQueManda − relojLocal (lo estima el
  /// invitado con la mitad del viaje de ida y vuelta).
  int posicionEsperadaMs(int ahoraLocalMs, int desfaseMs) {
    if (!sonando) return posicionMs;
    final transcurrido = ahoraLocalMs + desfaseMs - enMs;
    var esperada = posicionMs + (transcurrido > 0 ? transcurrido : 0);
    if (duracionMs > 0 && esperada > duracionMs) esperada = duracionMs;
    return esperada;
  }

  /// ¿Hay que corregir? (la diferencia supera lo que se tolera)
  bool hayDeriva(int posicionActualMs, int esperadaMs) =>
      (posicionActualMs - esperadaMs).abs() > derivaFiestaMs;

  FiestaEstado copiarCon({bool? sonando}) => FiestaEstado(
    clave: clave,
    titulo: titulo,
    artista: artista,
    album: album,
    duracionMs: duracionMs,
    posicionMs: posicionMs,
    enMs: enMs,
    sonando: sonando ?? this.sonando,
  );
}
