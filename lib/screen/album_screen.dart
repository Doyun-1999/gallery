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
  final int _maxCacheSize = 100;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  static const int _pageSize = 30;

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
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _isLoadingMore = false);
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
        width: 200,
        allowUpscaling: false,
        policy: ResizeImagePolicy.fit,
      );
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
          body: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
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
