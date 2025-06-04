import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';

class DeviceAlbumScreen extends StatefulWidget {
  final AssetPathEntity album;

  const DeviceAlbumScreen({super.key, required this.album});

  @override
  State<DeviceAlbumScreen> createState() => _DeviceAlbumScreenState();
}

class _DeviceAlbumScreenState extends State<DeviceAlbumScreen> {
  final Map<String, ImageProvider> _imageCache = {};
  static const int _maxCacheSize = 100;
  List<Photo> _photos = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  static const int _pageSize = 30;
  int _currentPage = 0;

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
                itemCount: _photos.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _photos.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final photo = _photos[index];
                  return PhotoGridItem(
                    photo: photo,
                    imageProvider: _getImageProvider(photo.path),
                    onTap: () {
                      // TODO: 사진 상세 보기 구현
                    },
                    onLongPress: () {},
                    isSelectable: false,
                    isSelected: false,
                    key: ValueKey(photo.id),
                  );
                },
              ),
    );
  }
}
