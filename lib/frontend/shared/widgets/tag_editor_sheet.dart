import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../injection.dart';
import '../utils/responsive.dart';
import '../theme/app_colors.dart';

final _log = Logger();

/// Shows a bottom sheet to edit audio file metadata tags.
void showTagEditor(BuildContext context, {required String filePath, String? title, String? artist}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TagEditorSheet(filePath: filePath, title: title, artist: artist),
  );
}

class _TagEditorSheet extends StatefulWidget {
  final String filePath;
  final String? title;
  final String? artist;
  const _TagEditorSheet({required this.filePath, this.title, this.artist});

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fields = {};
  final Map<String, TextEditingController> _ctrls = {};

  static const _editableFields = [
    ('title', 'Title', Icons.title),
    ('artist', 'Artist', Icons.person),
    ('album', 'Album', Icons.album),
    ('albumArtist', 'Album Artist', Icons.person_outline),
    ('genre', 'Genre', Icons.category),
    ('isrc', 'ISRC', Icons.qr_code),
    ('year', 'Year', Icons.calendar_today),
    ('trackNumber', 'Track #', Icons.music_note),
    ('discNumber', 'Disc #', Icons.library_music),
  ];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final backend = sl<BackendService>();
      final json = await backend.readFileMetadata(widget.filePath);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      _fields = parsed.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      // Pre-fill from FeedItem if backend returned empty
      if (_fields['title'] == null || _fields['title']!.isEmpty) {
        _fields['title'] = widget.title ?? '';
      }
      if (_fields['artist'] == null || _fields['artist']!.isEmpty) {
        _fields['artist'] = widget.artist ?? '';
      }
      for (final entry in _editableFields) {
        _ctrls[entry.$1] = TextEditingController(text: _fields[entry.$1] ?? '');
      }
      setState(() => _loading = false);
    } catch (e) {
      _log.w('[tagEditor] load error: $e');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final meta = <String, String>{};
      for (final entry in _editableFields) {
        final val = _ctrls[entry.$1]?.text.trim() ?? '';
        meta[entry.$1] = val;
      }
      final backend = sl<BackendService>();
      final ok = await backend.writeFileMetadata(widget.filePath, meta);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tags guardados'), duration: Duration(seconds: 2)),
        );
      } else {
        setState(() { _saving = false; _error = 'Error al guardar'; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final onBg = isDark ? Colors.white : Colors.black;
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40, height: 4,
              decoration: BoxDecoration(color: onBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(r.spacingXL, r.spacingL, r.spacingXL, r.spacingS),
              child: Row(
                children: [
                  Icon(Icons.edit, size: r.subtitleSize, color: AppColors.primary),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Text('Editar Tags',
                      style: TextStyle(fontSize: r.subtitleSize + 2, fontWeight: FontWeight.bold, color: onBg)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: onBg.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // File name
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
              child: Text(
                widget.filePath.split(RegExp(r'[/\\]')).last,
                style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4)),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: r.spacingM),
            Divider(height: 1, color: onBg.withValues(alpha: 0.1)),
            // Fields
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(r.spacingXL),
                            child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: r.footerSize)),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: r.spacingXL, vertical: r.spacingM),
                          itemCount: _editableFields.length,
                          itemBuilder: (ctx, i) {
                            final (key, label, icon) = _editableFields[i];
                            final ctrl = _ctrls[key];
                            return Padding(
                              padding: EdgeInsets.only(bottom: r.spacingM),
                              child: TextField(
                                controller: ctrl,
                                style: TextStyle(fontSize: r.footerSize + 1, color: onBg),
                                decoration: InputDecoration(
                                  labelText: label,
                                  labelStyle: TextStyle(color: onBg.withValues(alpha: 0.5), fontSize: r.footerSize),
                                  prefixIcon: Icon(icon, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingM),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(r.spacingXL, 0, r.spacingXL, r.spacingXL),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Guardar', style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
