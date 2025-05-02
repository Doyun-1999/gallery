class Photo {
  final String id;
  final String path;
  final DateTime dateAdded;
  final bool isFavorite;
  final DateTime? favoritedAt;

  Photo({
    required this.id,
    required this.path,
    required this.dateAdded,
    this.isFavorite = false,
    this.favoritedAt,
  });

  Photo copyWith({
    String? id,
    String? path,
    DateTime? dateAdded,
    bool? isFavorite,
    DateTime? favoritedAt,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritedAt: favoritedAt ?? this.favoritedAt,
    );
  }

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      path: json['path'],
      dateAdded: DateTime.parse(json['dateAdded']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'dateAdded': dateAdded.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }
}
