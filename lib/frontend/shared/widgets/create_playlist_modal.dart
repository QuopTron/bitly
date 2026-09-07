import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';
import '../../../backend/services/playlist_cubit.dart';
import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../injection.dart';
import '../models/feed_models.dart';
import 'cover_image.dart';

/// Opens the redesigned playlist creation sheet.
/// Returns the new playlist ID on success, or null if cancelled.
Future<String?> showCreatePlaylistModal(BuildContext context, {FeedItem? initialTrack}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatePlaylistSheet(initialTrack: initialTrack),
  );
}

class _CreatePlaylistSheet extends StatefulWidget {
  final FeedItem? initialTrack;
  const _CreatePlaylistSheet({this.initialTrack});

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  String? _selectedCover = '-1';
  final Set<String> _selectedTrackIds = {};
  List<_PickableTrack> _availableTracks = [];
  bool _loaded = false;


  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _loadTracks() {
    final tracks = <_PickableTrack>[];
    try {
      final liked = sl<LikeCubit>().tracks;
      for (final t in liked) {
        tracks.add(_PickableTrack(
          id: t.id, name: t.name, artist: t.artists,
          coverUrl: t.coverUrl ?? t.localCoverPath, source: t.source,
        ));
      }
    } catch (_) {}
    try {
      final downloaded = sl<DownloadCubit>().completedTracks;
      for (final d in downloaded) {
        if (tracks.any((t) => t.id == d.id)) continue;
        tracks.add(_PickableTrack(
          id: d.id, name: d.name, artist: d.artists,
          coverUrl: d.coverUrl, source: d.source,
        ));
      }
    } catch (_) {}
    if (widget.initialTrack != null) {
      final it = widget.initialTrack!;
      _selectedTrackIds.add(it.id);
      if (!tracks.any((t) => t.id == it.id)) {
        tracks.insert(0, _PickableTrack(
          id: it.id, name: it.name, artist: it.artists,
          coverUrl: it.coverUrl, source: it.source,
        ));
      }
    }
    if (mounted) setState(() { _availableTracks = tracks; _loaded = true; });
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final coverValue = (_selectedCover != null && _selectedCover != '-1') ? 'gradient:${_selectedCover}' : '';
    final id = await context.read<PlaylistCubit>().createPlaylist(name, coverPath: coverValue.isEmpty ? null : coverValue);
    if (id != null && _selectedTrackIds.isNotEmpty) {
      final cubit = context.read<PlaylistCubit>();
      for (final trackId in _selectedTrackIds) {
        await cubit.addTrack(id, trackId);
      }
    }
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        margin: EdgeInsets.only(top: r.spacingXL * 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
              blurRadius: 30, offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            children: [
              SizedBox(height: r.spacingM),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              SizedBox(height: r.spacingM),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                child: Row(children: [
                  Icon(Icons.playlist_add_rounded, color: glow, size: r.subtitleSize + 2),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Text(
                      'Nueva playlist',
                      style: TextStyle(fontSize: r.subtitleSize + 1, fontWeight: FontWeight.w700, color: onBg),
                    ),
                  ),
                  if (!_saving)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: onBg.withValues(alpha: 0.5), size: r.subtitleSize),
                    ),
                ]),
              ),
              SizedBox(height: r.spacingS),
              // Cover + Name row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover picker
                    GestureDetector(
                      onTap: _pickCover,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: onBg.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedCover != null
                                ? glow.withValues(alpha: 0.4)
                                : onBg.withValues(alpha: 0.1),
                          ),
                        ),
                        child: _selectedCover != null && _selectedCover != '-1'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(13),
                                    gradient: LinearGradient(
                                      colors: _presetColors[int.tryParse(_selectedCover!) ?? 0],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(child: Icon(Icons.music_note_rounded, color: Colors.white.withValues(alpha: 0.7), size: 28)),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      color: onBg.withValues(alpha: 0.35), size: r.subtitleSize + 2),
                                  SizedBox(height: 2),
                                  Text('Foto', style: TextStyle(fontSize: r.footerSize - 3,
                                      color: onBg.withValues(alpha: 0.3))),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(width: r.spacingM),
                    // Name field
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            style: TextStyle(color: onBg, fontSize: r.subtitleSize, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Nombre de la playlist',
                              hintStyle: TextStyle(color: onBg.withValues(alpha: 0.3)),
                              filled: true,
                              fillColor: onBg.withValues(alpha: 0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: onBg.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: onBg.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: glow, width: 1.4),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
                            ),
                          ),
                          SizedBox(height: r.spacingXS),
                          // Privacy info
                          Row(children: [
                            Icon(Icons.lock_outline_rounded, size: r.footerSize, color: onBg.withValues(alpha: 0.35)),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Solo tu puedes ver esta playlist',
                                style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.35)),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spacingM),
              // Offline notice
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: glow.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.offline_bolt_rounded, size: r.footerSize + 2, color: glow.withValues(alpha: 0.7)),
                    SizedBox(width: r.spacingS),
                    Expanded(
                      child: Text(
                        'Solo las canciones descargadas se reproduciran sin conexion',
                        style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.5), height: 1.3),
                      ),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: r.spacingM),
              // Track selector header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                child: Row(children: [
                  Text(
                    'Agregar canciones',
                    style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w700, color: onBg),
                  ),
                  SizedBox(width: r.spacingS),
                  if (_selectedTrackIds.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: glow.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_selectedTrackIds.length}', style: TextStyle(
                          fontSize: r.footerSize - 2, color: glow, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              SizedBox(height: r.spacingS),
              // Track list
              Expanded(
                child: !_loaded
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: glow))
                    : _availableTracks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.music_note_rounded, size: 36, color: onBg.withValues(alpha: 0.2)),
                                SizedBox(height: r.spacingS),
                                Text('No hay canciones disponibles',
                                    style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                            itemCount: _availableTracks.length,
                            itemBuilder: (ctx, i) => _trackTile(_availableTracks[i], onBg, glow, r),
                          ),
              ),
              // Create button
              Padding(
                padding: EdgeInsets.fromLTRB(r.spacingM, r.spacingS, r.spacingM, r.bottomPadding),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving || _nameCtrl.text.trim().isEmpty ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: glow,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Crear playlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackTile(_PickableTrack track, Color onBg, Color glow, Responsive r) {
    final selected = _selectedTrackIds.contains(track.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedTrackIds.remove(track.id);
        } else {
          _selectedTrackIds.add(track.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
        decoration: BoxDecoration(
          color: selected ? glow.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Cover
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: onBg.withValues(alpha: 0.06),
              ),
              child: track.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CoverImage(coverUrl: track.coverUrl, localPath: null),
                    )
                  : Icon(Icons.music_note_rounded, color: onBg.withValues(alpha: 0.3), size: 18),
            ),
            SizedBox(width: r.spacingS),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: r.footerSize, color: onBg, fontWeight: FontWeight.w500)),
                  if (track.artist != null && track.artist!.isNotEmpty)
                    Text(track.artist!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.4))),
                ],
              ),
            ),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? glow : Colors.transparent,
                border: Border.all(
                  color: selected ? glow : onBg.withValues(alpha: 0.25),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static const _presetColors = [
    [Color(0xFF66A6FF), Color(0xFF00B4D8)],
    [Color(0xFF7B2FF7), Color(0xFFFF6B6B)],
    [Color(0xFFFFB347), Color(0xFFFF6B6B)],
    [Color(0xFF4ECDC4), Color(0xFF556270)],
  ];

  void _pickCover() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final r = Responsive(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(r.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            SizedBox(height: r.spacingM),
            Text('Seleccionar portada', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w700, color: onBg)),
            SizedBox(height: r.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _coverOption(-1, onBg, r),
                for (var i = 0; i < _presetColors.length; i++) _coverOption(i, onBg, r),
              ],
            ),
            SizedBox(height: r.bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _coverOption(int index, Color onBg, Responsive r) {
    final selected = _selectedCover == '$index';
    final gradient = index >= 0 && index < _presetColors.length ? _presetColors[index] : null;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCover = '$index');
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: gradient != null ? LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: gradient == null ? onBg.withValues(alpha: 0.06) : null,
          border: Border.all(
            color: selected ? AppColors.greenBright : onBg.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: gradient == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, color: onBg.withValues(alpha: 0.4), size: 20),
                  Text('Sin foto', style: TextStyle(fontSize: 9, color: onBg.withValues(alpha: 0.3))),
                ],
              )
            : Center(child: Icon(Icons.music_note_rounded, color: Colors.white.withValues(alpha: 0.7), size: 24)),
      ),
    );
  }
}

class _PickableTrack {
  final String id, name;
  final String? artist, coverUrl, source;
  const _PickableTrack({required this.id, required this.name, this.artist, this.coverUrl, this.source});
}
