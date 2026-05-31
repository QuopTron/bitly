import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/services/cache/video_cache_manager.dart';
import 'dart:io';

class VideoCacheSettings extends ConsumerStatefulWidget {
  const VideoCacheSettings({super.key});

  @override
  ConsumerState<VideoCacheSettings> createState() => _VideoCacheSettingsState();
}

class _VideoCacheSettingsState extends ConsumerState<VideoCacheSettings> {
  final VideoCacheManager _cacheManager = VideoCacheManager();
  bool _isLoading = true;
  int _currentSize = 0;
  int _maxSize = 0;
  List<CachedVideoInfo> _cachedVideos = [];

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    await _cacheManager.init();
    
    setState(() {
      _currentSize = _cacheManager.getCurrentCacheSize() as int;
      _maxSize = _cacheManager.getMaxCacheSize() as int;
      _isLoading = false;
    });
    
    _loadCachedVideos();
  }

  Future<void> _loadCachedVideos() async {
    final videos = await _cacheManager.getCachedVideos();
    setState(() {
      _cachedVideos = videos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Caché de Video'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCacheStats(colorScheme),
                const SizedBox(height: 24),
                _buildMaxSizeSlider(colorScheme),
                const SizedBox(height: 24),
                _buildClearCacheButton(colorScheme),
                 const SizedBox(height: 24),
                _buildCachedVideosList(colorScheme),
              ],
            ),
    );
  }

  Widget _buildCacheStats(ColorScheme colorScheme) {
    final currentSizeMB = (_currentSize / (1024 * 1024)).toStringAsFixed(2);
    final maxSizeMB = (_maxSize / (1024 * 1024)).toStringAsFixed(2);
    final usagePercentage = (_currentSize / _maxSize * 100).clamp(0, 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Almacenamiento de Caché', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            )),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: usagePercentage / 100,
               backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercentage > 90 ? Colors.red : colorScheme.primary
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${currentSizeMB} MB / ${maxSizeMB} MB', style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                )),
                Text('${usagePercentage.toStringAsFixed(1)}%', style: TextStyle(
                  color: usagePercentage > 90 ? Colors.red : colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxSizeSlider(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Límite Máximo de Caché', style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            )),
             const SizedBox(height: 8),
            Text('${(_maxSize / (1024 * 1024)).toStringAsFixed(0)} MB', style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            )),
            Slider(
              value: _maxSize.toDouble(),
              min: 100 * 1024 * 1024, // 100MB
              max: 2000 * 1024 * 1024, // 2GB
              divisions: 19,
              label: '${(_maxSize / (1024 * 1024)).toStringAsFixed(0)} MB',
              onChanged: (value) async {
                await _cacheManager.setMaxCacheSize(value.toInt());
                await _loadCacheInfo();
              },
              activeColor: colorScheme.primary,
               inactiveColor: colorScheme.surfaceContainerHighest,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('100MB', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                Text('2GB', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearCacheButton(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Administrar Almacenamiento', style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            )),
            const SizedBox(height: 8),
            Text('Videos cacheados: ${_cachedVideos.length}', style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            )),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Limpiar caché'),
                    content: const Text('¿Estás seguro de que quieres eliminar todos los videos cacheados?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _cacheManager.clearCache();
                  await _loadCacheInfo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Caché limpiado correctamente')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('LIMPIAR TODO EL CACHÉ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedVideosList(ColorScheme colorScheme) {
    if (_cachedVideos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No hay videos cacheados',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Videos Cacheados (${_cachedVideos.length})', style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            )),
            const SizedBox(height: 8),
            ..._cachedVideos.map((video) => _buildVideoListItem(video, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoListItem(CachedVideoInfo video, ColorScheme colorScheme) {
    return ListTile(
      title: Text(video.name, style: TextStyle(color: colorScheme.onSurface)),
      subtitle: Text('${video.formattedSize} • ${_formatDate(video.lastAccessed)}', 
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: colorScheme.onSurfaceVariant),
        onPressed: () async {
          final file = File(video.path);
          await file.delete();
          await _loadCacheInfo();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} días atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} horas atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutos atrás';
    } else {
      return 'Justo ahora';
    }
  }
}