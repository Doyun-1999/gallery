import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:flutter/rendering.dart';

class AlbumScreen extends StatefulWidget {
  final String albumId;

  const AlbumScreen({super.key, required this.albumId});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final Map<String, ImageProvider> _imageCache = {};
  final int _maxCacheSize = 50;
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

  void _preloadImages(List<Photo> photos, Range visibleRange) {
    if (_lastPreloadIndex == visibleRange.start) return;
    _lastPreloadIndex = visibleRange.start;

    final preloadRange = Range(visibleRange.start, visibleRange.end + 5);

    for (
      int i = preloadRange.start;
      i < preloadRange.end && i < photos.length;
      i++
    ) {
      _getImageProvider(photos[i].path);
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
              title: const Text('앨범에서 제거'),
              onTap: () {
                galleryModel.removePhotoFromAlbum(photoId, widget.albumId);
                Navigator.pop(context);
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
          title: const Text('앨범 비우기'),
          content: const Text('정말로 이 앨범의 모든 사진을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                for (final photoId
                    in galleryModel.albums
                        .firstWhere((album) => album.id == widget.albumId)
                        .photoIds) {
                  galleryModel.removePhotoFromAlbum(photoId, widget.albumId);
                }
                Navigator.pop(context);
              },
              child: const Text('삭제'),
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
        );
        final photos =
            galleryModel.photos
                .where((photo) => album.photoIds.contains(photo.id))
                .toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final visibleRange = Range(0, 10);
          _preloadImages(photos, visibleRange);
        });

        return Scaffold(
          appBar: AppBar(
            title: Text(album.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showClearAllDialog(context, galleryModel),
              ),
            ],
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
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
                            source: PhotoViewSource.album,
                            albumId: widget.albumId,
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
