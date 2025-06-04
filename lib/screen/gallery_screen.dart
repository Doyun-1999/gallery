import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final Map<String, ImageProvider> _imageCache = {};
  static const int _maxCacheSize = 50;
  int _lastPreloadIndex = -1;

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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      if (!galleryModel.isLoading && galleryModel.hasMore) {
        galleryModel.loadMorePhotos();
      }
    }
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
    final firstVisibleItem = (_scrollController.position.pixels / 300).floor();
    final lastVisibleItem = firstVisibleItem + 12;
    return Range(firstVisibleItem, lastVisibleItem);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final photos = galleryModel.photos;

        if (photos.isNotEmpty) {
          _isLoading = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _preloadImages(photos);
          });
        }

        if (_isLoading && photos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels ==
                scrollInfo.metrics.maxScrollExtent) {
              if (!galleryModel.isLoading && galleryModel.hasMore) {
                galleryModel.loadMorePhotos();
              }
            }
            return true;
          },
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: photos.length + (galleryModel.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == photos.length && galleryModel.hasMore) {
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PhotoViewScreen(
                            photoId: photo.id,
                            source: PhotoViewSource.gallery,
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
}

class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}
