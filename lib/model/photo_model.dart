import 'package:photo_manager/photo_manager.dart';

class Photo {
  final String id;
  final String path;
  final DateTime date;
  final String? albumId;
  bool isFavorite;
  String? memo;
  String? voiceMemoPath;
  DateTime? memoDate;
  final AssetEntity? asset;
  final bool isVideo;

  Photo({
    required this.id,
    required this.path,
    required this.date,
    this.albumId,
    this.isFavorite = false,
    this.memo,
    this.voiceMemoPath,
    this.memoDate,
    this.asset,
    this.isVideo = false,
  });

  Photo copyWith({
    String? id,
    String? path,
    DateTime? date,
    String? albumId,
    bool? isFavorite,
    String? memo,
    String? voiceMemoPath,
    DateTime? memoDate,
    AssetEntity? asset,
    bool? isVideo,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      date: date ?? this.date,
      albumId: albumId ?? this.albumId,
      isFavorite: isFavorite ?? this.isFavorite,
      memo: memo ?? this.memo,
      voiceMemoPath: voiceMemoPath ?? this.voiceMemoPath,
      memoDate: memoDate ?? this.memoDate,
      asset: asset ?? this.asset,
      isVideo: isVideo ?? this.isVideo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'date': date.toIso8601String(),
      'albumId': albumId,
      'isFavorite': isFavorite,
      'memo': memo,
      'voiceMemoPath': voiceMemoPath,
      'memoDate': memoDate?.toIso8601String(),
      'isVideo': isVideo,
    };
  }

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      path: json['path'],
      date: DateTime.parse(json['date']),
      albumId: json['albumId'],
      isFavorite: json['isFavorite'] ?? false,
      memo: json['memo'],
      voiceMemoPath: json['voiceMemoPath'],
      memoDate:
          json['memoDate'] != null ? DateTime.parse(json['memoDate']) : null,
      asset: json['asset'],
      isVideo: json['isVideo'] ?? false,
    );
  }
}
