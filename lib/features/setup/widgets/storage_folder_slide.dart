import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
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
      if (!bitlyDir.existsSync()) {
        bitlyDir.createSync(recursive: true);
      }
      if (mounted) {
        setState(() {
          _selectedPath = bitlyDir.path;
          _usingDefault = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFolder() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: widget.loc.setup.storageTitle,
      );
      if (result != null && mounted) {
        setState(() {
          _selectedPath = result;
          _usingDefault = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar carpeta: $e',
              style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _useDefault() async {
    setState(() => _picking = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bitlyDir = Directory('${dir.path}/Bitly');
      if (!bitlyDir.existsSync()) {
        bitlyDir.createSync(recursive: true);
      }
      if (mounted) {
        setState(() {
          _selectedPath = bitlyDir.path;
          _usingDefault = true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _finishSetup() async {
    if (_selectedPath == null) return;
    try {
      // Persist download path via SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_path', _selectedPath!);
      if (mounted) {
        context.read<SetupBloc>().add(const NextSlide());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;

    return Padding(
      key: const ValueKey('storageFolder'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        SizedBox(height: widget.r.spacingM),
        _header(onBg),
        SizedBox(height: widget.r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16,
            borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: widget.r.spacingL),
              _folderPreview(onBg, glowColor),
              SizedBox(height: widget.r.spacingL),
              _optionCards(onBg, glowColor),
              const Spacer(),
              _continueButton(onBg, glowColor, saving),
              SizedBox(height: widget.r.spacingL),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _header(Color onBg) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(widget.r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.folder_outlined,
          size: widget.r.titleSize * 1.1,
          color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: widget.r.spacingS),
      Text(widget.loc.setup.storageTitle,
        style: TextStyle(
          fontSize: widget.r.titleSize,
          fontWeight: FontWeight.bold,
          color: onBg,
          letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
        child: Text(widget.loc.setup.storageDesc,
          style: TextStyle(
            fontSize: widget.r.footerSize,
            color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }

  // ── Folder preview ────────────────────────────────────────────

  Widget _folderPreview(Color onBg, Color glowColor) {
    final hasPath = _selectedPath != null;
    final displayPath = _usingDefault
        ? widget.loc.setup.storageDefaultPath
        : _selectedPath ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingL),
      child: GlassContainer(
        borderRadius: 14,
        borderColor: hasPath
            ? glowColor.withValues(alpha: 0.3)
            : onBg.withValues(alpha: 0.08),
        bgColor: hasPath
            ? glowColor.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.all(widget.r.spacingM),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(widget.r.spacingS),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasPath
                  ? glowColor.withValues(alpha: 0.15)
                  : onBg.withValues(alpha: 0.04),
            ),
            child: Icon(
              hasPath ? Icons.folder : Icons.folder_open,
              size: widget.r.titleSize,
              color: hasPath ? glowColor : onBg.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(width: widget.r.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPath ? widget.loc.setup.storageSelected : 'Ninguna carpeta',
                  style: TextStyle(
                    fontSize: widget.r.footerSize,
                    fontWeight: FontWeight.w600,
                    color: hasPath ? glowColor : onBg.withValues(alpha: 0.3),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  displayPath,
                  style: TextStyle(
                    fontSize: widget.r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_picking)
            SizedBox(
              width: widget.r.footerSize,
              height: widget.r.footerSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: glowColor,
              ),
            ),
        ]),
      ),
    );
  }

  // ── Option cards ──────────────────────────────────────────────

  Widget _optionCards(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingL),
      child: Column(children: [
        _optionCard(
          icon: Icons.create_new_folder,
          title: widget.loc.setup.storageChoose,
          subtitle: widget.loc.setup.storageChooseDesc,
          selected: !_usingDefault && _selectedPath != null,
          onTap: _pickFolder,
          disabled: _picking,
          onBg: onBg,
          glowColor: glowColor,
        ),
        SizedBox(height: widget.r.spacingS),
        _optionCard(
          icon: Icons.home_outlined,
          title: widget.loc.setup.storageDefault,
          subtitle: widget.loc.setup.storageDefaultDesc,
          selected: _usingDefault,
          onTap: _useDefault,
          disabled: _picking,
          onBg: onBg,
          glowColor: glowColor,
        ),
      ]),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required bool disabled,
    required Color onBg,
    required Color glowColor,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? glowColor.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? glowColor.withValues(alpha: 0.4)
                : onBg.withValues(alpha: 0.08),
            width: selected ? 1.2 : 0.6,
          ),
        ),
        padding: EdgeInsets.all(widget.r.spacingM),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(widget.r.spacingXS),
            decoration: BoxDecoration(
              color: selected
                  ? glowColor.withValues(alpha: 0.12)
                  : onBg.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
              size: widget.r.subtitleSize,
              color: selected ? glowColor : onBg.withValues(alpha: 0.4)),
          ),
          SizedBox(width: widget.r.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontSize: widget.r.footerSize + 1,
                    fontWeight: FontWeight.w600,
                    color: selected ? glowColor : onBg),
                ),
                SizedBox(height: 2),
                Text(subtitle,
                  style: TextStyle(
                    fontSize: widget.r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle,
              size: widget.r.footerSize + 2,
              color: glowColor),
        ]),
      ),
    );
  }

  // ── Continue button ───────────────────────────────────────────

  Widget _continueButton(Color onBg, Color glowColor, bool saving) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        width: double.infinity,
        height: widget.r.continueButtonHeight,
        child: GlassButton(
          label: widget.loc.setup.continueText,
          onPressed: _selectedPath != null && !saving ? _finishSetup : null,
          isLoading: saving,
          height: widget.r.continueButtonHeight,
          accent: glowColor,
        ),
      ),
    );
  }
}
