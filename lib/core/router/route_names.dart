enum RouteNames {
  splash('/'),
  tutorial('/tutorial'),
  setup('/setup'),
  home('/home'),
  search('/search'),
  library('/library'),
  downloads('/downloads'),
  player('/player'),
  settings('/settings'),
  extensions('/extensions'),
  extensionsStore('/extensions/store');

  final String path;
  const RouteNames(this.path);

  String get name => path.replaceAll('/', '');
}
