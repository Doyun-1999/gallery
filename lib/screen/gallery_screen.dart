import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class GalleryScreen extends StatefulWidget {
  final bool isSelectMode;
  final Set<String> selectedPhotoIds;
  final void Function(String photoId) onPhotoTap;
  final void Function(String photoId) onPhotoLongPress;

  const GalleryScreen({
    super.key,
    required this.isSelectMode,
    required this.selectedPhotoIds,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final Map<String, ImageProvider> _imageCache = {};
  static const int _maxCacheSize = 100;

  @override
  bool get wantKeepAlive => true;

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

  void _onScroll() {
    if (_isLoading) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<GalleryModel>().loadMorePhotos();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final photos = galleryModel.photos.where((p) => !p.isVideo).toList();

        if (photos.isEmpty && !galleryModel.isLoading) {
          return const Center(child: Text('사진이 없습니다.'));
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo is ScrollEndNotification) {
              _onScroll();
            }
            return true;
          },
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: photos.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == photos.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final photo = photos[index];
              return PhotoGridItem(
                photo: photo,
                imageProvider: _getImageProvider(photo.path),
                onTap: () => widget.onPhotoTap(photo.id),
                onLongPress: () => widget.onPhotoLongPress(photo.id),
                isSelectable: widget.isSelectMode,
                isSelected: widget.selectedPhotoIds.contains(photo.id),
                key: ValueKey(photo.id),
              );
            },
          ),
        );
      },
    );
  }
}
