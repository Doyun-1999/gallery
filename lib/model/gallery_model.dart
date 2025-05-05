import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/album_model.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class GalleryModel extends ChangeNotifier {
  List<Photo> _photos = [];
  List<Album> _albums = [];
  List<Photo> _favorites = [];
  late SharedPreferences _prefs;
  static const String _memoKey = 'photo_memos';
  static const String _voiceMemoKey = 'photo_voice_memos';
  static const String _favoritesKey = 'favoriteIds';
  bool _isLoading = false;
  int _currentPage = 0;
  static const int _pageSize = 30;

  List<Photo> get photos => _photos;
  List<Album> get albums => List.unmodifiable(_albums);
  List<Photo> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  bool get hasMore => true;

  GalleryModel() {
    _initSharedPreferences();
    _loadData();
  }

  Future<void> _initSharedPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // SharedPreferences 초기화 실패 시 무시
    }
  }

  Future<void> _loadData() async {
    try {
      await _loadPhotos();
      await _loadAlbums();
      await _loadMemos();
      await _loadFavorites();
      notifyListeners();
    } catch (e) {
      // 데이터 로드 실패 시 무시
    }
  }

  Future<void> _loadMemos() async {
    try {
      // 텍스트 메모 로드
      final memoData = _prefs.getString(_memoKey);
      if (memoData != null && memoData.isNotEmpty) {
        final Map<String, dynamic> memoMap = json.decode(memoData);
        for (var photo in _photos) {
          photo.memo = memoMap[photo.id]?.toString();
        }
      }

      // 음성 메모 로드
      final voiceMemoData = _prefs.getString(_voiceMemoKey);
      if (voiceMemoData != null && voiceMemoData.isNotEmpty) {
        final Map<String, dynamic> voiceMemoMap = json.decode(voiceMemoData);
        for (var photo in _photos) {
          final voiceMemoPath = voiceMemoMap[photo.id]?.toString();
          if (voiceMemoPath != null) {
            final file = File(voiceMemoPath);
            if (await file.exists()) {
              photo.voiceMemoPath = voiceMemoPath;
            } else {
              voiceMemoMap.remove(photo.id);
            }
          }
        }
        final validVoiceMemoJson = json.encode(voiceMemoMap);
        await _prefs.setString(_voiceMemoKey, validVoiceMemoJson);
      }
    } catch (e) {
      // 메모 로드 실패 시 무시
    }
  }

  String? getMemo(String photoId) {
    final photo = _photos.firstWhere(
      (photo) => photo.id == photoId,
      orElse: () => Photo(id: photoId, path: '', date: DateTime.now()),
    );
    return photo.memo;
  }

  Future<void> _saveMemos() async {
    try {
      final memoMap = <String, String>{};
      final voiceMemoMap = <String, String>{};

      for (var photo in _photos) {
        if (photo.memo != null && photo.memo!.isNotEmpty) {
          memoMap[photo.id] = photo.memo!;
        }
        if (photo.voiceMemoPath != null && photo.voiceMemoPath!.isNotEmpty) {
          voiceMemoMap[photo.id] = photo.voiceMemoPath!;
        }
      }

      if (memoMap.isNotEmpty) {
        final memoJson = json.encode(memoMap);
        await _prefs.setString(_memoKey, memoJson);
      } else {
        await _prefs.remove(_memoKey);
      }

      if (voiceMemoMap.isNotEmpty) {
        final voiceMemoJson = json.encode(voiceMemoMap);
        await _prefs.setString(_voiceMemoKey, voiceMemoJson);
      } else {
        await _prefs.remove(_voiceMemoKey);
      }
    } catch (e) {
      // 메모 저장 실패 시 무시
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/photos.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _photos = jsonList.map((json) => Photo.fromJson(json)).toList();
      }
    } catch (e) {
      // 사진 로드 실패 시 무시
    }
  }

  Future<void> _savePhotos() async {
    final directory = await getApplicationDocumentsDirectory();
    final photosFile = File(path.join(directory.path, 'photos.json'));
    final jsonList = _photos.map((photo) => photo.toJson()).toList();
    await photosFile.writeAsString(json.encode(jsonList));
  }

  Future<void> _loadFavorites() async {
    try {
      final favoriteIds = _prefs.getStringList(_favoritesKey) ?? [];
      _favorites = [];
      for (var photo in _photos) {
        final isFavorite = favoriteIds.contains(photo.id);
        photo.isFavorite = isFavorite;
        if (isFavorite) {
          _favorites.add(photo);
        }
      }
    } catch (e) {
      // 즐겨찾기 로드 실패 시 무시
    }
  }

  Future<void> toggleFavorite(String photoId) async {
    try {
      final index = _photos.indexWhere((photo) => photo.id == photoId);
      if (index != -1) {
        final newFavoriteState = !_photos[index].isFavorite;
        _photos[index].isFavorite = newFavoriteState;

        if (newFavoriteState) {
          if (!_favorites.any((photo) => photo.id == photoId)) {
            _favorites.add(_photos[index]);
          }
        } else {
          _favorites.removeWhere((photo) => photo.id == photoId);
        }

        final favoriteIds = _favorites.map((p) => p.id).toList();
        await _prefs.setStringList(_favoritesKey, favoriteIds);

        await _savePhotos();
        notifyListeners();
      }
    } catch (e) {
      // 즐겨찾기 토글 실패 시 무시
    }
  }

  List<Photo> get favoritesByRecent {
    final favs = List<Photo>.from(favorites);
    favs.sort((a, b) => b.date.compareTo(a.date));
    return favs;
  }

  Future<void> removeFavorite(String photoId) async {
    final index = _photos.indexWhere((photo) => photo.id == photoId);
    if (index != -1 && _photos[index].isFavorite) {
      _photos[index] = _photos[index].copyWith(isFavorite: false);
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> clearAllFavorites() async {
    for (int i = 0; i < _photos.length; i++) {
      if (_photos[i].isFavorite) {
        _photos[i] = _photos[i].copyWith(isFavorite: false);
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
    final directory = await getApplicationDocumentsDirectory();
    final albumsFile = File(path.join(directory.path, 'albums.json'));

    if (await albumsFile.exists()) {
      final jsonString = await albumsFile.readAsString();
      final List<dynamic> albumsJson = json.decode(jsonString);
      _albums = albumsJson.map((json) => Album.fromJson(json)).toList();
    }
  }

  Future<void> _saveAlbums() async {
    final directory = await getApplicationDocumentsDirectory();
    final albumsFile = File(path.join(directory.path, 'albums.json'));
    final jsonList = _albums.map((album) => album.toJson()).toList();
    await albumsFile.writeAsString(json.encode(jsonList));
  }

  Future<void> addPhoto(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(imageFile.path);
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');

    final newPhoto = Photo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: savedImage.path,
      date: DateTime.now(),
    );

    _photos.add(newPhoto);
    await _savePhotos();
    notifyListeners();
  }

  Future<void> deletePhoto(String photoId) async {
    final photo = _photos.firstWhere((photo) => photo.id == photoId);

    for (var album in _albums) {
      album.photoIds.remove(photoId);
    }

    final file = File(photo.path);
    if (await file.exists()) {
      await file.delete();
    }

    _photos.removeWhere((photo) => photo.id == photoId);

    await _savePhotos();
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> createAlbum(String name) async {
    final album = Album(
      id: const Uuid().v4(),
      name: name,
      dateCreated: DateTime.now(),
    );
    _albums.add(album);
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> deleteAlbum(String albumId) async {
    _albums.removeWhere((album) => album.id == albumId);
    await _saveAlbums();
    notifyListeners();
  }

  Future<void> addPhotoToAlbum(String photoId, String albumId) async {
    final album = _albums.firstWhere((a) => a.id == albumId);
    if (!album.photoIds.contains(photoId)) {
      album.photoIds.add(photoId);
      album.coverPhotoId ??= photoId;
      await _saveAlbums();
      notifyListeners();
    }
  }

  Future<void> removePhotoFromAlbum(String photoId, String albumId) async {
    final album = _albums.firstWhere((a) => a.id == albumId);
    album.photoIds.remove(photoId);
    if (album.coverPhotoId == photoId) {
      album.coverPhotoId =
          album.photoIds.isNotEmpty ? album.photoIds.first : null;
    }
    await _saveAlbums();
    notifyListeners();
  }

  List<Photo> getAlbumPhotos(String albumId) {
    final album = _albums.firstWhere((album) => album.id == albumId);
    return _photos.where((photo) => album.photoIds.contains(photo.id)).toList();
  }

  Future<void> addMemo(String photoId, String memo) async {
    try {
      final photo = _photos.firstWhere((p) => p.id == photoId);
      photo.memo = memo;
      photo.memoDate = DateTime.now();
      await _saveMemos();
      notifyListeners();
    } catch (e) {
      // 메모 추가 실패 시 무시
    }
  }

  Future<void> addVoiceMemo(String photoId, String path) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final newPath = '${appDir.path}/$fileName';

      final sourceFile = File(path);
      final targetFile = File(newPath);
      await sourceFile.copy(newPath);

      if (await sourceFile.exists()) {
        await sourceFile.delete();
      }

      final photo = _photos.firstWhere((p) => p.id == photoId);
      photo.voiceMemoPath = newPath;
      photo.memoDate = DateTime.now();

      final voiceMemoMap = <String, String>{};
      for (var photo in _photos) {
        if (photo.voiceMemoPath != null) {
          voiceMemoMap[photo.id] = photo.voiceMemoPath!;
        }
      }

      final voiceMemoJson = json.encode(voiceMemoMap);
      await _prefs.setString(_voiceMemoKey, voiceMemoJson);

      notifyListeners();
    } catch (e) {
      // 음성 메모 추가 실패 시 무시
    }
  }

  Future<void> removeMemo(String photoId) async {
    try {
      final index = _photos.indexWhere((photo) => photo.id == photoId);
      if (index != -1) {
        _photos[index] = _photos[index].copyWith(
          memo: null,
          voiceMemoPath: null,
          memoDate: null,
        );
        await _saveMemos();
        notifyListeners();
      }
    } catch (e) {
      // 메모 삭제 실패 시 무시
    }
  }

  Future<void> setAlbumCover(String albumId, String photoId) async {
    final album = _albums.firstWhere((a) => a.id == albumId);
    if (album.photoIds.contains(photoId)) {
      album.coverPhotoId = photoId;
      await _saveAlbums();
      notifyListeners();
    }
  }

  Future<void> loadDevicePhotos(List<String> favoriteIds) async {
    try {
      _isLoading = true;
      _currentPage = 0;
      notifyListeners();

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );

      if (albums.isEmpty) return;

      final List<AssetEntity> initialPhotos = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      final Map<String, String> memoBackup = {};
      final Map<String, String> voiceMemoBackup = {};
      for (var photo in _photos) {
        if (photo.memo != null) {
          memoBackup[photo.id] = photo.memo!;
        }
        if (photo.voiceMemoPath != null) {
          voiceMemoBackup[photo.id] = photo.voiceMemoPath!;
        }
      }

      final List<Photo> newPhotos = [];
      for (final asset in initialPhotos) {
        final file = await asset.file;
        if (file != null) {
          final photo = Photo(
            id: asset.id,
            path: file.path,
            date: asset.createDateTime,
            isFavorite: favoriteIds.contains(asset.id),
            memo: memoBackup[asset.id],
            voiceMemoPath: voiceMemoBackup[asset.id],
            asset: asset,
          );
          newPhotos.add(photo);
        }
      }

      _photos = newPhotos;
      _currentPage++;
      await _savePhotos();
      await _saveMemos();
    } catch (e) {
      // 디바이스 사진 로드 실패 시 무시
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePhotos() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );

      if (albums.isEmpty) return;

      final List<AssetEntity> morePhotos = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      final Set<String> loadedIds = _photos.map((p) => p.id).toSet();

      for (final asset in morePhotos) {
        if (loadedIds.contains(asset.id)) continue;

        final file = await asset.file;
        if (file != null) {
          final photo = Photo(
            id: asset.id,
            path: file.path,
            date: asset.createDateTime,
            isFavorite: false,
            asset: asset,
          );
          _photos.add(photo);
        }
      }

      _currentPage++;
      await _savePhotos();
    } catch (e) {
      // 추가 사진 로드 실패 시 무시
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
