/// Paginated response wrapper
class PaginatedResponse<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  PaginatedResponse({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final itemsJson = json['items'] as List<dynamic>? ?? json['data'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      items: itemsJson.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? json['next_cursor'] != null,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'items': items.map((e) => toJsonT(e)).toList(),
      if (nextCursor != null) 'next_cursor': nextCursor,
      'has_more': hasMore,
    };
  }
}

