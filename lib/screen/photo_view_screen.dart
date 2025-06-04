// screens/photo_view_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screens/image_editor_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:gallery_memo/widget/memo_dialog.dart';
import 'package:gallery_memo/widget/photo_info_dialog.dart';
import 'package:gallery_memo/widget/delete_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:gallery_memo/widget/photo_control_button.dart';
import 'package:gallery_memo/widget/photo_memo_display.dart';
import 'package:gallery_memo/widget/album_dialogs.dart';
import 'package:video_player/video_player.dart';

class PhotoViewScreen extends StatefulWidget {
  final String photoId;
  final PhotoViewSource source;
  final String? albumId;

  const PhotoViewScreen({
    super.key,
    required this.photoId,
    this.source = PhotoViewSource.gallery,
    this.albumId,
  });

  @override
  PhotoViewScreenState createState() => PhotoViewScreenState();
}

enum PhotoViewSource { gallery, favorites, album }

class PhotoViewScreenState extends State<PhotoViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late String _currentPhotoId;
  bool _showControls = true;
  late AnimationController _animationController;
  String? _currentMemo;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentPhotoId = widget.photoId;

    // 애니메이션 컨트롤러 설정
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 2초 후 컨트롤 자동 숨김
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });

    // 메모 데이터 로드
    _loadMemoData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String path) async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.file(File(path));
    try {
      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
      _videoController!.play();
    } catch (e) {
      debugPrint('비디오 초기화 중 오류 발생: $e');
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final galleryModel = Provider.of<GalleryModel>(context);
    final List<Photo> photoList = _getPhotoList(galleryModel);

    if (photoList.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return;
    }

    final int initialIndex = photoList.indexWhere(
      (photo) => photo.id == widget.photoId,
    );
    if (initialIndex == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return;
    }

    _pageController = PageController(initialPage: initialIndex);
    _loadMemoData();
  }

  List<Photo> _getPhotoList(GalleryModel galleryModel) {
    switch (widget.source) {
      case PhotoViewSource.favorites:
        return galleryModel.favorites;
      case PhotoViewSource.album:
        if (widget.albumId != null) {
          return galleryModel.getAlbumPhotos(widget.albumId!);
        }
        return galleryModel.photos;
      case PhotoViewSource.gallery:
        return galleryModel.photos;
    }
  }

  Future<void> _loadMemoData() async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final photo = galleryModel.photos.firstWhere(
      (photo) => photo.id == _currentPhotoId,
      orElse: () => galleryModel.photos.first,
    );

    setState(() {
      _currentMemo = photo.memo;
    });

    if (photo.isVideo) {
      await _initializeVideo(photo.path);
    } else {
      _videoController?.dispose();
      _videoController = null;
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  void _showMemoDialog(Photo photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MemoDialog(photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final List<Photo> photoList = _getPhotoList(galleryModel);

        if (photoList.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('사진 보기')),
            body: const Center(child: Text('사진을 찾을 수 없습니다.')),
          );
        }

        final currentPhoto = photoList.firstWhere(
          (photo) => photo.id == _currentPhotoId,
          orElse: () => photoList.first,
        );

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar:
              _showControls
                  ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(
                          currentPhoto.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              currentPhoto.isFavorite
                                  ? Colors.red
                                  : Colors.white,
                        ),
                        onPressed: () {
                          galleryModel.toggleFavorite(currentPhoto.id);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_to_photos,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder:
                                (context) =>
                                    AddToAlbumDialog(photoId: currentPhoto.id),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.white),
                        onPressed: () {
                          _showPhotoInfoDialog(context, currentPhoto);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteDialog(context, currentPhoto);
                        },
                      ),
                    ],
                  )
                  : null,
          body: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child:
                    currentPhoto.isVideo && _isVideoInitialized
                        ? Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        )
                        : PhotoViewGallery.builder(
                          scrollPhysics: const BouncingScrollPhysics(),
                          builder: (BuildContext context, int index) {
                            final photo = photoList[index];
                            return PhotoViewGalleryPageOptions(
                              imageProvider: FileImage(File(photo.path)),
                              initialScale: PhotoViewComputedScale.contained,
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 2,
                              onScaleEnd: (context, details, controllerValue) {
                                setState(() {});
                              },
                            );
                          },
                          itemCount: photoList.length,
                          loadingBuilder:
                              (context, event) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          pageController: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPhotoId = photoList[index].id;
                            });
                            _loadMemoData();
                          },
                        ),
              ),
              if (_showControls && currentPhoto.isVideo && _isVideoInitialized)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.alphaBlend(
                            Colors.black.withAlpha(204),
                            Colors.transparent,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                        ),
                        ValueListenableBuilder(
                          valueListenable: _videoController!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Expanded(
                              child: Slider(
                                value: value.position.inMilliseconds.toDouble(),
                                min: 0,
                                max: value.duration.inMilliseconds.toDouble(),
                                onChanged: (newValue) {
                                  _videoController!.seekTo(
                                    Duration(milliseconds: newValue.toInt()),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder(
                          valueListenable: _videoController!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Text(
                              '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                              style: const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showControls && !currentPhoto.isVideo)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.alphaBlend(
                            Colors.black.withAlpha(204),
                            Colors.transparent,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhotoMemoDisplay(
                          memo: _currentMemo,
                          voiceMemoPath: currentPhoto.voiceMemoPath,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhotoControlButton(
                              icon:
                                  _currentMemo != null
                                      ? Icons.note
                                      : Icons.note_add,
                              onPressed: () => _showMemoDialog(currentPhoto),
                            ),
                            const SizedBox(width: 16),
                            PhotoControlButton(
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ImageEditorScreen(
                                          imagePath: currentPhoto.path,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _showDeleteDialog(BuildContext context, Photo photo) {
    if (photo.voiceMemoPath != null && photo.voiceMemoPath!.isNotEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text("음성 메모 삭제 확인"),
            content: const Text("음성 메모를 삭제하시겠습니까?"),
            actions: [
              CupertinoDialogAction(
                child: const Text("취소"),
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                },
              ),
              CupertinoDialogAction(
                child: const Text("삭제", style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  try {
                    final galleryModel = Provider.of<GalleryModel>(
                      context,
                      listen: false,
                    );

                    // 음성 메모 삭제
                    if (photo.voiceMemoPath != null &&
                        photo.voiceMemoPath!.isNotEmpty) {
                      File(photo.voiceMemoPath!).delete();
                      photo.voiceMemoPath = null;
                    }

                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context); // 다이얼로그 닫기
                    }
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context); // 사진 보기 화면 닫기
                    }
                  } catch (e) {
                    debugPrint('음성 메모 삭제 중 오류 발생: $e');
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('음성 메모 삭제 중 오류가 발생했습니다.')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder:
            (context) => DeleteDialog(
              photo: photo,
              onDelete: () async {
                try {
                  final galleryModel = Provider.of<GalleryModel>(
                    context,
                    listen: false,
                  );
                  await galleryModel.deletePhoto(photo.id);

                  // 다이얼로그 닫기
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // 사진 보기 화면 닫기
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('사진 삭제 중 오류 발생: $e');
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('사진 삭제 중 오류가 발생했습니다.')),
                    );
                  }
                }
              },
            ),
      );
    }
  }

  void _showPhotoInfoDialog(BuildContext context, Photo photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PhotoInfoDialog(photo: photo),
    );
  }
}
