class ExtensionManifest {
  final String name;
  final String version;
  final String author;
  final String description;
  final String entrypoint;
  final List<String> permissions;
  final List<String> sources;

  const ExtensionManifest({
    required this.name,
    required this.version,
    required this.author,
    this.description = '',
    required this.entrypoint,
    this.permissions = const [],
    this.sources = const [],
  });
}
