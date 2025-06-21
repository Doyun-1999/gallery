import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';

class DeviceAlbumScreen extends StatefulWidget {
  final AssetPathEntity album;

  const DeviceAlbumScreen({super.key, required this.album});

  @override
  State<DeviceAlbumScreen> createState() => _DeviceAlbumScreenState();
}

class _DeviceAlbumScreenState extends State<DeviceAlbumScreen> {
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, Uint8List?> _thumbnailCache = {};
  static const int _maxCacheSize = 100;
  List<Photo> _photos = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  int _currentPage = 0;
  final Set<String> _errorPhotoIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPhotos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _imageCache.clear();
    _thumbnailCache.clear();
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

    try {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      final newPhotos = await galleryModel.getDeviceAlbumPhotos(
        widget.album,
        page: _currentPage + 1,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _photos.addAll(newPhotos);
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      _photos = await galleryModel.getDeviceAlbumPhotos(
        widget.album,
        page: 0,
        pageSize: _pageSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (!_imageCache.containsKey(path)) {
      if (_imageCache.length >= _maxCacheSize) {
        _imageCache.remove(_imageCache.keys.first);
      }
      final file = File(path);
      final imageProvider = FileImage(file, scale: 0.5);
      _imageCache[path] = imageProvider;
    }
    return _imageCache[path]!;
  }

  Future<Uint8List?> _getThumbnailData(Photo photo) async {
    if (!_thumbnailCache.containsKey(photo.id)) {
      if (_thumbnailCache.length >= _maxCacheSize) {
        _thumbnailCache.remove(_thumbnailCache.keys.first);
      }

      try {
        if (photo.asset != null) {
          final thumbnailData = await photo.asset!.thumbnailData;
          _thumbnailCache[photo.id] = thumbnailData;
        } else {
          _thumbnailCache[photo.id] = null;
        }
      } catch (e) {
        debugPrint('썸네일 로드 실패: ${photo.id} - $e');
        _thumbnailCache[photo.id] = null;
      }
    }
    return _thumbnailCache[photo.id];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.name)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _photos.isEmpty
              ? const Center(child: Text('사진이 없습니다.'))
              : GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount:
                    _photos
                        .where((p) => !_errorPhotoIds.contains(p.id))
                        .length +
                    (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  final displayPhotos =
                      _photos
                          .where((p) => !_errorPhotoIds.contains(p.id))
                          .toList();

                  if (index >= displayPhotos.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final photo = displayPhotos[index];
                  return FutureBuilder<Uint8List?>(
                    future:
                        photo.isVideo
                            ? _getThumbnailData(photo)
                            : Future.value(null),
                    builder: (context, snapshot) {
                      ImageProvider imageProvider;

                      if (photo.isVideo &&
                          snapshot.hasData &&
                          snapshot.data != null) {
                        // 동영상인 경우 썸네일 데이터 사용
                        imageProvider = MemoryImage(snapshot.data!);
                      } else {
                        // 이미지인 경우 파일 경로 사용
                        imageProvider = _getImageProvider(photo.path);
                      }

                      return PhotoGridItem(
                        photo: photo,
                        imageProvider: imageProvider,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PhotoViewScreen(
                                    photoId: photo.id,
                                    source: PhotoViewSource.video,
                                    deviceAlbum: widget.album,
                                  ),
                            ),
                          );
                        },
                        onLongPress: () {},
                        isSelectable: false,
                        isSelected: false,
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
                  );
                },
              ),
    );
  }
}
