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
  bool _isLoading = true;
  List<Photo> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (albums.isEmpty) {
        setState(() {
          _isLoading = false;
          _videos = [];
        });
        return;
      }

      final List<AssetEntity> videoAssets = await albums[0].getAssetListPaged(
        page: 0,
        size: 1000,
      );

      final List<Photo> videos = [];
      for (final asset in videoAssets) {
        final file = await asset.file;
        if (file != null) {
          final photo = Photo(
            id: asset.id,
            path: file.path,
            date: asset.createDateTime,
            asset: asset,
            isVideo: true,
          );
          videos.add(photo);
        }
      }

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      print('비디오 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
        _videos = [];
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text('동영상이 없습니다', style: TextStyle(fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return FutureBuilder<ImageProvider>(
          future: _getVideoThumbnail(video),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return PhotoGridItem(
                photo: video,
                imageProvider: snapshot.data!,
                onTap: () {
                  final galleryModel = Provider.of<GalleryModel>(
                    context,
                    listen: false,
                  );
                  galleryModel.photos.addAll(_videos);

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
    );
  }
}
