#!/usr/bin/env python3
"""
Script to apply NEON Glassmorphism theme to remaining screens
"""

import re
import os
import sys

# Path to the project
PROJECT_PATH = "/mnt/e/Pablo/proyectos/bitly/lib"

# Files to update
FILES_TO_UPDATE = [
    "screens/home_tab.dart",
    "screens/queue_tab.dart", 
    "screens/album_screen.dart",
    "screens/artist_screen.dart",
    "screens/playlist_screen.dart",
    "screens/home_tab_widgets.dart",
    "screens/queue_tab_widgets.dart",
]

# Theme imports to add
THEME_IMPORTS = """import 'package:bitly/theme/app_theme.dart';
import 'package:bitly/theme/design_utils.dart';
import 'package:bitly/widgets/glass_container.dart';
"""

# Regex patterns
SCAFFOLD_PATTERN = r'(Scaffold\()'
BACKGROUND_PATTERN = r'(backgroundColor:\s*Theme\.of\(context\)\.colorScheme\.(background|surface))'
CARD_PATTERN = r'Card\('
CONTAINER_BACKGROUND_PATTERN = r'Container\([^)]*color:\s*(Colors\.white|Theme\.of\(context\)\.colorScheme\.(surface|background))[^)]*\)'

# Replacements
SCAFFOLD_REPLACEMENT = """NeonScaffold(
    appBar: AppBar("""

# Regex for more complex patterns
SCAFFOLD_FULL = re.compile(r'Scaffold\([^)]*backgroundColor:[^)]*[^)]*\)', re.DOTALL)

def update_file(filepath):
    """Update a single dart file with NEON theme"""
    print(f"Updating {filepath}...")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 1. Check if already has our theme imports
    has_theme_import = 'app_theme.dart' in content
    
    # 2. Find all imports and add our theme imports
    import_section_end = content.find('\n\nclass ') or content.find('\n\npart ')
    if import_section_end == -1:
        import_section_end = content.find('\n\n@')
    if import_section_end == -1:
        import_section_end = content.find('\n\nfinal ')
    
    # Add theme imports after existing imports
    if not has_theme_import and import_section_end != -1:
        # Insert before the first blank line after imports
        insert_pos = content.rfind('\n', 0, import_section_end) + 1
        content = content[:insert_pos] + '\n' + THEME_IMPORTS + '\n' + content[insert_pos:]
    
    # 3. Replace Scaffold with NeonScaffold
    # This is complex - let's just add gradient background
    content = re.sub(
        r'(Scaffold\()',
        r'\1\n      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimaryLight,',
        content,
        flags=re.DOTALL
    )
    
    # Add gradient background to body if Scaffold exists
    content = re.sub(
        r'(Scaffold\([^)]*body:\s*)([^)]*)',
        r'\1Container(\n        decoration: BoxDecoration(\n          gradient: isDark ? AppTheme.gradientDark : AppTheme.gradientLight,\n        ),\n        child: \2',
        content,
        flags=re.DOTALL
    )
    
    # 4. Add isDark and colorScheme variables if not present
    if 'final isDark = Theme.of(context).brightness == Brightness.dark' not in content:
        # Find build methods and add variables
        build_pattern = r'(Widget build\(BuildContext context(?:, WidgetRef ref)?\) \{[^\n]*\n)'
        def add_variables(match):
            return match.group(1) + """    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    """
        content = re.sub(build_pattern, add_variables, content, flags=re.DOTALL)
    
    # 5. Replace Card widgets with NeonCard
    # Simple replacement - might need adjustment
    content = re.sub(
        r'Card\(\s*margin:',
        r'NeonCard(\n      margin:',
        content
    )
    
    content = re.sub(
        r'Card\(\s*elevation:',
        r'NeonCard(\n      ',  # Remove elevation
        content
    )
    
    content = re.sub(
        r'Card\(\s*child:',
        r'NeonCard(\n      borderRadius: 16,\n      child:',
        content
    )
    
    # 6. Replace Container with specific color backgrounds
    content = re.sub(
        r'(Container\([^)]*)color:\s*Theme\.of\(context\)\.colorScheme\.surface(Container[^)]*\{)',
        r'\1color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,\n      \2',
        content
    )
    
    # 7. Scrollbar styling
    content = re.sub(
        r'(Scrollbar\()',
        r'Scrollbar(\n        thumbVisibility: true,\n        trackVisibility: true,\n        ',
        content
    )
    
    # Only write if content changed
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ Updated {filepath}")
        return True
    else:
        print(f"  - No changes for {filepath}")
        return False

def main():
    """Main function to update all files"""
    print("=" * 60)
    print("NEON THEME APPLIER - Glassmorphism & Futuristic Design")
    print("=" * 60)
    
    updated_count = 0
    
    for filename in FILES_TO_UPDATE:
        filepath = os.path.join(PROJECT_PATH, filename)
        if os.path.exists(filepath):
            if update_file(filepath):
                updated_count += 1
        else:
            print(f"  ⚠️  {filepath} not found")
    
    print("\n" + "=" * 60)
    print(f"Updated {updated_count}/{len(FILES_TO_UPDATE)} files")
    print("=" * 60)
    print("\nManual adjustments may still be needed for:")
    print("  - Complex layouts")
    print("  - Nested widgets")
    print("  - Custom styling")
    print("\nReview the documentation in NEON_DESIGN_IMPLEMENTATION.md")

if __name__ == '__main__':
    main()
