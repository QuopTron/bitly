import re, glob, sys
pattern = re.compile(r"invoke\(['\"]([^,'\"]+)['\"]")
files = glob.glob('lib/providers/**/*.dart', recursive=True) + glob.glob('lib/services/**/*.dart', recursive=True)
methods = set()
for path in files:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            for m in pattern.findall(content):
                methods.add(m)
    except Exception:
        pass
for m in sorted(methods):
    print(m)
