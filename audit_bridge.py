import re, os

# ========== Extract Flutter methods ==========
flutter_methods = set()
for root, dirs, files in os.walk('lib'):
    for fname in files:
        if not fname.endswith('.dart'):
            continue
        path = os.path.join(root, fname)
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            continue
        for m in re.findall(r'invoke\([\'\"]([^,\'\"]+)[\'\"]', content):
            flutter_methods.add(m)

# ========== Extract Desktop methods ==========
with open('go_backend_Bitly/cmd/server/main.go', 'r', encoding='utf-8') as f:
    desktop_content = f.read()
desktop_methods = set(re.findall(r'case \"([a-zA-Z_][a-zA-Z0-9_]*)\":', desktop_content))

# ========== Extract Android methods ==========
with open('android/app/src/main/kotlin/com/example/bitly/MainActivity.kt', 'r', encoding='utf-8') as f:
    android_content = f.read()
android_methods = set(re.findall(r'\"([a-zA-Z_][a-zA-Z0-9_]*)\"\s*->', android_content))

# ========== Platform-specific filters ==========
desktop_only = {
    'ping', 'convertAudioFile', 'parseCueSheet', 'scanCueSheetForLibrary',
    'checkDuplicatesBatch', 'preBuildDuplicateIndex', 'invalidateDuplicateIndex',
    'allowDownloadDir', 'getLogs', 'getLogsSince', 'getLogCount', 'clearLogs',
    'validarCodigoPremium', 'verificarPremium', 'exitApp', 'getTrackCacheSizeBytes',
    'cleanupConnections', 'setLoggingEnabled',
}
android_only = {
    'initGoBackend', 'startDownloadService', 'stopDownloadService',
    'updateDownloadServiceProgress', 'safStat', 'safExists', 'safDelete',
    'safCopyToTemp', 'safCreateFromPath', 'safReplaceFromPath',
    'writeTempToSaf', 'resolveSafFile', 'getSafFileModTimes', 'pickSafTree',
    'ensureYtDlp', 'bootstrapEssentialExtensions', 'shareContentUri',
    'shareMultipleContentUris', 'openContentUri', 'cancelNativeDownloadWorker',
    'scanSafTree', 'createYtDlpSAFContext', 'destroyYtDlpSAFContext',
    'runNativeDownloadWorker', 'pauseNativeDownloadWorker', 'resumeNativeDownloadWorker',
    'startNativeDownloadWorker', 'getNativeDownloadWorkerSnapshot',
    'isDownloadServiceRunning',
}
ios_only = {
    'createIosBookmarkFromPath', 'startAccessingIosBookmark', 'stopAccessingIosBookmark',
}

# ========== Filter ==========
flutter_shared = flutter_methods - desktop_only - android_only - ios_only
desktop_shared = desktop_methods - android_only - ios_only
android_shared = android_methods - desktop_only - ios_only

print(f'Flutter total: {len(flutter_methods)}')
print(f'Desktop total: {len(desktop_methods)}')
print(f'Android total: {len(android_methods)}')
print(f'Flutter shared (after filter): {len(flutter_shared)}')
print(f'Desktop shared (after filter): {len(desktop_shared)}')
print(f'Android shared (after filter): {len(android_shared)}')

print('\n=== METHODS IN FLUTTER BUT MISSING ON DESKTOP ===')
missing_desktop = sorted(flutter_shared - desktop_shared)
for m in missing_desktop:
    print(m)
print(f'Total: {len(missing_desktop)}')

print('\n=== METHODS IN FLUTTER BUT MISSING ON ANDROID ===')
missing_android = sorted(flutter_shared - android_shared)
for m in missing_android:
    print(m)
print(f'Total: {len(missing_android)}')

print('\n=== ON DESKTOP BUT MISSING ON ANDROID ===')
desk_missing_android = sorted(desktop_shared - android_shared)
for m in desk_missing_android:
    print(m)
print(f'Total: {len(desk_missing_android)}')

print('\n=== ON ANDROID BUT MISSING ON DESKTOP ===')
andr_missing_desktop = sorted(android_shared - desktop_shared)
for m in andr_missing_desktop:
    print(m)
print(f'Total: {len(andr_missing_desktop)}')

print('\n=== ORPHAN DESKTOP HANDLERS (not in Flutter) ===')
orphan_desktop = sorted(desktop_shared - flutter_shared)
for m in orphan_desktop:
    print(m)
print(f'Total: {len(orphan_desktop)}')

print('\n=== ORPHAN ANDROID HANDLERS (not in Flutter) ===')
orphan_android = sorted(android_shared - flutter_shared)
for m in orphan_android:
    print(m)
print(f'Total: {len(orphan_android)}')
