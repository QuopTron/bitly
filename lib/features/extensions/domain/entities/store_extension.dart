class StoreExtension {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final int downloads;
  final double rating;
  final String category;

  const StoreExtension({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    this.description = '',
    this.downloads = 0,
    this.rating = 0.0,
    this.category = '',
  });
}
