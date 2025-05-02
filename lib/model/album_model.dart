class Album {
  final String id;
  final String name;
  final List<String> photoIds;
  final DateTime dateCreated;

  Album({
    required this.id,
    required this.name,
    required this.photoIds,
    required this.dateCreated,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      name: json['name'],
      photoIds: List<String>.from(json['photoIds']),
      dateCreated: DateTime.parse(json['dateCreated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoIds': photoIds,
      'dateCreated': dateCreated.toIso8601String(),
    };
  }
}
