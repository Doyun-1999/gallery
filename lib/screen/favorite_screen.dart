// lib/screen/favorite_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/widget/album_dialogs.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';

class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _showRecent = true;
  final Map<String, ImageProvider> _imageCache = {};
  static const int _maxCacheSize = 50;
  int _lastPreloadIndex = -1;

  // --- 선택 모드 관련 상태 변수 추가 ---
  bool _isSelectMode = false;
  final Set<String> _selectedPhotoIds = {};
  // ------------------------------------

  @override
  void dispose() {
    _imageCache.clear();
    super.dispose();
  }

  // --- 선택 모드 진입/종료 및 토글 함수 추가 ---
  void _enterSelectMode() {
    if (!_isSelectMode) {
      setState(() {
        _isSelectMode = true;
      });
    }
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedPhotoIds.clear();
    });
  }

  void _togglePhotoSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }
  // -----------------------------------------

  ImageProvider _getImageProvider(String path) {
    if (!_imageCache.containsKey(path)) {
      if (_imageCache.length >= _maxCacheSize) {
        final oldestKey = _imageCache.keys.first;
        _imageCache.remove(oldestKey);
      }

      final file = File(path);
      final imageProvider = ResizeImage(
        FileImage(file),
        width: 300,
        allowUpscaling: false,
        policy: ResizeImagePolicy.fit,
      );
      _imageCache[path] = imageProvider;
    }
    return _imageCache[path]!;
  }

  void _preloadImages(List<Photo> photos) {
    if (photos.isEmpty) return;

    final visibleRange = _getVisibleRange();
    final startIndex = visibleRange.start;
    final endIndex = visibleRange.end;

    if (startIndex > _lastPreloadIndex || endIndex < _lastPreloadIndex - 12) {
      for (int i = startIndex; i < endIndex; i++) {
        if (i < photos.length) {
          _getImageProvider(photos[i].path);
        }
      }
      _lastPreloadIndex = startIndex;
    }
  }

  Range _getVisibleRange() {
    const firstVisibleItem = 0; // 즐겨찾기 화면은 스크롤 위치가 고정되어 있으므로 0부터 시작
    const lastVisibleItem = 12; // 한 번에 보여줄 아이템 수
    return Range(firstVisibleItem, lastVisibleItem);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final favorites =
            _showRecent
                ? galleryModel.favoritesByRecent
                : galleryModel.favorites;

        if (favorites.isEmpty && !_isSelectMode) {
          return Scaffold(
            appBar: _buildAppBar(galleryModel),
            body: const Center(child: Text('아직 즐겨찾기에 추가된 사진이 없습니다.')),
          );
        }

        // 빌드 후에 프리로드 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadImages(favorites);
        });

        return Scaffold(
          appBar: _buildAppBar(galleryModel),
          body: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final photo = favorites[index];
              return PhotoGridItem(
                photo: photo,
                imageProvider: _getImageProvider(photo.path),
                isSelectable: _isSelectMode,
                isSelected: _selectedPhotoIds.contains(photo.id),
                onTap: () {
                  if (_isSelectMode) {
                    _togglePhotoSelection(photo.id);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PhotoViewScreen(
                              photoId: photo.id,
                              source: PhotoViewSource.favorites,
                            ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  if (!_isSelectMode) {
                    _enterSelectMode();
                    _togglePhotoSelection(photo.id);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(GalleryModel galleryModel) {
    if (_isSelectMode) {
      return AppBar(
        title: Text('${_selectedPhotoIds.length}개 선택'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.heart_broken),
            tooltip: '즐겨찾기에서 제거',
            onPressed:
                _selectedPhotoIds.isEmpty
                    ? null
                    : () {
                      for (var photoId in _selectedPhotoIds) {
                        galleryModel.toggleFavorite(photoId);
                      }
                      _exitSelectMode();
                    },
          ),
          // IconButton(
          //   icon: const Icon(Icons.playlist_add),
          //   tooltip: '앨범에 추가',
          //   onPressed:
          //       _selectedPhotoIds.isEmpty
          //           ? null
          //           : () => _addSelectedPhotosToAlbum(context),
          // ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '삭제',
            onPressed:
                _selectedPhotoIds.isEmpty
                    ? null
                    : () => _deleteSelectedPhotos(context, galleryModel),
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text('즐겨찾기 (${galleryModel.favorites.length})'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showRecent ? Icons.access_time : Icons.photo_library),
            onPressed: () {
              setState(() {
                _showRecent = !_showRecent;
              });
            },
            tooltip: _showRecent ? '최근 즐겨찾기 순' : '기본 순서',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearAllDialog(context, galleryModel),
            tooltip: '모든 즐겨찾기 삭제',
          ),
        ],
      );
    }
  }

  void _addSelectedPhotosToAlbum(BuildContext context) {
    if (_selectedPhotoIds.isNotEmpty) {
      // 여러 사진을 추가하는 로직이 필요하지만,
      // 현재 다이얼로그는 한 번에 한 사진만 처리하므로, 첫 번째 사진 ID를 전달합니다.
      // 또는 여러 사진을 한 번에 처리하도록 AddToAlbumDialog를 수정해야 합니다.
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (context) => AddToAlbumDialog(photoId: _selectedPhotoIds.first),
      );
    }
  }

  Future<void> _deleteSelectedPhotos(
    BuildContext context,
    GalleryModel galleryModel,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('사진 삭제'),
            content: Text('${_selectedPhotoIds.length}개의 항목을 기기에서 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final Set<String> idsToDelete = Set.from(_selectedPhotoIds);
      for (final photoId in idsToDelete) {
        await galleryModel.deletePhoto(photoId);
      }
      _exitSelectMode();
    }
  }

  void _showClearAllDialog(BuildContext context, GalleryModel galleryModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모든 즐겨찾기 삭제'),
          content: const Text('정말로 모든 즐겨찾기를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                galleryModel.clearAllFavorites();
                Navigator.pop(context);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }
}
