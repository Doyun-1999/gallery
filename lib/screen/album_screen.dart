// lib/screen/album_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/album_model.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;

class AlbumScreen extends StatefulWidget {
  final String albumId;

  const AlbumScreen({super.key, required this.albumId});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final Map<String, ImageProvider> _imageCache = {};
  final int _maxCacheSize = 100;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final Set<String> _errorPhotoIds = {};

  // --- 선택 모드 관련 상태 변수 추가 ---
  bool _isSelectMode = false;
  final Set<String> _selectedPhotoIds = {};
  // ------------------------------------

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _imageCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePhotos();
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    // In a real app, you would fetch more data here.
    // For this example, we'll just simulate a delay.
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  // --- 선택 모드 관리 함수 추가 ---
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
  // -------------------------------

  ImageProvider _getImageProvider(String path) {
    if (!_imageCache.containsKey(path)) {
      if (_imageCache.length >= _maxCacheSize) {
        final oldestKey = _imageCache.keys.first;
        _imageCache.remove(oldestKey);
      }

      final file = File(path);
      final imageProvider = FileImage(file, scale: 0.5);
      _imageCache[path] = imageProvider;
    }
    return _imageCache[path]!;
  }

  void _showClearAllDialog(BuildContext context, GalleryModel galleryModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('앨범 비우기'),
          content: const Text('정말로 이 앨범의 모든 사진을 제거하시겠습니까? (앨범에서만 제거됩니다.)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final album = galleryModel.albums.firstWhere(
                  (album) => album.id == widget.albumId,
                );
                final photoIdsToRemove = List<String>.from(album.photoIds);

                for (final photoId in photoIdsToRemove) {
                  galleryModel.removePhotoFromAlbum(photoId, widget.albumId);
                }
                Navigator.pop(context);
              },
              child: const Text('제거'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final album = galleryModel.albums.firstWhere(
          (album) => album.id == widget.albumId,
          orElse: () {
            // Handle case where album is not found, maybe pop the navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
            return Album(
              id: '',
              name: 'Not Found',
              dateCreated: DateTime.now(),
            );
          },
        );
        if (album.id.isEmpty) {
          return const Scaffold(body: Center(child: Text("앨범을 찾을 수 없습니다.")));
        }

        final photos =
            galleryModel.photos
                .where(
                  (photo) =>
                      album.photoIds.contains(photo.id) &&
                      !_errorPhotoIds.contains(photo.id),
                )
                .toList();

        return Scaffold(
          appBar: _buildAppBar(context, galleryModel, album.name),
          body: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: photos.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= photos.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final photo = photos[index];
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
                              source: PhotoViewSource.album,
                              albumId: widget.albumId,
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
                onError: (photoId) {
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _errorPhotoIds.add(photoId);
                      });
                    });
                  }
                },
                key: ValueKey(photo.id),
              );
            },
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    GalleryModel galleryModel,
    String albumName,
  ) {
    if (_isSelectMode) {
      return AppBar(
        title: Text('${_selectedPhotoIds.length}개 선택'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_album_outlined),
            tooltip: '앨범 커버로 설정',
            onPressed:
                _selectedPhotoIds.length == 1
                    ? () {
                      galleryModel.setAlbumCover(
                        widget.albumId,
                        _selectedPhotoIds.first,
                      );
                      _exitSelectMode();
                    }
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: '앨범에서 제거',
            onPressed:
                _selectedPhotoIds.isNotEmpty
                    ? () {
                      for (var photoId in _selectedPhotoIds) {
                        galleryModel.removePhotoFromAlbum(
                          photoId,
                          widget.albumId,
                        );
                      }
                      _exitSelectMode();
                    }
                    : null,
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text(albumName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showClearAllDialog(context, galleryModel),
          ),
        ],
      );
    }
  }
}

class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}
