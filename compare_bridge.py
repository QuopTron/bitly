import re, glob

# Extract desktop methods
with open('go_backend_Bitly/cmd/server/main.go', 'r', encoding='utf-8') as f:
    content = f.read()
desktop = set(re.findall(r'case "([a-zA-Z_][a-zA-Z0-9_]*)":', content))

# Extract Android methods
with open('android/app/src/main/kotlin/com/example/bitly/MainActivity.kt', 'r', encoding='utf-8') as f:
    content = f.read()
android = set(re.findall(r'"([a-zA-Z_][a-zA-Z0-9_]*)"\s*->', content))

# Extract Flutter methods
pattern = re.compile(r"invoke\(['\"]([^,'\"]+)['\"]")
files = glob.glob('lib/providers/**/*.dart', recursive=True) + glob.glob('lib/services/**/*.dart', recursive=True)
flutter = set()
for path in files:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            for m in pattern.findall(content):
                flutter.add(m)
    except Exception:
        pass

print('=== METHODS IN FLUTTER BUT MISSING ON DESKTOP ===')
missing_desktop = sorted(flutter - desktop)
for m in missing_desktop:
    print(m)
print(f'\nTotal missing on desktop: {len(missing_desktop)}')

print('\n=== METHODS IN FLUTTER BUT MISSING ON ANDROID ===')
missing_android = sorted(flutter - android)
for m in missing_android:
    print(m)
print(f'\nTotal missing on Android: {len(missing_android)}')

print('\n=== METHODS ON ANDROID BUT MISSING IN FLUTTER (orphan handlers) ===')
orphan_android = sorted(android - flutter)
for m in orphan_android:
    print(m)
print(f'\nTotal orphan Android handlers: {len(orphan_android)}')

print('\n=== METHODS ON DESKTOP BUT MISSING IN FLUTTER (orphan desktop) ===')
orphan_desktop = sorted(desktop - flutter)
for m in orphan_desktop:
    print(m)
print(f'\nTotal orphan desktop handlers: {len(orphan_desktop)}')

print('\n=== METHODS ON ANDROID BUT MISSING ON DESKTOP ===')
missing_from_desktop = sorted(android - desktop)
for m in missing_from_desktop:
    print(m)
print(f'\nTotal on Android but missing on Desktop: {len(missing_from_desktop)}')

print('\n=== METHODS ON DESKTOP BUT MISSING ON ANDROID ===')
missing_from_android = sorted(desktop - android)
for m in missing_from_android:
    print(m)
print(f'\nTotal on Desktop but missing on Android: {len(missing_from_android)}')
