// PART de modal_cola.dart: handle, cabecera, lista y estado vacío.

part of 'modal_cola.dart';

Widget _handleCola(Responsive r, Color fg) {
  return Container(
    margin: EdgeInsets.only(top: r.spacingM),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: fg.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

Widget _cabeceraCola(
  BuildContext context,
  Responsive r,
  EstadoCola cola,
  Color fg,
  Color colorBrillo,
) {
  final total = cola.tracks.length;
  final proximos = cola.tieneActual ? total - cola.indiceActual - 1 : total;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Row(
      children: [
        Icon(Icons.queue_music, size: r.subtitleSize + 2, color: colorBrillo),
        SizedBox(width: r.spacingS),
        Text(
          'Cola ($total)',
          style: TextStyle(
            fontSize: r.subtitleSize + 1,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
        if (cola.shuffle || cola.modoRepeticion != ModoRepeticion.ninguno) ...[
          SizedBox(width: r.spacingS),
          if (cola.shuffle)
            ChipModoCola(
              icono: Icons.shuffle,
              etiqueta: 'Shuffle',
              r: r,
              colorBrillo: colorBrillo,
            ),
          if (cola.modoRepeticion != ModoRepeticion.ninguno) ...[
            SizedBox(width: r.spacingXS),
            ChipModoCola(
              icono: cola.modoRepeticion == ModoRepeticion.uno
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              etiqueta:
                  cola.modoRepeticion == ModoRepeticion.uno ? 'One' : 'All',
              r: r,
              colorBrillo: colorBrillo,
            ),
          ],
        ],
        const Spacer(),
        if (proximos > 0)
          Text(
            '$proximos próximos',
            style: TextStyle(
              fontSize: r.footerSize,
              color: fg.withValues(alpha: 0.5),
            ),
          ),
      ],
    ),
  );
}

Widget _listaCola(
  BuildContext context,
  Responsive r,
  EstadoCola cola,
  Color fg,
  Color colorBrillo,
) {
  final cubit = context.read<CubitCola>();
  return ReorderableListView.builder(
    padding: EdgeInsets.only(top: r.spacingXS, bottom: r.bottomPadding),
    itemCount: cola.tracks.length,
    onReorder: (viejo, nuevo) {
      Haptico.medio();
      cubit.reordenar(viejo, nuevo);
    },
    proxyDecorator: (child, index, animation) => Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: child,
    ),
    itemBuilder: (context, index) {
      final track = cola.tracks[index];
      final esActual = cola.tieneActual && index == cola.indiceActual;
      final esReproducida =
          cola.tieneActual && index < cola.indiceActual;

      return FilaTrackCola(
        key: ValueKey('cola_${track.id}'),
        r: r,
        fg: fg,
        colorBrillo: colorBrillo,
        track: track,
        index: index,
        esActual: esActual,
        esReproducida: esReproducida,
        onTap: esActual
            ? null
            : () {
                Haptico.tap();
                cubit.irA(index);
                Navigator.pop(context);
              },
        onQuitar: () {
          Haptico.tap();
          cubit.eliminar(index);
        },
      );
    },
  );
}

Widget _estadoVacioCola(Responsive r, Color colorBrillo, Color fg) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.queue_music, size: 56, color: fg.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text(
          'Cola vacía',
          style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: fg),
        ),
        const SizedBox(height: 4),
        Text(
          'Reproduce una canción para empezar',
          style: TextStyle(
              fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
        ),
      ],
    ),
  );
}