import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../../backend/cache/settings_cache.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../injection.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import 'storage_folder_option_card.dart';
import 'storage_folder_preview.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class StorageFolderSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const StorageFolderSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<StorageFolderSlide> createState() => _StorageFolderSlideState();
}

class _StorageFolderSlideState extends State<StorageFolderSlide> {
  String? _selectedPath;
  bool _usingDefault = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _initDefault();
  }

  Future<void> _initDefault() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bitlyDir = Directory('${dir.path}/Bitly');
      if (!bitlyDir.existsSync()) bitlyDir.createSync(recursive: true);
      if (mounted) setState(() { _selectedPath = bitlyDir.path; _usingDefault = true; });
    } catch (_) {}
  }

  Future<void> _pickFolder() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.getDirectoryPath(dialogTitle: widget.loc.setup.storageTitle);
      if (result != null && mounted) setState(() { _selectedPath = result; _usingDefault = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar carpeta: $e',
            style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.withValues(alpha: 0.8)));
      }
    } finally { if (mounted) setState(() => _picking = false); }
  }

  Future<void> _useDefault() async {
    setState(() => _picking = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bitlyDir = Directory('${dir.path}/Bitly');
      if (!bitlyDir.existsSync()) bitlyDir.createSync(recursive: true);
      if (mounted) setState(() { _selectedPath = bitlyDir.path; _usingDefault = true; });
    } catch (_) {}
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _finishSetup() async {
    if (_selectedPath == null) return;
    try {
      await sl<SettingsCache>().saveDownloadPath(_selectedPath!);
      // Sync to Go's in-memory config
      try { await sl<BackendService>().syncDownloadDir(_selectedPath!); } catch (_) {}
      if (mounted) context.read<SetupBloc>().add(const NextSlide());
    } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;
    final loc = widget.loc;
    final r = widget.r;

    return Padding(
      key: const ValueKey('storageFolder'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(children: [
        SizedBox(height: r.spacingM),
        _header(onBg, loc, r),
        SizedBox(height: r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16, borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: r.spacingL),
              StorageFolderPreview(
                hasPath: _selectedPath != null,
                usingDefault: _usingDefault,
                picking: _picking,
                displayPath: _usingDefault ? loc.setup.storageDefaultPath : (_selectedPath ?? ''),
                selectedLabel: loc.setup.storageSelected,
                noFolderLabel: loc.setup.noFolder,
                onBg: onBg, glowColor: glowColor,
              ),
              SizedBox(height: r.spacingL),
              _optionCards(onBg, glowColor, loc, r),
              const Spacer(),
              _continueButton(onBg, glowColor, saving, loc, r),
              SizedBox(height: r.spacingL),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _header(Color onBg, AppLocalizations loc, Responsive r) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8)),
        child: Icon(Icons.folder_outlined, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: r.spacingS),
      Text(loc.setup.storageTitle,
        style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(loc.setup.storageDesc,
          style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5)), textAlign: TextAlign.center)),
    ]);
  }

  Widget _optionCards(Color onBg, Color glowColor, AppLocalizations loc, Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingL),
      child: Column(children: [
        StorageOptionCard(
          icon: Icons.create_new_folder, title: loc.setup.storageChoose,
          subtitle: loc.setup.storageChooseDesc, selected: !_usingDefault && _selectedPath != null,
          onTap: _pickFolder, disabled: _picking, onBg: onBg, glowColor: glowColor),
        SizedBox(height: r.spacingS),
        StorageOptionCard(
          icon: Icons.home_outlined, title: loc.setup.storageDefault,
          subtitle: loc.setup.storageDefaultDesc, selected: _usingDefault,
          onTap: _useDefault, disabled: _picking, onBg: onBg, glowColor: glowColor),
      ]),
    );
  }

  Widget _continueButton(Color onBg, Color glowColor, bool saving, AppLocalizations loc, Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: SizedBox(width: double.infinity, height: r.continueButtonHeight,
        child: GlassButton(
          label: loc.setup.continueText,
          onPressed: _selectedPath != null && !saving ? _finishSetup : null,
          isLoading: saving, height: r.continueButtonHeight, accent: glowColor)),
    );
  }
}

