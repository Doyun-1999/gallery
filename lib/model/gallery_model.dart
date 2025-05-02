import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/album_model.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryModel extends ChangeNotifier {
  List<Photo> _photos = [];
  List<Album> _albums = [];

  List<Photo> get photos => _photos;
  List<Album> get albums => _albums;

  List<Photo> get favorites =>
      _photos.where((photo) => photo.isFavorite).toList();

  GalleryModel() {
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadPhotos();
    await _loadAlbums();
    notifyListeners();
  }

  Future<void> _loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favoriteIds') ?? [];

    await loadDevicePhotos(favoriteIds);
  }

  Future<void> loadDevicePhotos([List<String>? favoriteIds]) async {
    try {
      // 1. 명시적으로 권한 확인
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();
      print(
        "loadDevicePhotos 권한 상태: ${permission.isAuth}, ${permission.hasAccess}",
      );

      // 2. 권한이 없으면 빈 리스트로 설정하고 종료
      if (!permission.hasAccess) {
        _photos = [];
        notifyListeners();
        print("loadDevicePhotos: 권한 없음, 빈 리스트 반환");
        return;
      }

      // 3. 모든 앨범 가져오기 전에 딜레이 추가 (권한 적용 시간 확보)
      await Future.delayed(Duration(milliseconds: 300));

      // 4. 모든 앨범 가져오기 시도
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );

      print("앨범 개수: ${albums.length}");

      if (albums.isEmpty) {
        _photos = [];
        notifyListeners();
        print("앨범이 없음, 빈 리스트 반환");
        return;
      }

      // 5. 첫 번째 앨범에서 이미지 가져오기
      final AssetPathEntity allPhotosAlbum = albums.first;
      final List<AssetEntity> assets = await allPhotosAlbum.getAssetListRange(
        start: 0,
        end: 100, // 최대 이미지 수 조정
      );

      print("가져온 이미지 수: ${assets.length}");

      // 6. 이미지를 Photo 모델로 변환
      _photos = [];
      for (final asset in assets) {
        try {
          final File? file = await asset.file;
          if (file != null) {
            final String id = asset.id;
            final bool isFavorite = favoriteIds?.contains(id) ?? false;

            _photos.add(
              Photo(
                id: id,
                path: file.path,
                dateAdded: DateTime.fromMillisecondsSinceEpoch(
                  asset.createDateTime.millisecondsSinceEpoch,
                ),
                isFavorite: isFavorite,
              ),
            );
          }
        } catch (assetError) {
          print("개별 이미지 처리 중 오류: $assetError");
          // 개별 이미지 오류는 무시하고 계속 진행
          continue;
        }
      }

      notifyListeners();
      print("이미지 로드 완료: ${_photos.length}개 변환됨");
    } catch (e) {
      print("loadDevicePhotos 메서드 실행 중 오류 발생: $e");
      // 오류 발생 시 빈 리스트로 설정
      _photos = [];
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String photoId) async {
    final index = _photos.indexWhere((photo) => photo.id == photoId);
    if (index != -1) {
      final bool newFavoriteStatus = !_photos[index].isFavorite;
      _photos[index] = _photos[index].copyWith(
        isFavorite: newFavoriteStatus,
        favoritedAt: newFavoriteStatus ? DateTime.now() : null,
      );
      await _saveFavorites();
      notifyListeners();
    }
  }

  List<Photo> get favoritesByRecent {
    final favs = favorites;
    favs.sort((a, b) {
      if (a.favoritedAt == null || b.favoritedAt == null) {
        return 0;
      }
      return b.favoritedAt!.compareTo(a.favoritedAt!);
    });
    return favs;
  }

  Future<void> removeFavorite(String photoId) async {
    final index = _photos.indexWhere((photo) => photo.id == photoId);
    if (index != -1 && _photos[index].isFavorite) {
      _photos[index] = _photos[index].copyWith(
        isFavorite: false,
        favoritedAt: null,
      );
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> clearAllFavorites() async {
    for (int i = 0; i < _photos.length; i++) {
      if (_photos[i].isFavorite) {
        _photos[i] = _photos[i].copyWith(isFavorite: false, favoritedAt: null);
      }
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds =
        _photos
            .where((photo) => photo.isFavorite)
            .map((photo) => photo.id)
            .toList();

    await prefs.setStringList('favoriteIds', favoriteIds);
  }

  Future<void> _loadAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = prefs.getStringList('albums') ?? [];

    _albums =
        albumsJson.map((json) => Album.fromJson(jsonDecode(json))).toList();
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson =
        _photos.map((photo) => jsonEncode(photo.toJson())).toList();

    await prefs.setStringList('photos', photosJson);
  }

  Future<void> _saveAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson =
        _albums.map((album) => jsonEncode(album.toJson())).toList();

    await prefs.setStringList('albums', albumsJson);
  }

  Future<void> addPhoto(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(imageFile.path);
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');

    final newPhoto = Photo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: savedImage.path,
      dateAdded: DateTime.now(),
    );

    _photos.add(newPhoto);
    await _savePhotos();
    notifyListeners();
  }

  Future<void> deletePhoto(String photoId) async {
    final photo = _photos.firstWhere((photo) => photo.id == photoId);

    // Delete from albums
    for (var album in _albums) {
      album.photoIds.remove(photoId);
    }

    // Delete the actual file
    final file = File(photo.path);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from list
    _photos.removeWhere((photo) => photo.id == photoId);

    await _savePhotos();
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> createAlbum(String name) async {
    final newAlbum = Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      photoIds: [],
      dateCreated: DateTime.now(),
    );

    _albums.add(newAlbum);
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> deleteAlbum(String albumId) async {
    _albums.removeWhere((album) => album.id == albumId);
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> addPhotoToAlbum(String photoId, String albumId) async {
    final albumIndex = _albums.indexWhere((album) => album.id == albumId);
    if (albumIndex != -1 && !_albums[albumIndex].photoIds.contains(photoId)) {
      _albums[albumIndex].photoIds.add(photoId);
      await _saveAlbums();
      notifyListeners();
    }
  }

  Future<void> removePhotoFromAlbum(String photoId, String albumId) async {
    final albumIndex = _albums.indexWhere((album) => album.id == albumId);
    if (albumIndex != -1) {
      _albums[albumIndex].photoIds.remove(photoId);
      await _saveAlbums();
      notifyListeners();
    }
  }

  List<Photo> getAlbumPhotos(String albumId) {
    final album = _albums.firstWhere((album) => album.id == albumId);
    return _photos.where((photo) => album.photoIds.contains(photo.id)).toList();
  }
}
