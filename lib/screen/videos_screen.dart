import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  VideosScreenState createState() => VideosScreenState();
}

class VideosScreenState extends State<VideosScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  int _lastPreloadIndex = -1;
  List<Photo> _videos = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _updateVideos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateVideos() {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    setState(() {
      _videos = galleryModel.photos.where((photo) => photo.isVideo).toList();
      _isLoading = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      if (!galleryModel.isLoading && galleryModel.hasMore) {
        setState(() {
          _isLoading = true;
        });
        galleryModel.loadMorePhotos().then((_) {
          _updateVideos();
        });
      }
    }
  }

  Future<ImageProvider> _getVideoThumbnail(Photo photo) async {
    if (photo.asset != null) {
      final thumbnail = await photo.asset!.thumbnailData;
      if (thumbnail != null) {
        return MemoryImage(thumbnail);
      }
    }
    return FileImage(File(photo.path));
  }

  void _preloadImages(List<Photo> photos, Range range) {
    if (photos.isEmpty) return;

    final startIndex = range.start;
    final endIndex = range.end;

    if (startIndex > _lastPreloadIndex || endIndex < _lastPreloadIndex - 12) {
      for (int i = startIndex; i < endIndex; i++) {
        if (i < photos.length) {
          _getVideoThumbnail(photos[i]);
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
        if (_isLoading && _videos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_videos.isEmpty) {
          return const Center(
            child: Text('동영상이 없습니다', style: TextStyle(fontSize: 16)),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _preloadImages(_videos, _getVisibleRange());
        });

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels ==
                scrollInfo.metrics.maxScrollExtent) {
              if (!galleryModel.isLoading && galleryModel.hasMore) {
                setState(() {
                  _isLoading = true;
                });
                galleryModel.loadMorePhotos().then((_) {
                  _updateVideos();
                });
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
            itemCount: _videos.length + (galleryModel.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _videos.length && galleryModel.hasMore) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final video = _videos[index];
              return FutureBuilder<ImageProvider>(
                future: _getVideoThumbnail(video),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return PhotoGridItem(
                      photo: video,
                      imageProvider: snapshot.data!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PhotoViewScreen(
                                  photoId: video.id,
                                  source: PhotoViewSource.gallery,
                                ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
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
