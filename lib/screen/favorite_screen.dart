// screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'photo_view_screen.dart';
import 'package:gallery/widget/photo_grid_item.dart';

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

  @override
  void dispose() {
    _imageCache.clear();
    super.dispose();
  }

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

        if (favorites.isEmpty) {
          return const Center(child: Text('아직 즐겨찾기에 추가된 사진이 없습니다.'));
        }

        // 빌드 후에 프리로드 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadImages(favorites);
        });

        return Scaffold(
          appBar: AppBar(
            title: Text('즐겨찾기 (${favorites.length})'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(
                  _showRecent ? Icons.access_time : Icons.photo_library,
                ),
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
          ),
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
                onTap: () {
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
                },
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  void _showQuickActions(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle),
              title: const Text('즐겨찾기에서 제거'),
              onTap: () {
                galleryModel.removeFavorite(photoId);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_photos),
              title: const Text('앨범에 추가'),
              onTap: () {
                Navigator.pop(context);
                _showAddToAlbumDialog(context, galleryModel, photoId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('공유'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
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

  void _showAddToAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Album'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: galleryModel.albums.length,
              itemBuilder: (context, index) {
                final album = galleryModel.albums[index];
                final bool isInAlbum = album.photoIds.contains(photoId);

                return ListTile(
                  title: Text(album.name),
                  trailing:
                      isInAlbum
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                  onTap: () {
                    if (isInAlbum) {
                      galleryModel.removePhotoFromAlbum(photoId, album.id);
                    } else {
                      galleryModel.addPhotoToAlbum(photoId, album.id);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed:
                  () => _showCreateAlbumDialog(context, galleryModel, photoId),
              child: const Text('Create New Album'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Album'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'Album Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await galleryModel.createAlbum(name);
                  final albumId = galleryModel.albums.last.id;
                  await galleryModel.addPhotoToAlbum(photoId, albumId);
                  Navigator.pop(context);
                  Navigator.pop(context); // Close both dialogs
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
