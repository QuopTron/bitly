import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';
import 'package:bitly/utils/app_bar_layout.dart';
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/widgets/settings_group.dart';

class FilesSettingsPage extends ConsumerStatefulWidget {
  const FilesSettingsPage({super.key});

  @override
  ConsumerState<FilesSettingsPage> createState() => _FilesSettingsPageState();
}

class _FilesSettingsPageState extends ConsumerState<FilesSettingsPage> {
  int _androidSdkVersion = 0;
  bool _hasAllFilesAccess = false;

  @override
  void initState() {
    super.initState();
    _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      final hasAccess = await Permission.manageExternalStorage.isGranted;
      if (mounted) {
        setState(() {
          _androidSdkVersion = sdkVersion;
          _hasAllFilesAccess = hasAccess;
        });
      }
    }
  }

  Future<void> _requestAllFilesAccess() async {
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      ref.read(settingsProvider.notifier).setUseAllFilesAccess(true);
      if (mounted) setState(() => _hasAllFilesAccess = true);
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.setupStorageAccessRequired),
            content: Text(context.l10n.allFilesAccessDeniedMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.dialogCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.setupOpenSettings),
              ),
            ],
          ),
        );
        if (shouldOpen == true) await openAppSettings();
      }
    }
  }

  Future<void> _disableAllFilesAccess() async {
    ref.read(settingsProvider.notifier).setUseAllFilesAccess(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.allFilesAccessDisabledMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120 + topPadding,
              collapsedHeight: kToolbarHeight,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = 120 + topPadding;
                  final minHeight = kToolbarHeight + topPadding;
                  final expandRatio =
                      ((constraints.maxHeight - minHeight) /
                              (maxHeight - minHeight))
                          .clamp(0.0, 1.0);
                  final leftPadding = 56 - (32 * expandRatio);
                  return FlexibleSpaceBar(
                    expandedTitleScale: 1.0,
                    titlePadding: EdgeInsets.only(
                      left: leftPadding,
                      bottom: 16,
                    ),
                    title: Text(
                      context.l10n.settingsFiles,
                      style: TextStyle(
                        fontSize: 20 + (8 * expandRatio),
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: SettingsSectionHeader(
                title: context.l10n.setupDownloadLocationTitle,
              ),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.folder_outlined,
                    title: context.l10n.downloadDirectory,
                    subtitle: settings.downloadDirectory.isEmpty
                        ? (Platform.isIOS
                              ? context.l10n.setupAppDocumentsFolder
                              : 'Music/Bitly')
                        : settings.downloadDirectory,
                    onTap: () => _pickDirectory(context, ref),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: SettingsSectionHeader(
                title: context.l10n.sectionFileSettings,
              ),
            ),
            SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.text_fields,
                    title: context.l10n.downloadFilenameFormat,
                    subtitle: settings.filenameFormat,
                    onTap: () => _showFormatEditor(
                      context,
                      ref,
                      settings.filenameFormat,
                    ),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            if (Platform.isAndroid && _androidSdkVersion >= 33) ...[
              SliverToBoxAdapter(
                child: SettingsSectionHeader(
                  title: context.l10n.sectionStorageAccess,
                ),
              ),
              SliverToBoxAdapter(
                child: SettingsGroup(
                  children: [
                    SettingsSwitchItem(
                      icon: Icons.folder_special_outlined,
                      title: context.l10n.allFilesAccess,
                      subtitle: _hasAllFilesAccess
                          ? context.l10n.allFilesAccessEnabledSubtitle
                          : context.l10n.allFilesAccessDisabledSubtitle,
                      value: _hasAllFilesAccess && settings.useAllFilesAccess,
                      onChanged: (value) {
                        if (value) {
                          _requestAllFilesAccess();
                        } else {
                          _disableAllFilesAccess();
                        }
                      },
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.allFilesAccessDescription,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    if (Platform.isIOS) {
      _showIOSDirectoryOptions(context, ref);
    } else if (Platform.isAndroid) {
      _showAndroidDirectoryOptions(context, ref);
    } else {
      String? result;
      try {
        result = await FilePicker.getDirectoryPath();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.snackbarFolderPickerFailed(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      if (result != null && context.mounted) {
        final dir = Directory(result);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        ref.read(settingsProvider.notifier).setDownloadDirectory(result);
      }
    }
  }

  Future<String> _getDefaultAndroidDirectory() async {
    const directMusicPath = '/storage/emulated/0/Music/Bitly';
    try {
      final musicDir = Directory(directMusicPath);
      if (!await musicDir.exists()) await musicDir.create(recursive: true);
      return musicDir.path;
    } catch (_) {}
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final musicDir = Directory(
          '${externalDir.parent.parent.parent.parent.path}/Music/Bitly',
        );
        if (!await musicDir.exists()) await musicDir.create(recursive: true);
        return musicDir.path;
      }
    } catch (_) {}
    final appDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${appDir.path}/Bitly');
    if (!await fallbackDir.exists()) await fallbackDir.create(recursive: true);
    return fallbackDir.path;
  }

  void _showAndroidDirectoryOptions(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.read(settingsProvider);
    final isSafMode =
        settings.storageMode == 'saf' && settings.downloadTreeUri.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                context.l10n.setupDownloadLocationTitle,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                context.l10n.downloadLocationSubtitle,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.folder_special, color: colorScheme.primary),
              title: Text(context.l10n.storageModeAppFolder),
              subtitle: Text(context.l10n.storageModeAppFolderSubtitle),
              trailing: !isSafMode ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.pop(ctx);
                final defaultDir = await _getDefaultAndroidDirectory();
                final notifier = ref.read(settingsProvider.notifier);
                notifier.setStorageMode('app');
                notifier.setDownloadDirectory(defaultDir);
                notifier.setDownloadTreeUri('');
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_open, color: colorScheme.primary),
              title: Text(context.l10n.storageModeSaf),
              subtitle: Text(context.l10n.storageModeSafSubtitle),
              trailing: isSafMode ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.pop(ctx);
                final result = await PlatformBridge.pickSafTree();
                if (result != null) {
                  final treeUri = result['tree_uri'] as String? ?? '';
                  final displayName = result['display_name'] as String? ?? '';
                  if (treeUri.isNotEmpty) {
                    ref.read(settingsProvider.notifier).setStorageMode('saf');
                    ref
                        .read(settingsProvider.notifier)
                        .setDownloadTreeUri(
                          treeUri,
                          displayName: displayName.isNotEmpty
                              ? displayName
                              : treeUri,
                        );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showIOSDirectoryOptions(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                context.l10n.setupDownloadLocationTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                context.l10n.setupDownloadLocationIosMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.folder_special, color: colorScheme.primary),
              title: Text(context.l10n.setupAppDocumentsFolder),
              subtitle: Text(context.l10n.setupAppDocumentsFolderSubtitle),
              trailing: Icon(Icons.check_circle, color: colorScheme.primary),
              onTap: () async {
                final dir = await getApplicationDocumentsDirectory();
                ref
                    .read(settingsProvider.notifier)
                    .setDownloadDirectory(dir.path);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.cloud, color: colorScheme.onSurfaceVariant),
              title: Text(context.l10n.setupChooseFromFiles),
              subtitle: Text(context.l10n.setupChooseFromFilesSubtitle),
              onTap: () async {
                Navigator.pop(ctx);
                if (Platform.isIOS) {
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                }
                String? result;
                try {
                  result = await FilePicker.getDirectoryPath();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          ctx.l10n.snackbarFolderPickerFailed(e.toString()),
                        ),
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                  return;
                }
                if (result != null) {
                  if (Platform.isIOS) {
                    final validation = validateIosPath(result);
                    if (!validation.isValid) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              validation.errorReason ??
                                  context.l10n.setupIcloudNotSupported,
                            ),
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                      return;
                    }

                    final bookmark =
                        await PlatformBridge.createIosBookmarkFromPath(result);
                    if (bookmark == null || bookmark.isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              ctx.l10n.snackbarFolderPickerFailed(
                                'Could not keep access to the selected folder',
                              ),
                            ),
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                      return;
                    }

                    ref
                        .read(settingsProvider.notifier)
                        .setDownloadDirectory(result, iosBookmark: bookmark);
                    return;
                  }
                  ref
                      .read(settingsProvider.notifier)
                      .setDownloadDirectory(result);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.setupIosEmptyFolderWarning,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFormatEditor(
    BuildContext context,
    WidgetRef ref,
    String current, {
    void Function(String)? onSave,
    String? title,
    String? description,
  }) {
    final controller = TextEditingController(text: current);
    final colorScheme = Theme.of(context).colorScheme;

    final basicTags = [
      '{artist}',
      '{title}',
      '{album}',
      '{track}',
      '{year}',
      '{date}',
      '{disc}',
    ];
    final advancedTags = [
      '{track_raw}',
      '{track:02}',
      '{track:1}',
      '{date:%Y}',
      '{date:%Y-%m-%d}',
      '{disc_raw}',
      '{disc:02}',
    ];
    var showAdvancedTags = RegExp(
      r'\{(?:track_raw|disc_raw|track:\d+|disc:\d+|date:[^}]+)\}',
      caseSensitive: false,
    ).hasMatch(current);

    void insertTag(String tag) {
      final text = controller.text;
      final selection = controller.selection;
      final start = selection.start >= 0 ? selection.start : text.length;
      final end = selection.end >= 0 ? selection.end : text.length;
      String insertion = tag;
      if (start > 0) {
        final before = text.substring(0, start);
        if (!before.trim().endsWith('-')) {
          insertion = ' - $tag';
        } else if (before.trim().endsWith('-') && !before.endsWith(' ')) {
          insertion = ' $tag';
        }
      }
      final newText = text.replaceRange(start, end, insertion);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + insertion.length),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      title ?? context.l10n.filenameFormat,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description ??
                          context.l10n.downloadFilenameDescription(
                            '{album}',
                            '{artist}',
                            '{date}',
                            '{disc}',
                            '{title}',
                            '{track}',
                            '{year}',
                          ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: '{artist} - {title}',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.downloadFilenameInsertTag,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: basicTags.map((tag) {
                        return ActionChip(
                          label: Text(tag),
                          onPressed: () => insertTag(tag),
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: showAdvancedTags,
                      onChanged: (value) =>
                          setModalState(() => showAdvancedTags = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.filenameShowAdvancedTags),
                      subtitle: Text(
                        context.l10n.filenameShowAdvancedTagsDescription,
                      ),
                    ),
                    if (showAdvancedTags) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: advancedTags.map((tag) {
                          return ActionChip(
                            label: Text(tag),
                            onPressed: () => insertTag(tag),
                            backgroundColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(context.l10n.dialogCancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              final save =
                                  onSave ??
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setFilenameFormat;
                              save(controller.text);
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(context.l10n.dialogSave),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
}

}
