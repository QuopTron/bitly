import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitly/l10n/l10n.dart';
import 'package:bitly/providers/extension_provider.dart';
import 'package:bitly/providers/playback_queue_provider.dart';
import 'package:bitly/providers/store_provider.dart';
import 'package:bitly/services/library/covers/cover_cache_manager.dart';
import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/widgets/animation_utils.dart';
import 'package:bitly/widgets/glass_container.dart';
import 'package:bitly/widgets/settings_group.dart';

void showExtensionStoreModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.95,
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (_) => const _ExtensionStoreFuturisticModal(),
  );
}

class _ExtensionStoreFuturisticModal extends ConsumerWidget {
  const _ExtensionStoreFuturisticModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentCover = ref.watch(
      playbackQueueProvider.select(
        (q) => q.currentIndex >= 0 && q.currentIndex < q.items.length
            ? q.items[q.currentIndex].track.coverUrl
            : null,
      ),
    );

    return _ExtensionStoreGlassContent(coverUrl: currentCover, colorScheme: colorScheme);
  }
}

class _ExtensionStoreGlassContent extends StatefulWidget {
  final String? coverUrl;
  final ColorScheme colorScheme;

  const _ExtensionStoreGlassContent({required this.coverUrl, required this.colorScheme});

  @override
  State<_ExtensionStoreGlassContent> createState() => _ExtensionStoreGlassContentState();
}

class _ExtensionStoreGlassContentState extends State<_ExtensionStoreGlassContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget? coverWidget;

    if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      if (widget.coverUrl!.startsWith('http://') || widget.coverUrl!.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: widget.coverUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        coverWidget = Image.file(
          File(widget.coverUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return Container(
      margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      height: MediaQuery.of(context).size.height * 0.85,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppTheme.modalBlurSigma,
            sigmaY: AppTheme.modalBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.modalGradientDark : AppTheme.modalGradientLight,
              border: Border.all(
                color: isDark ? AppTheme.modalBorderDark : AppTheme.modalBorderLight,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: isDark ? AppTheme.primaryDark.withOpacity(0.08) : AppTheme.primaryLight.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        isDark ? AppTheme.glowDark : AppTheme.glowLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? AppTheme.primaryDark.withOpacity(0.4) : AppTheme.primaryLight.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Extensiones y Tienda',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 22,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: isDark ? AppTheme.primaryDark.withOpacity(0.3) : AppTheme.primaryLight.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.glassBorderDark : AppTheme.glassBorderLight,
                        width: 1,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      indicator: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(12),
                      tabs: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text('Tienda'),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.extension_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text('Extensiones'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _StoreTab(colorScheme: colorScheme),
                      _InstalledTab(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Store Tab
class _StoreTab extends ConsumerStatefulWidget {
  final ColorScheme colorScheme;

  const _StoreTab({required this.colorScheme});

  @override
  ConsumerState<_StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends ConsumerState<_StoreTab> {
  final _searchController = TextEditingController();
  bool _isStoreInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeStore());
  }

  Future<void> _initializeStore() async {
    if (_isStoreInitialized) return;
    _isStoreInitialized = true;

    final cacheDir = await getApplicationCacheDirectory();
    if (!mounted) return;

    await ref.read(storeProvider.notifier).initialize(cacheDir.path);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeProvider);
    final colorScheme = widget.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final extensions = storeState.extensions;
    final filtered = storeState.filteredExtensions;
    final isLoading = storeState.isLoading;
    final error = storeState.error;
    final downloadingId = storeState.downloadingId;
    final updatesCount = storeState.updatesAvailableCount;
    final hasRegistryUrl = storeState.hasRegistryUrl;

    if (_searchController.text != storeState.searchQuery) {
      _searchController.value = TextEditingValue(
        text: storeState.searchQuery,
        selection: TextSelection.collapsed(offset: storeState.searchQuery.length),
      );
    }

    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: NeonCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar extensiones...',
                  prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                  suffixIcon: storeState.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(storeProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) => ref.read(storeProvider.notifier).setSearchQuery(v),
              ),
            ),
          ),
        ),

        // Category chips
        if (hasRegistryUrl && !isLoading && error == null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StoreCategoryChip(
                    label: 'Todas',
                    icon: Icons.apps,
                    isSelected: storeState.selectedCategory == null,
                    onTap: () => ref.read(storeProvider.notifier).setCategory(null),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _StoreCategoryChip(
                    label: 'Descarga',
                    icon: Icons.download_outlined,
                    isSelected: storeState.selectedCategory == 'download',
                    onTap: () => ref.read(storeProvider.notifier).setCategory('download'),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _StoreCategoryChip(
                    label: 'Metadata',
                    icon: Icons.label_outline,
                    isSelected: storeState.selectedCategory == 'metadata',
                    onTap: () => ref.read(storeProvider.notifier).setCategory('metadata'),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _StoreCategoryChip(
                    label: 'Utilidad',
                    icon: Icons.build_outlined,
                    isSelected: storeState.selectedCategory == 'utility',
                    onTap: () => ref.read(storeProvider.notifier).setCategory('utility'),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _StoreCategoryChip(
                    label: 'Letras',
                    icon: Icons.lyrics_outlined,
                    isSelected: storeState.selectedCategory == 'lyrics',
                    onTap: () => ref.read(storeProvider.notifier).setCategory('lyrics'),
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ),

        // Setup repo state
        if (!hasRegistryUrl)
          SliverFillRemaining(
            child: _buildSetupRepo(colorScheme, error, context),
          )
        else if (isLoading && extensions.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null && extensions.isEmpty)
          SliverFillRemaining(
            child: _buildError(error, colorScheme, context),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            child: _buildEmpty(
              hasFilters: storeState.searchQuery.isNotEmpty || storeState.selectedCategory != null,
              colorScheme: colorScheme,
              context: context,
            ),
          )
        else ...[
          // Count + Update All
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NeonCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.extension, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'extensión' : 'extensiones'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (updatesCount > 0)
                      _GlassButton(
                        icon: Icons.update,
                        label: 'Actualizar todas ($updatesCount)',
                        onPressed: downloadingId != null ? null : () => _updateAll(context),
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Extension list
          SliverToBoxAdapter(
            child: NeonCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              padding: const EdgeInsets.all(8),
              child: SettingsGroup(
                margin: EdgeInsets.zero,
                children: filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ext = entry.value;
                  return _StoreExtensionItem(
                    extension: ext,
                    isDownloading: downloadingId == ext.id,
                    showDivider: index < filtered.length - 1,
                    colorScheme: colorScheme,
                    onInstall: () => _installExtension(ext, context),
                    onUpdate: () => _updateExtension(ext, context),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSetupRepo(ColorScheme colorScheme, String? error, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: NeonCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dns_outlined, size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Configurar Repositorio',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  hintText: 'URL del registry.json',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: TextStyle(color: colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _setDefaultRepo(),
                icon: const Icon(Icons.check),
                label: const Text('Usar repositorio por defecto'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setDefaultRepo() {
    ref.read(storeProvider.notifier).setRegistryUrl(
      'https://raw.githubusercontent.com/spotiflacapp/SpotiFLAC-Extension/main/registry.json',
    );
  }

  Widget _buildError(String error, ColorScheme colorScheme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: NeonCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(storeProvider.notifier).refresh(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty({required bool hasFilters, required ColorScheme colorScheme, required BuildContext context}) {
    return Center(
      child: NeonCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.extension_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'Sin resultados' : 'No hay extensiones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _installExtension(StoreExtension ext, BuildContext context) async {
    final tempDir = await getTemporaryDirectory();
    final appDir = await getApplicationDocumentsDirectory();
    final extensionsDir = '${appDir.path}/extensions';

    final success = await ref
        .read(storeProvider.notifier)
        .installExtension(ext.id, tempDir.path, extensionsDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : widget.colorScheme.error),
              const SizedBox(width: 8),
              Text(success ? '${ext.displayName} instalada' : 'Error al instalar ${ext.displayName}'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.95),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _updateExtension(StoreExtension ext, BuildContext context) async {
    final tempDir = await getTemporaryDirectory();

    final success = await ref
        .read(storeProvider.notifier)
        .updateExtension(ext.id, tempDir.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : widget.colorScheme.error),
              const SizedBox(width: 8),
              Text(success
                  ? '${ext.displayName} actualizada a v${ext.version}'
                  : 'Error al actualizar ${ext.displayName}'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.95),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _updateAll(BuildContext context) async {
    final tempDir = await getTemporaryDirectory();

    final count = await ref
        .read(storeProvider.notifier)
        .updateAll(tempDir.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(count > 0 ? Icons.check_circle : Icons.info_outline,
                color: count > 0 ? Colors.green : widget.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(count > 0
                  ? '$count extensión${count == 1 ? '' : 'es'} actualizada${count == 1 ? '' : 's'}'
                  : 'No hay actualizaciones disponibles'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.95),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

// Installed Extensions Tab
class _InstalledTab extends ConsumerStatefulWidget {
  final ColorScheme colorScheme;

  const _InstalledTab({required this.colorScheme});

  @override
  ConsumerState<_InstalledTab> createState() => _InstalledTabState();
}

class _InstalledTabState extends ConsumerState<_InstalledTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initExtensions());
  }

  Future<void> _initExtensions() async {
    final extState = ref.read(extensionProvider);
    if (!extState.isInitialized) {
      final appDir = await getApplicationDocumentsDirectory();
      final extensionsDir = '${appDir.path}/extensions';
      final dataDir = '${appDir.path}/extension_data';

      await Directory(extensionsDir).create(recursive: true);
      await Directory(dataDir).create(recursive: true);

      await ref
          .read(extensionProvider.notifier)
          .initialize(extensionsDir, dataDir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extState = ref.watch(extensionProvider);
    final colorScheme = widget.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        if (extState.extensions.isEmpty && !extState.isLoading)
          SliverFillRemaining(
            child: Center(
              child: NeonCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension_off, size: 48,
                      color: colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No hay extensiones instaladas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Ve a la tienda para instalar extensiones',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NeonCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16,
                      color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${extState.extensions.length} instalada${extState.extensions.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: NeonCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              padding: const EdgeInsets.all(8),
              child: SettingsGroup(
                margin: EdgeInsets.zero,
                children: extState.extensions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ext = entry.value;
                  final isEnabled = ext.enabled;
                  return _InstalledExtensionItem(
                    extension: ext,
                    isEnabled: isEnabled,
                    showDivider: index < extState.extensions.length - 1,
                    colorScheme: colorScheme,
                    onToggle: (enabled) => ref
                        .read(extensionProvider.notifier)
                        .setExtensionEnabled(ext.id, enabled),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        // Import button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => _importExtension(context),
              icon: const Icon(Icons.add),
              label: const Text('Importar extensión'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _importExtension(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final selectedPaths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.toLowerCase().endsWith('.Bitly-ext'))
        .toList();

    if (selectedPaths.isEmpty) return;

    final installResult = await ref
        .read(extensionProvider.notifier)
        .installExtensions(selectedPaths);

    if (mounted) {
      final success = installResult.installed > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : widget.colorScheme.error),
              const SizedBox(width: 8),
              Text(success
                  ? '${installResult.installed} extensión${installResult.installed == 1 ? '' : 'es'} importada${installResult.installed == 1 ? '' : 's'}'
                  : 'Error al importar'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.95),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

// Category Chip
class _StoreCategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _StoreCategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
        ),
        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        avatar: isSelected
            ? Icon(
                Icons.check_circle,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              )
            : null,
      ),
    );
  }
}

// Glass Button
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}

// Store Extension Item
class _StoreExtensionItem extends StatelessWidget {
  final StoreExtension extension;
  final bool isDownloading;
  final bool showDivider;
  final ColorScheme colorScheme;
  final VoidCallback onInstall;
  final VoidCallback onUpdate;

  const _StoreExtensionItem({
    required this.extension,
    required this.isDownloading,
    required this.showDivider,
    required this.colorScheme,
    required this.onInstall,
    required this.onUpdate,
  });

  IconData _categoryIcon() {
    switch (extension.category) {
      case 'metadata': return Icons.label_outline;
      case 'download': return Icons.download_outlined;
      case 'utility': return Icons.build_outlined;
      case 'lyrics': return Icons.lyrics_outlined;
      case 'integration': return Icons.link;
      default: return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onTap: extension.isInstalled ? null : onInstall,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: extension.isInstalled
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(),
                  color: extension.isInstalled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            extension.displayName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v${extension.version}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extension.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isDownloading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (extension.hasUpdate)
                FilledButton.tonal(
                  onPressed: onUpdate,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Actualizar',
                    style: TextStyle(fontSize: 12,
                      color: Colors.orange.shade300)),
                )
              else if (extension.isInstalled)
                Icon(Icons.check_circle, color: Colors.green, size: 24)
              else
                FilledButton(
                  onPressed: onInstall,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Instalar'),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 74,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}

// Installed Extension Item
class _InstalledExtensionItem extends StatelessWidget {
  final Extension extension;
  final bool isEnabled;
  final bool showDivider;
  final ColorScheme colorScheme;
  final ValueChanged<bool> onToggle;

  const _InstalledExtensionItem({
    required this.extension,
    required this.isEnabled,
    required this.showDivider,
    required this.colorScheme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.extension,
                  color: isEnabled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extension.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isEnabled ? 'Activo' : 'Desactivado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: onToggle,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: colorScheme.primary,
                inactiveThumbColor: colorScheme.surfaceContainerHighest,
                inactiveTrackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 64,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}
