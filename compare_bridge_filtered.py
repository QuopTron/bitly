import re

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
    'runNativeDownloadWorker',
}

ios_only = {
    'createIosBookmarkFromPath', 'startAccessingIosBookmark', 'stopAccessingIosBookmark',
}

with open('/tmp/flutter_methods.txt') as f:
    flutter = set(l.strip() for l in f if l.strip())
with open('/tmp/desktop_methods.txt') as f:
    desktop = set(l.strip() for l in f if l.strip())
with open('/tmp/android_methods.txt') as f:
    android = set(l.strip() for l in f if l.strip())

# Filter out legitimately platform-specific methods
def filter_platform(s, platform_set):
    return {m for m in s if m not in platform_set}

flutter_filtered = flutter - desktop_only - android_only - ios_only
desktop_filtered = desktop - android_only - ios_only
android_filtered = android - desktop_only - ios_only

print('=== METHODS IN FLUTTER BUT MISSING ON DESKTOP (REAL BUGS) ===')
missing_desktop = sorted(flutter_filtered - desktop_filtered)
for m in missing_desktop:
    print(m)
print(f'Total: {len(missing_desktop)}')

print('\n=== METHODS IN FLUTTER BUT MISSING ON ANDROID (REAL BUGS) ===')
missing_android = sorted(flutter_filtered - android_filtered)
for m in missing_android:
    print(m)
print(f'Total: {len(missing_android)}')

print('\n=== ON DESKTOP BUT MISSING ON ANDROID (should Android have these?) ===')
desk_missing_android = sorted(desktop_filtered - android_filtered)
for m in desk_missing_android:
    print(m)
print(f'Total: {len(desk_missing_android)}')

print('\n=== ON ANDROID BUT MISSING ON DESKTOP (should Desktop have these?) ===')
andr_missing_desktop = sorted(android_filtered - desktop_filtered)
for m in andr_missing_desktop:
    print(m)
print(f'Total: {len(andr_missing_desktop)}')

print('\n=== HANDLERS ON DESKTOP BUT NEVER CALLED FROM FLUTTER (orphan) ===')
orphan_desktop = sorted(desktop_filtered - flutter_filtered)
for m in orphan_desktop:
    print(m)
print(f'Total: {len(orphan_desktop)}')

print('\n=== HANDLERS ON ANDROID BUT NEVER CALLED FROM FLUTTER (orphan) ===')
orphan_android = sorted(android_filtered - flutter_filtered)
for m in orphan_android:
    print(m)
print(f'Total: {len(orphan_android)}')
