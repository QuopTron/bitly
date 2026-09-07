import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../models/feed_models.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../backend/services/playlist_cubit.dart';
import '../../../injection.dart';

void showAddToModal(BuildContext context, FeedItem item) {
  final r = Responsive(context);
  final loc = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToSheet(r: r, loc: loc, item: item),
  );
}

class _AddToSheet extends StatelessWidget {
  final Responsive r;
  final AppLocalizations loc;
  final FeedItem item;

  const _AddToSheet({required this.r, required this.loc, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final hasTrack = sl<QueueCubit>().state.hasCurrent;
    final modalBg = hasTrack ? bg.withValues(alpha: 0.85) : bg;

    Widget sheet = Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: EdgeInsets.only(top: r.spacingM),
            width: 40, height: 4,
            decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: r.spacingM),
          // Item preview
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacingM),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: onBg.withValues(alpha: 0.06),
                ),
                child: item.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(item.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, e, s) =>
                            Icon(Icons.music_note_rounded, color: onBg.withValues(alpha: 0.3), size: 20)),
                      )
                    : Icon(Icons.music_note_rounded, color: onBg.withValues(alpha: 0.3), size: 20),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w600, color: onBg)),
                    if (item.artists != null && item.artists!.isNotEmpty)
                      Text(item.artists!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
          SizedBox(height: r.spacingM),
          Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
          // Options
          _option(r, onBg, glow, Icons.playlist_add_rounded, loc.setup.addToPlaylist, () {
            Navigator.pop(context);
            _addToPlaylist(context, item);
          }),
          Divider(height: 1, indent: 52, color: onBg.withValues(alpha: 0.06)),
          _option(r, onBg, glow, Icons.favorite_border_rounded, loc.setup.addToWishlist, () {
            Navigator.pop(context);
            context.read<LikeCubit>().toggleLike(item);
          }),
          if (item.type == 'track') ...[
            Divider(height: 1, indent: 52, color: onBg.withValues(alpha: 0.06)),
            _option(r, onBg, glow, Icons.queue_music_rounded, loc.setup.playNext, () {
              Navigator.pop(context);
              sl<QueueCubit>().addNext(item);
            }),
          ],
          SizedBox(height: r.bottomPadding),
        ]),
      ),
    );
    if (hasTrack) {
      sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: sheet,
        ),
      );
    }
    return sheet;
  }

  void _addToPlaylist(BuildContext context, FeedItem item) {
    final cubit = sl<PlaylistCubit>();
    final state = cubit.state;
    if (state.playlists.isEmpty) {
      _showCreatePlaylistDialog(context, cubit, item);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlaylistPicker(r: r, cubit: cubit, item: item),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, PlaylistCubit cubit, FeedItem item) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = isDark ? AppColors.greenBright : AppColors.greenMedium;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.playlist_add_rounded, color: glow, size: 22),
          SizedBox(width: r.spacingS),
          Text('Nueva playlist', style: TextStyle(color: onBg, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: loc.setup.playlistNameHint,
            hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
            filled: true,
            fillColor: onBg.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: glow),
            ),
          ),
          style: TextStyle(color: onBg),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.setup.cancel, style: TextStyle(color: onBg.withValues(alpha: 0.6)))),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final id = await cubit.createPlaylist(name);
                if (id != null && item.type == 'track') {
                  cubit.addTrack(id, item.id);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Crear', style: TextStyle(color: glow, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _option(Responsive r, Color onBg, Color glow, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingM + 8, vertical: r.spacingM),
          child: Row(children: [
            Icon(icon, size: r.subtitleSize, color: onBg.withValues(alpha: 0.65)),
            SizedBox(width: r.spacingM),
            Text(label, style: TextStyle(fontSize: r.subtitleSize - 1, color: onBg, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _PlaylistPicker extends StatelessWidget {
  final Responsive r;
  final PlaylistCubit cubit;
  final FeedItem item;

  const _PlaylistPicker({required this.r, required this.cubit, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: EdgeInsets.only(top: r.spacingM),
            width: 40, height: 4,
            decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: r.spacingM),
          Text('Seleccionar playlist',
              style: TextStyle(fontSize: r.subtitleSize + 1, fontWeight: FontWeight.bold, color: onBg)),
          SizedBox(height: r.spacingS),
          // Create new option
          ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: glow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, color: glow, size: r.subtitleSize),
            ),
            title: Text('Crear nueva playlist',
                style: TextStyle(color: glow, fontWeight: FontWeight.w600, fontSize: r.subtitleSize - 1)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => Scaffold(
                  body: _CreatePlaylistInline(item: item),
                ),
              ));
            },
          ),
          Divider(height: 1, color: onBg.withValues(alpha: 0.06)),
          ...cubit.state.playlists.map((p) => ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: onBg.withValues(alpha: 0.06),
              ),
              child: p.coverPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(p.coverPath!, fit: BoxFit.cover, errorBuilder: (_, e, s) =>
                          Icon(Icons.playlist_play_rounded, color: onBg.withValues(alpha: 0.4), size: 20)),
                    )
                  : Icon(Icons.playlist_play_rounded, color: onBg.withValues(alpha: 0.4), size: 20),
            ),
            title: Text(p.name, style: TextStyle(color: onBg, fontSize: r.subtitleSize - 1)),
            subtitle: Text('${p.itemCount} canciones',
                style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4))),
            onTap: () {
              if (item.type == 'track') cubit.addTrack(p.id, item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Agregado a "${p.name}"'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            },
          )),
          SizedBox(height: r.bottomPadding),
        ]),
      ),
    );
  }
}

/// Inline creation sheet used when accessed from playlist picker.
class _CreatePlaylistInline extends StatefulWidget {
  final FeedItem item;
  const _CreatePlaylistInline({required this.item});
  @override
  State<_CreatePlaylistInline> createState() => _CreatePlaylistInlineState();
}

class _CreatePlaylistInlineState extends State<_CreatePlaylistInline> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = isDark ? AppColors.greenBright : AppColors.greenMedium;
    return Padding(
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Nombre de la playlist'),
          ),
          SizedBox(height: r.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                final id = await sl<PlaylistCubit>().createPlaylist(_ctrl.text.trim());
                if (id != null && widget.item.type == 'track') {
                  await sl<PlaylistCubit>().addTrack(id, widget.item.id);
                }
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: glow, foregroundColor: Colors.white),
              child: _saving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Crear y agregar'),
            ),
          ),
        ],
      ),
    );
  }
}
