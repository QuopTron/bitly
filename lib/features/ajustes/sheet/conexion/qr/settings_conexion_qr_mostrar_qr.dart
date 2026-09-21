// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_mostrar_qr.dart — PART de settings_sheet_new.dart: el
// cuadro del QR y el código de 6 dígitos en grande, tal como los ve el usuario
// en el aparato que quiere entrar.
//
// El QR va sobre blanco a propósito: es lo que la cámara del otro aparato
// puede leer (sobre el fondo oscuro de la app no enfoca igual). El código va
// debajo, espaciado, para poder dictarlo o escribirlo sin equivocarse.
//
// Se conecta con: settings_conexion_qr_mostrar.dart (la hoja lo monta).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// El cuadro blanco con el QR de la invitación.
class _CuadroQr extends StatelessWidget {
  final PayloadVinculo dato;
  final Responsive r;

  const _CuadroQr({required this.dato, required this.r});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(r.spacingS),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r.val(16, 12, 24)),
    ),
    child: QrImageView(
      data: dato.textoQr,
      version: QrVersions.auto,
      size: r.val(180, 150, 240),
      backgroundColor: Colors.white,
      errorStateBuilder:
          (_, _) => SizedBox(
            width: r.val(180, 150, 240),
            height: r.val(180, 150, 240),
            child: const Center(child: Icon(Icons.error_outline)),
          ),
    ),
  );
}

/// El código de 6 dígitos, en grande y con un espacio al medio.
class _CodigoGrande extends StatelessWidget {
  final String codigo;
  final Color onBg;
  final Responsive r;

  const _CodigoGrande({
    required this.codigo,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) => Text(
    codigo.length == 6
        ? '${codigo.substring(0, 3)} ${codigo.substring(3)}'
        : codigo,
    style: TextStyle(
      fontSize: r.titleSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 6,
      color: onBg,
    ),
  );
}
