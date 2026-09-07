import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';
import '../models/feed_models.dart';
import 'cover_image.dart';

/// TikTok-style "shared with you" overlay for deep link opens.
class SharedOverlay extends StatefulWidget {
  final String? type;
  final String? id;
  final String? query;
  final VoidCallback onDismiss;
  final VoidCallback onPlay;

  const SharedOverlay({
    super.key,
    this.type,
    this.id,
    this.query,
    required this.onDismiss,
    required this.onPlay,
  });

  @override
  State<SharedOverlay> createState() => _SharedOverlayState();
}

class _SharedOverlayState extends State<SharedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  FeedItem? _foundItem;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.ease);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _resolveItem();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveItem() async {
    // Use the query as the item name for the overlay display
    setState(() {
      _foundItem = FeedItem(
        id: widget.id ?? '',
        type: widget.type ?? 'track',
        name: widget.query ?? 'Cancion compartida',
        source: '',
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final glow = AppColors.greenBright;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.95),
              body: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Text(
                      'Te compartieron',
                      style: TextStyle(
                        fontSize: r.subtitleSize - 2,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: r.spacingL),
                    // Cover placeholder with glow
                    if (_loading)
                      SizedBox(
                        width: 180, height: 180,
                        child: Center(child: CircularProgressIndicator(color: glow, strokeWidth: 2)),
                      )
                    else
                      Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: glow.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _foundItem?.coverUrl != null
                              ? CoverImage(coverUrl: _foundItem!.coverUrl, localPath: null)
                              : Container(
                                  color: glow.withValues(alpha: 0.15),
                                  child: Icon(_typeIcon(), size: 64, color: glow),
                                ),
                        ),
                      ),
                    SizedBox(height: r.spacingL),
                    Text(
                      _foundItem?.name ?? 'Buscando...',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.titleSize + 2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (_foundItem?.artists != null && _foundItem!.artists!.isNotEmpty) ...[
                      SizedBox(height: r.spacingXS),
                      Text(
                        _foundItem!.artists!,
                        style: TextStyle(
                          fontSize: r.subtitleSize,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    SizedBox(height: r.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: glow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: glow.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _typeLabel(),
                        style: TextStyle(fontSize: r.footerSize - 1, color: glow, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(flex: 2),
                    // Play button
                    GestureDetector(
                      onTap: widget.onPlay,
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: glow,
                          boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: r.spacingL),
                    // Omitir button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          'Omitir',
                          style: TextStyle(
                            fontSize: r.subtitleSize - 1,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: r.spacingXL),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _typeIcon() {
    switch (widget.type) {
      case 'album': return Icons.album_rounded;
      case 'artist': return Icons.person_rounded;
      case 'playlist': return Icons.queue_music_rounded;
      default: return Icons.music_note_rounded;
    }
  }

  String _typeLabel() {
    switch (widget.type) {
      case 'album': return 'Album';
      case 'artist': return 'Artista';
      case 'playlist': return 'Playlist';
      default: return 'Cancion';
    }
  }
}
