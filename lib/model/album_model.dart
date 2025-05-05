class Album {
  final String id;
  final String name;
  final List<String> photoIds;
  String? coverPhotoId;
  final DateTime dateCreated;

  Album({
    required this.id,
    required this.name,
    List<String>? photoIds,
    this.coverPhotoId,
    required this.dateCreated,
  }) : photoIds = photoIds ?? [];

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      name: json['name'],
      photoIds: List<String>.from(json['photoIds'] ?? []),
      coverPhotoId: json['coverPhotoId'],
      dateCreated: DateTime.parse(json['dateCreated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoIds': photoIds,
      'coverPhotoId': coverPhotoId,
      'dateCreated': dateCreated.toIso8601String(),
    };
  }
}
