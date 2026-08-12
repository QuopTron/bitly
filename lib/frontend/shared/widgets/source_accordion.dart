import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/source_constants.dart';

/// Compact source selector that opens as a floating glass popup (overlay)
/// anchored under the trigger button.
///
/// Unlike an inline expansion (which would push the feed down), the list is
/// shown in a global [OverlayEntry] so it *overlays* the content below it and
/// is painted above everything — taking little space and never displacing the
/// layout.
class SourceAccordion extends StatefulWidget {
  final Map<String, String> sources;
  final String selectedSource;
  final Color onBg;
  final Color glowColor;
  final ValueChanged<String> onChanged;

  const SourceAccordion({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.onBg,
    required this.glowColor,
    required this.onChanged,
  });

  @override
  State<SourceAccordion> createState() => _SourceAccordionState();
}

class _SourceAccordionState extends State<SourceAccordion> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _entry;
  bool _open = false;

  static const double _headerHeight = 38;
  static const double _rowHeight = 40;

  bool get _isDark => widget.onBg.computeLuminance() > 0.5;

  Color get _glass => _isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.9);

  Color get _glassStrong => _isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.96);

  String get _currentLabel => widget.selectedSource.isEmpty
      ? 'Todas'
      : widget.sources[widget.selectedSource] ?? widget.selectedSource;

  IconData get _currentIcon => widget.selectedSource.isEmpty
      ? Icons.apps
      : (sourceIcons[widget.selectedSource] ?? Icons.music_video);

  @override
  void dispose() {
    _closeOverlay(fromDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _button();
  }

  Widget _button() {
    return Material(
      key: _buttonKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          height: _headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: widget.onBg.withValues(alpha: _isDark ? 0.1 : 0.18),
              width: 0.8,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_glassStrong, _glass],
            ),
            boxShadow: _isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roundIcon(_currentIcon, size: 17),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  _currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: widget.onBg,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: widget.onBg.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle() {
    if (_open) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final buttonRect = box.localToGlobal(Offset.zero) & box.size;
    final size = MediaQuery.of(context).size;
    final pad = 8.0;
    final rows = _rows;
    final panelHeight = math.min(size.height * 0.55,
        rows.length * _rowHeight + (rows.isNotEmpty ? 4 : 0) + 12);
    final availBelow = size.height - buttonRect.bottom;
    final placeBelow = availBelow >= panelHeight + pad + 8;

    final top = placeBelow
        ? buttonRect.bottom + 6
        : math.max(pad, buttonRect.top - panelHeight - 6);

    final entry = OverlayEntry(builder: (context) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeOverlay,
            ),
          ),
          Positioned(
            left: buttonRect.left,
            top: top,
            width: math.max(buttonRect.width, 200),
            child: _FloatingPanel(
              isDark: _isDark,
              onBg: widget.onBg,
              glowColor: widget.glowColor,
              rows: rows,
              selectedSource: widget.selectedSource,
              onSelect: (v) {
                widget.onChanged(v);
                _closeOverlay();
              },
            ),
          ),
        ],
      );
    });

    _entry = entry;
    setState(() => _open = true);
    overlay.insert(entry);
  }

  void _closeOverlay({bool fromDispose = false}) {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
    if (!fromDispose && _open && mounted) {
      setState(() => _open = false);
    }
  }

  List<_SourceRow> get _rows {
    // Preserve the caller's insertion order (search config lists the primary
    // source first, e.g. deezer) instead of re-sorting alphabetically.
    return [
      _SourceRow('', Icons.apps, 'Todas'),
      for (final e in widget.sources.entries)
        _SourceRow(e.key, sourceIcons[e.key] ?? Icons.music_video, e.value),
    ];
  }

  Widget _roundIcon(IconData icon, {required double size, Color? tint}) {
    final c = tint ?? widget.glowColor;
    return Container(
      width: size + 12,
      height: size + 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: 0.3),
            c.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Icon(icon, size: size, color: c.withValues(alpha: 0.95)),
    );
  }
}

class _SourceRow {
  final String value;
  final IconData icon;
  final String label;
  const _SourceRow(this.value, this.icon, this.label);
}

class _FloatingPanel extends StatelessWidget {
  final bool isDark;
  final Color onBg;
  final Color glowColor;
  final List<_SourceRow> rows;
  final String selectedSource;
  final ValueChanged<String> onSelect;

  const _FloatingPanel({
    required this.isDark,
    required this.onBg,
    required this.glowColor,
    required this.rows,
    required this.selectedSource,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -8),
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 16,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: glowColor.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 42,
                        endIndent: 12,
                        color: onBg.withValues(alpha: isDark ? 0.08 : 0.12),
                      ),
                    _row(rows[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(_SourceRow row) {
    final selected = selectedSource == row.value;
    return Material(
      color: selected
          ? glowColor.withValues(alpha: isDark ? 0.16 : 0.2)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(row.value),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _roundIconSmall(row.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: onBg.withValues(alpha: selected ? 1 : 0.78),
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 17,
                  color: selected
                      ? glowColor
                      : onBg.withValues(alpha: isDark ? 0.3 : 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIconSmall(IconData icon) {
    final c = glowColor;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: isDark ? 0.3 : 0.25),
            c.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Icon(icon, size: 15, color: c.withValues(alpha: 0.9)),
    );
  }
}