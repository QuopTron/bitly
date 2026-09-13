#!/bin/bash
# embed_xcode.sh — Embed Go backend framework/binary in iOS/macOS Xcode projects.
#
# Usage:
#   ./scripts/build/embed_xcode.sh ios      # Embed Gobackend.xcframework in iOS target
#   ./scripts/build/embed_xcode.sh macos    # Embed Gobackend.framework in macOS target
#
# Run from the repo root AFTER `gomobile bind -target=ios -o ...`

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

embed_ios() {
  local XC_FRAMEWORK="$ROOT/ios/Runner/Gobackend.xcframework"
  local PROJECT="$ROOT/ios/Runner.xcodeproj"

  if [ ! -d "$XC_FRAMEWORK" ]; then
    echo "ERROR: $XC_FRAMEWORK not found. Run:"
    echo "  cd go_backend && gomobile bind -target=ios -o ../ios/Runner/Gobackend.xcframework ./internal/gobackend/"
    exit 1
  fi

  echo "=== Adding Gobackend.xcframework to iOS Xcode project ==="

  # 1. Add framework search path
  # 2. Add framework to "Embed Frameworks" build phase
  # 3. Add framework to "Link Binary With Libraries"
  #
  # This requires Ruby + xcodeproj gem:
  #   gem install xcodeproj

  if ! command -v ruby &>/dev/null; then
    echo "ERROR: Ruby is required. Install via 'brew install ruby'."
    exit 1
  fi

  ruby <<-RUBY
    require 'xcodeproj'

    project_path = '$PROJECT'
    framework_path = '$XC_FRAMEWORK'
    project = Xcodeproj::Project.open(project_path)
    target = project.targets.find { |t| t.name == 'Runner' }

    unless target
      puts 'ERROR: Runner target not found'
      exit 1
    end

    # Add framework to 'Frameworks' group
    frameworks_group = project.main_group.find_subpath('Frameworks', true)
    framework_ref = frameworks_group.new_reference(framework_path)

    # Add to 'Link Binary With Libraries' build phase
    target.frameworks_build_phase.add_file_reference(framework_ref)

    # Add to 'Embed Frameworks' build phase
    embed_phase = target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && p.name == 'Embed Frameworks' }
    unless embed_phase
      embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
      embed_phase.name = 'Embed Frameworks'
      embed_phase.symbol_dst_subfolder_spec = :frameworks
      target.build_phases << embed_phase
    end
    embed_phase.add_file_reference(framework_ref)

    project.save
    puts '✓ Gobackend.xcframework added to iOS project'
	RUBY
}

embed_macos() {
  local FRAMEWORK="$ROOT/macos/Runner/Gobackend.framework"
  local PROJECT="$ROOT/macos/Runner.xcodeproj"

  if [ ! -d "$FRAMEWORK" ]; then
    echo "ERROR: $FRAMEWORK not found. Run:"
    echo "  cd go_backend && gomobile bind -target=macos -o ../macos/Runner/Gobackend.framework ./internal/gobackend/"
    exit 1
  fi

  echo "=== Adding Gobackend.framework to macOS Xcode project ==="

  ruby <<-RUBY
    require 'xcodeproj'

    project_path = '$PROJECT'
    framework_path = '$FRAMEWORK'
    project = Xcodeproj::Project.open(project_path)
    target = project.targets.find { |t| t.name == 'Runner' }

    unless target
      puts 'ERROR: Runner target not found'
      exit 1
    end

    frameworks_group = project.main_group.find_subpath('Frameworks', true)
    framework_ref = frameworks_group.new_reference(framework_path)
    target.frameworks_build_phase.add_file_reference(framework_ref)

    # macOS: also need to embed in Frameworks
    embed_phase = target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && p.name == 'Embed Frameworks' }
    unless embed_phase
      embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
      embed_phase.name = 'Embed Frameworks'
      embed_phase.symbol_dst_subfolder_spec = :frameworks
      target.build_phases << embed_phase
    end
    embed_phase.add_file_reference(framework_ref)

    project.save
    puts '✓ Gobackend.framework added to macOS project'
	RUBY
}

case "${1:-}" in
  ios)    embed_ios ;;
  macos)  embed_macos ;;
  both)   embed_ios && embed_macos ;;
  *)
    echo "Usage: $0 {ios|macos|both}"
    exit 1
    ;;
esac
