import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

class DeviceAlbumScreen extends StatefulWidget {
  final AssetPathEntity album;

  const DeviceAlbumScreen({super.key, required this.album});

  @override
  State<DeviceAlbumScreen> createState() => _DeviceAlbumScreenState();
}

class _DeviceAlbumScreenState extends State<DeviceAlbumScreen> {
  final Map<String, ImageProvider> _imageCache = {};
  static const int _maxCacheSize = 50;
  List<Photo> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      _photos = await galleryModel.getDeviceAlbumPhotos(widget.album);
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
      _imageCache[path] = FileImage(File(path));
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
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return GestureDetector(
                    onTap: () {
                      // TODO: 사진 상세 보기 구현
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image(
                        image: _getImageProvider(photo.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey,
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
