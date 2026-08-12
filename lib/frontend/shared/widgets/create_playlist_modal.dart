import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../../backend/services/playlist_cubit.dart';

Future<String?> showCreatePlaylistModal(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreatePlaylistSheet(),
  );
}

class _CreatePlaylistSheet extends StatefulWidget {
  const _CreatePlaylistSheet();

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final id = await context.read<PlaylistCubit>().createPlaylist(name);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final loc = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: r.spacingM),
          Text(loc.setup.addToPlaylist,
            style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.w600, color: onBg)),
          SizedBox(height: r.spacingM),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: loc.setup.playlistNameHint,
              filled: true,
              fillColor: onBg.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: onBg.withValues(alpha: 0.12)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
            ),
            style: TextStyle(color: onBg, fontSize: r.footerSize + 1),
            onSubmitted: (_) => _create(),
          ),
          SizedBox(height: r.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: onBg.withValues(alpha: 0.1),
                foregroundColor: onBg,
                padding: EdgeInsets.symmetric(vertical: r.spacingS),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: onBg))
                : Text(loc.setup.continueText, style: TextStyle(fontSize: r.footerSize + 1, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: r.spacingS),
        ]),
      ),
    );
  }
}


