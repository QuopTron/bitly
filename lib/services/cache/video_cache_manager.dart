import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class VideoCacheManager {
  static const String _cacheDirName = 'videos';
  static const String _prefsKey = 'video_cache_stats';
  static const int _defaultMaxSizeMB = 500; // 500MB por defecto
  
  late Directory _cacheDir;
  late SharedPreferences _prefs;
  bool _initialized = false;
  
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  
  factory VideoCacheManager() => _instance;
  
  VideoCacheManager._internal();
  
  Future<void> init() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory(path.join(tempDir.path, _cacheDirName));
    
    // Crear directorio si no existe
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    
    // Inicializar estadísticas si no existen
    if (!_prefs.containsKey('$_prefsKey.total_size')) {
      await _updateCacheStats();
    }
    
    _initialized = true;
  }
  
  Future<String?> getCachedVideo(String trackName, String artistName) async {
    await init();
    
    final safeName = _getSafeFileName(trackName, artistName);
    final cacheFile = File(path.join(_cacheDir.path, '$safeName.mp4'));
    
    if (await cacheFile.exists()) {
      // Actualizar fecha de acceso
      cacheFile.setLastAccessedSync(DateTime.now());
      return cacheFile.path;
    }
    
    return null;
  }
  
  Future<void> cacheVideo(String url, String trackName, String artistName) async {
    await init();
    
    final safeName = _getSafeFileName(trackName, artistName);
    final cacheFile = File(path.join(_cacheDir.path, '$safeName.mp4'));
    
    // Si ya existe, no descargar de nuevo
    if (await cacheFile.exists()) {
      return;
    }
    
    // Verificar espacio antes de descargar
    await _ensureFreeSpace();
    
    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final file = await cacheFile.openWrite();
        await response.pipe(file);
        await file.close();
        
        // Actualizar estadísticas
        final fileSize = await cacheFile.length();
        await _updateCacheStats(fileSize: fileSize);
      }
    } catch (e) {
      // Si falla la descarga, eliminar el archivo parcial si existe
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      rethrow;
    }
  }
  
  Future<void> _ensureFreeSpace() async {
    final maxSize = await getMaxCacheSize();
    final currentSize = await getCurrentCacheSize();
    
    if (currentSize >= maxSize) {
      // Liberar espacio eliminando archivos antiguos
      await _cleanupOldFiles(currentSize - (maxSize ~/ 2));
    }
  }
  
  Future<void> _cleanupOldFiles(int bytesToFree) async {
    final files = await _cacheDir.list().toList();
    
    // Ordenar por fecha de acceso (más antiguos primero)
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return aStat.accessed.compareTo(bStat.accessed);
    });
    
    int bytesFreed = 0;
    for (final file in files) {
      if (bytesFreed >= bytesToFree) break;
      
      if (file is File) {
        final size = await file.length();
        await file.delete();
        bytesFreed += size;
      }
    }
    
    if (bytesFreed > 0) {
      await _updateCacheStats(bytesFreed: -bytesFreed);
    }
  }
  
  Future<int> getCurrentCacheSize() async {
    return _prefs.getInt('$_prefsKey.total_size') ?? 0;
  }
  
  Future<int> getMaxCacheSize() async {
    return _prefs.getInt('$_prefsKey.max_size') ?? _defaultMaxSizeMB * 1024 * 1024;
  }
  
  Future<void> setMaxCacheSize(int bytes) async {
    await _prefs.setInt('$_prefsKey.max_size', bytes);
    // Forzar limpieza si el nuevo límite es menor que el tamaño actual
    await _ensureFreeSpace();
  }
  
  Future<void> clearCache() async {
    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create();
      await _prefs.remove('$_prefsKey.total_size');
    }
  }
  
  Future<void> _updateCacheStats({int? fileSize, int? bytesFreed}) async {
    final currentSize = _prefs.getInt('$_prefsKey.total_size') ?? 0;
    final newSize = currentSize + (fileSize ?? 0) + (bytesFreed ?? 0);
    
    if (newSize < 0) {
      await _prefs.setInt('$_prefsKey.total_size', 0);
    } else {
      await _prefs.setInt('$_prefsKey.total_size', newSize);
    }
  }
  
  String _getSafeFileName(String trackName, String artistName) {
    final combined = '$trackName-$artistName';
    return combined.replaceAll(RegExp(r'[^\w\s-]'), '_')
                   .replaceAll(RegExp(r'\s+'), '_')
                   .substring(0, min(100, combined.length));
  }
  
  Future<List<CachedVideoInfo>> getCachedVideos() async {
    await init();
    
    final files = await _cacheDir.list().toList();
    final videos = <CachedVideoInfo>[];
    
    for (final file in files) {
      if (file is File && file.path.endsWith('.mp4')) {
        final stat = await file.stat();
        videos.add(CachedVideoInfo(
          name: path.basenameWithoutExtension(file.path),
          path: file.path,
          size: stat.size,
          lastAccessed: stat.accessed,
        ));
      }
    }
    
    // Ordenar por fecha de acceso (más recientes primero)
    videos.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    
    return videos;
  }
}

class CachedVideoInfo {
  final String name;
  final String path;
  final int size;
  final DateTime lastAccessed;
  
  CachedVideoInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.lastAccessed,
  });
  
  String get formattedSize {
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}