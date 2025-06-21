import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/album_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  int? _totalPhotoCount;

  // 기기 앨범 캐시
  List<AssetPathEntity>? _cachedDeviceAlbums;
  final Map<String, Photo?> _cachedThumbnails = {};
  DateTime? _lastDeviceAlbumsLoadTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  final Set<String> _selectedPhotoIds = {}; // 선택된 이미지 ID들을 저장하는 Set

  List<Photo> get photos => _photos;
  List<Album> get albums => _albums;
  List<Photo> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  bool get hasMore {
    if (_currentPage == -1) return false;
    if (_totalPhotoCount == null) return true;
    return _photos.length < _totalPhotoCount!;
  }

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

        // 실제 파일이 존재하고, 이미지/비디오 파일인지 확인
        _photos.removeWhere((photo) {
          // 파일이 존재하지 않으면 제거
          if (!File(photo.path).existsSync()) return true;

          // 음성 녹음 파일 확장자 체크
          final extension = photo.path.toLowerCase().split('.').last;
          final audioExtensions = ['m4a', 'wav', 'mp3', 'aac', 'ogg', 'flac'];
          if (audioExtensions.contains(extension)) return true;

          return false;
        });
      }
    } catch (e) {
      // 사진 로드 실패 시 무시
    }
    notifyListeners();
  }

  Future<void> _savePhotos() async {
    final directory = await getApplicationDocumentsDirectory();
    final photosFile = File(path.join(directory.path, 'photos.json'));

    // 이미지/비디오 파일만 필터링하여 저장
    final validPhotos =
        _photos.where((photo) {
          // 음성 녹음 파일 확장자 체크
          final extension = photo.path.toLowerCase().split('.').last;
          final audioExtensions = ['m4a', 'wav', 'mp3', 'aac', 'ogg', 'flac'];
          return !audioExtensions.contains(extension);
        }).toList();

    final jsonList = validPhotos.map((photo) => photo.toJson()).toList();
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

  Future<bool> deletePhoto(String photoId) async {
    try {
      final photo = photos.firstWhere((p) => p.id == photoId);
      debugPrint('삭제할 사진 정보: id=${photo.id}, path=${photo.path}');

      // Android 권한 체크
      if (Platform.isAndroid) {
        debugPrint('안드로이드 권한 체크 시작...');

        // Android 12 이상인지 확인
        final isAndroid12OrHigher = await _isAndroid12OrHigher();
        debugPrint('Android 12 이상 여부: $isAndroid12OrHigher');

        if (isAndroid12OrHigher) {
          // Android 13 이상에서는 READ_MEDIA_IMAGES 권한 사용
          final isAndroid13OrHigher = await _isAndroid13OrHigher();
          if (isAndroid13OrHigher) {
            final mediaImagesStatus = await Permission.photos.status;
            debugPrint('Media Images 권한 상태: $mediaImagesStatus');

            if (mediaImagesStatus.isDenied) {
              debugPrint('Media Images 권한 요청 시작...');
              final mediaImagesResult = await Permission.photos.request();
              debugPrint('Media Images 권한 요청 결과: $mediaImagesResult');
              if (mediaImagesResult.isDenied) {
                debugPrint('Media Images 권한이 거부됨');
                return false;
              }
            }
          } else {
            // Android 12에서는 storage 권한 사용
            final storageStatus = await Permission.storage.status;
            debugPrint('Storage 권한 상태: $storageStatus');

            if (storageStatus.isDenied) {
              debugPrint('Storage 권한 요청 시작...');
              final storageResult = await Permission.storage.request();
              debugPrint('Storage 권한 요청 결과: $storageResult');
              if (storageResult.isDenied) {
                debugPrint('Storage 권한이 거부됨');
                return false;
              }
            }
          }

          // Android 12 이상에서는 추가로 MANAGE_EXTERNAL_STORAGE 권한도 필요할 수 있음
          final manageStorageStatus =
              await Permission.manageExternalStorage.status;
          debugPrint('Manage External Storage 권한 상태: $manageStorageStatus');

          if (manageStorageStatus.isDenied) {
            debugPrint('Manage External Storage 권한 요청 시작...');
            final manageStorageResult =
                await Permission.manageExternalStorage.request();
            debugPrint(
              'Manage External Storage 권한 요청 결과: $manageStorageResult',
            );
            if (manageStorageResult.isDenied) {
              debugPrint('Manage External Storage 권한이 거부됨');
              return false;
            }
          }
        } else {
          // Android 12 미만에서는 storage 권한도 필요
          final storageStatus = await Permission.storage.status;
          debugPrint('Storage 권한 상태: $storageStatus');

          if (storageStatus.isDenied) {
            debugPrint('Storage 권한 요청 시작...');
            final storageResult = await Permission.storage.request();
            debugPrint('Storage 권한 요청 결과: $storageResult');
            if (storageResult.isDenied) {
              debugPrint('Storage 권한이 거부됨');
              return false;
            }
          }
        }
      }

      bool systemDeleteSuccess = false;

      // 1. PhotoManager를 통한 삭제 시도
      if (photo.asset != null) {
        try {
          debugPrint('PhotoManager를 통한 삭제 시도...');
          final List<String> result = await PhotoManager.editor.deleteWithIds([
            photo.asset!.id,
          ]);
          systemDeleteSuccess = result.isNotEmpty;
          debugPrint(
            'PhotoManager 삭제 결과: $systemDeleteSuccess, 삭제된 ID: $result',
          );
        } catch (e) {
          debugPrint('PhotoManager 삭제 실패: $e');
        }
      }

      // 2. 파일 시스템을 통한 삭제 시도
      if (!systemDeleteSuccess) {
        try {
          debugPrint('파일 시스템을 통한 삭제 시도...');
          final file = File(photo.path);
          if (await file.exists()) {
            await file.delete();
            systemDeleteSuccess = true;
            debugPrint('파일 시스템 삭제 성공');
          } else {
            debugPrint('파일이 존재하지 않음');
          }
        } catch (e) {
          debugPrint('파일 시스템 삭제 실패: $e');
        }
      }

      if (systemDeleteSuccess) {
        _photos.removeWhere((p) => p.id == photoId);
        await _savePhotos();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('사진 삭제 중 오류 발생: $e');
      return false;
    }
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
      final photo = _photos.firstWhere((p) => p.id == photoId);

      // 기존 음성 메모가 있다면 삭제
      if (photo.voiceMemoPath != null && photo.voiceMemoPath!.isNotEmpty) {
        final oldFile = File(photo.voiceMemoPath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      // 새로운 파일 경로가 비어있지 않은 경우에만 처리
      if (path.isNotEmpty) {
        final sourceFile = File(path);
        if (await sourceFile.exists()) {
          photo.voiceMemoPath = path;
          photo.memoDate = DateTime.now();

          final voiceMemoMap = <String, String>{};
          for (var photo in _photos) {
            if (photo.voiceMemoPath != null &&
                photo.voiceMemoPath!.isNotEmpty) {
              voiceMemoMap[photo.id] = photo.voiceMemoPath!;
            }
          }

          final voiceMemoJson = json.encode(voiceMemoMap);
          await _prefs.setString(_voiceMemoKey, voiceMemoJson);
        }
      } else {
        // 빈 경로가 전달된 경우 음성 메모 삭제
        photo.voiceMemoPath = null;
        photo.memoDate = null;

        final voiceMemoMap = <String, String>{};
        for (var photo in _photos) {
          if (photo.voiceMemoPath != null && photo.voiceMemoPath!.isNotEmpty) {
            voiceMemoMap[photo.id] = photo.voiceMemoPath!;
          }
        }

        if (voiceMemoMap.isEmpty) {
          await _prefs.remove(_voiceMemoKey);
        } else {
          final voiceMemoJson = json.encode(voiceMemoMap);
          await _prefs.setString(_voiceMemoKey, voiceMemoJson);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('음성 메모 추가 실패: $e');
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
        type: RequestType.all,
      );

      if (albums.isEmpty) {
        _currentPage = -1;
        _totalPhotoCount = 0;
        return;
      }

      // 전체 사진 개수 가져오기
      _totalPhotoCount = await albums[0].assetCountAsync;

      final List<AssetEntity> initialPhotos = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      if (initialPhotos.isEmpty) {
        _currentPage = -1;
        return;
      }

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
        try {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            // 파일 확장자 체크하여 이미지/비디오 파일만 허용
            final extension = file.path.toLowerCase().split('.').last;
            final imageExtensions = [
              'jpg',
              'jpeg',
              'png',
              'gif',
              'bmp',
              'webp',
              'heic',
              'heif',
            ];
            final videoExtensions = [
              'mp4',
              'avi',
              'mov',
              'wmv',
              'flv',
              'webm',
              'mkv',
              '3gp',
            ];
            final validExtensions = [...imageExtensions, ...videoExtensions];

            if (!validExtensions.contains(extension)) {
              debugPrint('지원하지 않는 파일 형식 제외: ${file.path}');
              continue;
            }

            final photo = Photo(
              id: asset.id,
              path: file.path,
              date: asset.createDateTime,
              isFavorite: favoriteIds.contains(asset.id),
              memo: memoBackup[asset.id],
              voiceMemoPath: voiceMemoBackup[asset.id],
              asset: asset,
              isVideo: asset.type == AssetType.video,
            );
            newPhotos.add(photo);
          }
        } catch (e) {
          debugPrint('사진 로딩 중 오류 발생: ${asset.id} - $e');
          continue;
        }
      }

      _photos = newPhotos;
      _currentPage++;
      await _savePhotos();
      await _saveMemos();
    } catch (e) {
      print('디바이스 사진 로드 중 오류 발생: $e');
      _currentPage = -1;
      _totalPhotoCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePhotos() async {
    if (_isLoading || !hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
      );

      if (albums.isEmpty) {
        _currentPage = -1;
        _totalPhotoCount = 0;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 전체 사진 개수 가져오기
      _totalPhotoCount = await albums[0].assetCountAsync;

      // 페이지 크기를 늘려서 더 많은 사진을 한 번에 로드
      final List<AssetEntity> morePhotos = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: 30,
      );

      if (morePhotos.isEmpty) {
        _currentPage = -1;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final Set<String> loadedIds = _photos.map((p) => p.id).toSet();
      bool hasNewPhotos = false;

      // 기존 사진들의 메모와 즐겨찾기 상태 백업
      final Map<String, String> memoBackup = {};
      final Map<String, String> voiceMemoBackup = {};
      final Map<String, bool> favoriteBackup = {};
      for (var photo in _photos) {
        if (photo.memo != null) {
          memoBackup[photo.id] = photo.memo!;
        }
        if (photo.voiceMemoPath != null) {
          voiceMemoBackup[photo.id] = photo.voiceMemoPath!;
        }
        favoriteBackup[photo.id] = photo.isFavorite;
      }

      for (final asset in morePhotos) {
        if (loadedIds.contains(asset.id)) continue;

        try {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            // 파일 확장자 체크하여 이미지/비디오 파일만 허용
            final extension = file.path.toLowerCase().split('.').last;
            final imageExtensions = [
              'jpg',
              'jpeg',
              'png',
              'gif',
              'bmp',
              'webp',
              'heic',
              'heif',
            ];
            final videoExtensions = [
              'mp4',
              'avi',
              'mov',
              'wmv',
              'flv',
              'webm',
              'mkv',
              '3gp',
            ];
            final validExtensions = [...imageExtensions, ...videoExtensions];

            if (!validExtensions.contains(extension)) {
              debugPrint('지원하지 않는 파일 형식 제외: ${file.path}');
              continue;
            }

            final isVideo = asset.type == AssetType.video;
            debugPrint('로드된 파일: ${file.path}, isVideo: $isVideo');

            final photo = Photo(
              id: asset.id,
              path: file.path,
              date: asset.createDateTime,
              isFavorite: favoriteBackup[asset.id] ?? false,
              memo: memoBackup[asset.id],
              voiceMemoPath: voiceMemoBackup[asset.id],
              asset: asset,
              isVideo: isVideo,
            );
            _photos.add(photo);
            hasNewPhotos = true;
          }
        } catch (e) {
          debugPrint('사진 로딩 중 오류 발생: ${asset.id} - $e');
          // 개별 사진 로딩 실패는 무시하고 계속 진행
          continue;
        }
      }

      if (hasNewPhotos) {
        _currentPage++;
        await _savePhotos();
        await _saveMemos();

        // 동영상이 20개 이상 로드되었거나 더 이상 로드할 사진이 없을 때까지 계속 로드
        final videoCount = _photos.where((photo) => photo.isVideo).length;
        if (videoCount < 20 && morePhotos.isNotEmpty) {
          _isLoading = false;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 100)); // 약간의 지연 추가
          // await loadMorePhotos(); // 재귀적으로 더 로드
        } else {
          _isLoading = false;
          notifyListeners();
        }
      } else {
        _currentPage = -1;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('추가 사진 로드 중 오류 발생: $e');
      _currentPage = -1;
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isPhotoInAlbum(String photoId, String albumId) {
    final album = _albums.firstWhere(
      (album) => album.id == albumId,
      orElse: () => throw Exception('Album not found'),
    );
    return album.photoIds.contains(photoId);
  }

  // 기기 앨범 목록을 가져오는 메서드
  Future<List<AssetPathEntity>> getDeviceAlbums() async {
    try {
      // 캐시된 데이터가 있고 유효한 경우 캐시된 데이터 반환
      if (_cachedDeviceAlbums != null && _lastDeviceAlbumsLoadTime != null) {
        final now = DateTime.now();
        if (now.difference(_lastDeviceAlbumsLoadTime!) < _cacheDuration) {
          debugPrint('캐시된 기기 앨범 목록 사용');
          return _cachedDeviceAlbums!;
        }
      }

      debugPrint('PhotoManager.getAssetPathList 호출 시작...');
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
      );

      debugPrint('PhotoManager.getAssetPathList 결과: ${albums.length}개의 앨범');

      // 이미지/동영상 파일만 포함된 앨범만 필터링
      final List<AssetPathEntity> validAlbums = [];
      for (final album in albums) {
        try {
          // 각 앨범의 첫 번째 asset을 확인하여 이미지/동영상인지 체크
          final assets = await album.getAssetListPaged(page: 0, size: 1);
          if (assets.isNotEmpty) {
            final asset = assets.first;
            final file = await asset.file;
            if (file != null && await file.exists()) {
              // 파일 확장자 체크
              final extension = file.path.toLowerCase().split('.').last;
              final imageExtensions = [
                'jpg',
                'jpeg',
                'png',
                'gif',
                'bmp',
                'webp',
                'heic',
                'heif',
              ];
              final videoExtensions = [
                'mp4',
                'avi',
                'mov',
                'wmv',
                'flv',
                'webm',
                'mkv',
                '3gp',
              ];
              final validExtensions = [...imageExtensions, ...videoExtensions];

              if (validExtensions.contains(extension)) {
                validAlbums.add(album);
                debugPrint('유효한 앨범 추가: ${album.name}');
              } else {
                debugPrint(
                  '지원하지 않는 파일 형식이 포함된 앨범 제외: ${album.name} (${file.path})',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('앨범 검증 중 오류 발생: ${album.name} - $e');
          // 오류가 발생한 앨범은 제외
          continue;
        }
      }

      debugPrint('필터링 후 유효한 앨범 수: ${validAlbums.length}개');

      // 캐시 업데이트
      _cachedDeviceAlbums = validAlbums;
      _lastDeviceAlbumsLoadTime = DateTime.now();

      return validAlbums;
    } catch (e) {
      debugPrint('기기 앨범 로드 중 오류 발생: $e');
      return _cachedDeviceAlbums ?? [];
    }
  }

  // 특정 기기 앨범의 사진들을 가져오는 메서드
  Future<List<Photo>> getDeviceAlbumPhotos(
    AssetPathEntity album, {
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      final List<AssetEntity> assets = await album.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      final List<Photo> photos = [];
      for (final asset in assets) {
        try {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            // 파일 확장자 체크하여 이미지/비디오 파일만 허용
            final extension = file.path.toLowerCase().split('.').last;
            final imageExtensions = [
              'jpg',
              'jpeg',
              'png',
              'gif',
              'bmp',
              'webp',
              'heic',
              'heif',
            ];
            final videoExtensions = [
              'mp4',
              'avi',
              'mov',
              'wmv',
              'flv',
              'webm',
              'mkv',
              '3gp',
            ];
            final validExtensions = [...imageExtensions, ...videoExtensions];

            if (!validExtensions.contains(extension)) {
              debugPrint('지원하지 않는 파일 형식 제외: ${file.path}');
              continue;
            }

            final photo = Photo(
              id: asset.id,
              path: file.path,
              date: asset.createDateTime,
              asset: asset,
              isVideo: asset.type == AssetType.video,
            );
            photos.add(photo);
          }
        } catch (e) {
          debugPrint('앨범 사진 로딩 중 오류 발생: ${asset.id} - $e');
          // 개별 사진 로딩 실패는 무시하고 계속 진행
          continue;
        }
      }
      return photos;
    } catch (e) {
      debugPrint('기기 앨범 사진 로드 중 오류 발생: $e');
      return [];
    }
  }

  // 앨범 썸네일을 위한 첫 번째 사진만 가져오는 메서드
  Future<Photo?> getDeviceAlbumThumbnail(AssetPathEntity album) async {
    try {
      // 캐시된 썸네일이 있는 경우 캐시된 데이터 반환
      if (_cachedThumbnails.containsKey(album.id)) {
        debugPrint('캐시된 썸네일 사용: ${album.name}');
        return _cachedThumbnails[album.id];
      }

      final List<AssetEntity> assets = await album.getAssetListPaged(
        page: 0,
        size: 1, // 첫 번째 사진만 가져옴
      );

      if (assets.isEmpty) return null;

      final asset = assets.first;
      try {
        final file = await asset.file;
        if (file == null || !await file.exists()) return null;

        // 파일 확장자 체크하여 이미지/비디오 파일만 허용
        final extension = file.path.toLowerCase().split('.').last;
        final imageExtensions = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'webp',
          'heic',
          'heif',
        ];
        final videoExtensions = [
          'mp4',
          'avi',
          'mov',
          'wmv',
          'flv',
          'webm',
          'mkv',
          '3gp',
        ];
        final validExtensions = [...imageExtensions, ...videoExtensions];

        if (!validExtensions.contains(extension)) {
          debugPrint('지원하지 않는 파일 형식 제외 (썸네일): ${file.path}');
          return null;
        }

        final isVideo = asset.type == AssetType.video;

        final photo = Photo(
          id: asset.id,
          path: file.path,
          date: asset.createDateTime,
          asset: asset,
          isVideo: isVideo,
        );

        // 썸네일 캐시에 저장
        _cachedThumbnails[album.id] = photo;

        return photo;
      } catch (e) {
        debugPrint('앨범 썸네일 로드 중 오류 발생: ${asset.id} - $e');
        return null;
      }
    } catch (e) {
      debugPrint('앨범 썸네일 로드 중 오류 발생: $e');
      return null;
    }
  }

  // 캐시 초기화
  void clearDeviceAlbumsCache() {
    _cachedDeviceAlbums = null;
    _cachedThumbnails.clear();
    _lastDeviceAlbumsLoadTime = null;
  }

  // 선택된 이미지 ID들을 반환하는 getter
  Set<String> get selectedPhotoIds => _selectedPhotoIds;

  // 이미지 선택 상태를 토글하는 메서드
  void togglePhotoSelection(String photoId) {
    if (_selectedPhotoIds.contains(photoId)) {
      _selectedPhotoIds.remove(photoId);
    } else {
      _selectedPhotoIds.add(photoId);
    }
    notifyListeners();
  }

  // 모든 선택을 해제하는 메서드
  void clearSelection() {
    _selectedPhotoIds.clear();
    notifyListeners();
  }

  // 선택된 이미지들의 Photo 객체 리스트를 반환하는 getter
  List<Photo> get selectedPhotos {
    return _photos
        .where((photo) => _selectedPhotoIds.contains(photo.id))
        .toList();
  }

  // Android 12 이상인지 확인하는 헬퍼 메서드
  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 31; // Android 12는 SDK 31
  }

  // Android 13 이상인지 확인하는 헬퍼 메서드
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33; // Android 13은 SDK 33
  }
}
