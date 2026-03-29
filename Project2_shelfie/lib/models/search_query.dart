/// Represents the user's search query for a book or product.
class SearchQuery {
  final String text;
  final SearchMode mode;
  final DateTime createdAt;

  SearchQuery({
    required this.text,
    required this.mode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'SearchQuery(text: $text, mode: $mode)';
}

enum SearchMode {
  library('Library', '📚'),
  store('Store', '🛒');

  final String label;
  final String icon;
  const SearchMode(this.label, this.icon);
}
