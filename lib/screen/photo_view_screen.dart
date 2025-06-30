// lib/screen/photo_view_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/image_editor_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:gallery_memo/widget/memo_dialog.dart';
import 'package:gallery_memo/widget/photo_info_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:gallery_memo/widget/photo_control_button.dart';
import 'package:gallery_memo/widget/photo_memo_display.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoViewScreen extends StatefulWidget {
  final String photoId;
  final PhotoViewSource source;
  final String? albumId;
  final AssetPathEntity? deviceAlbum;
  final List<Photo>? videos;

  const PhotoViewScreen({
    super.key,
    required this.photoId,
    this.source = PhotoViewSource.gallery,
    this.albumId,
    this.deviceAlbum,
    this.videos,
  });

  @override
  PhotoViewScreenState createState() => PhotoViewScreenState();
}

enum PhotoViewSource { gallery, favorites, album, video }

class PhotoViewScreenState extends State<PhotoViewScreen> {
  PageController? _pageController;
  bool _isLoading = true;

  late String _currentPhotoId;
  bool _showControls = true;
  String? _currentMemo;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // 제스처 충돌 해결을 위한 상태 변수
  bool _isZooming = false;

  // 기기 앨범 사진들을 위한 상태 변수
  var _deviceAlbumPhotos = <Photo>[];
  var _isLoadingDevicePhotos = false;

  @override
  void initState() {
    super.initState();
    _currentPhotoId = widget.photoId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.deviceAlbum != null) {
        // 기기 앨범인 경우 사진들을 로드
        _loadDeviceAlbumPhotos();
      } else {
        // 일반 앨범인 경우 기존 로직 사용
        final galleryModel = Provider.of<GalleryModel>(context, listen: false);
        final photoList = _getPhotoList(galleryModel);
        final initialIndex = photoList.indexWhere(
          (p) => p.id == widget.photoId,
        );

        if (initialIndex != -1) {
          setState(() {
            _pageController = PageController(initialPage: initialIndex);
            _loadDataForCurrentPhoto(galleryModel, photoList[initialIndex]);
            _isLoading = false;
          });
        } else {
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String path) async {
    try {
      await _videoController?.dispose();
      _videoController = null;
      if (!mounted) return;

      final file = File(path);
      if (!await file.exists()) throw Exception('Video file not found');

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      await _videoController!.setVolume(1.0);
      await _videoController!.play();
      _videoController!.setLooping(true);

      if (mounted) setState(() => _isVideoInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _isVideoInitialized = false);
    }
  }

  List<Photo> _getPhotoList(GalleryModel galleryModel) {
    switch (widget.source) {
      case PhotoViewSource.favorites:
        return galleryModel.favorites;
      case PhotoViewSource.album:
        if (widget.albumId == null) return [];
        return galleryModel.getAlbumPhotos(widget.albumId!);
      case PhotoViewSource.video:
        // 전달받은 비디오 목록이 있으면 사용, 없으면 빈 리스트
        return widget.videos ?? [];
      default:
        return galleryModel.photos;
    }
  }

  void _loadDataForCurrentPhoto(GalleryModel galleryModel, Photo photo) {
    if (!mounted) return;

    setState(() {
      _currentMemo = photo.memo;
    });

    if (photo.isVideo) {
      _initializeVideo(photo.path);
    } else {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() => _isVideoInitialized = false);
    }
  }

  // 메모 업데이트 콜백 함수
  void _onMemoUpdated(String? newMemo) {
    if (mounted) {
      setState(() {
        _currentMemo = newMemo;
      });
    }
  }

  void _showMemoDialog(Photo photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => MemoDialog(photo: photo, onMemoUpdated: _onMemoUpdated),
    );
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    setState(() {}); // UI 업데이트를 위해 setState 호출
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingDevicePhotos) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final galleryModel = Provider.of<GalleryModel>(context);
    final photoList =
        widget.deviceAlbum != null
            ? _deviceAlbumPhotos
            : _getPhotoList(galleryModel);

    if (photoList.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('사진 보기'),
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('사진을 찾을 수 없습니다.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentPhoto = photoList.firstWhere(
      (photo) => photo.id == _currentPhotoId,
      orElse: () => photoList.first,
    );

    // 현재 사진의 메모 상태를 실시간으로 감지하고 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentMemo != currentPhoto.memo) {
        setState(() {
          _currentMemo = currentPhoto.memo;
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController!,
            // 제스처 충돌 해결을 위해 physics 속성 설정
            physics:
                _isZooming
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
            itemCount: photoList.length,
            onPageChanged: (index) {
              setState(() => _currentPhotoId = photoList[index].id);
              _loadDataForCurrentPhoto(galleryModel, photoList[index]);

              // 마지막 5개 항목에 도달하면 더 많은 사진 로드
              if (index >= photoList.length - 5) {
                final galleryModelProvider = Provider.of<GalleryModel>(
                  context,
                  listen: false,
                );
                if (galleryModelProvider.hasMore &&
                    !galleryModelProvider.isLoading) {
                  galleryModelProvider.loadMorePhotos();
                }
              }
            },
            itemBuilder: (context, index) {
              final photo = photoList[index];
              if (photo.isVideo) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _showControls = !_showControls);
                  },
                  child: Container(
                    color: Colors.black,
                    child:
                        _isVideoInitialized && _videoController != null
                            ? Center(
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                            : const Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              return PhotoView(
                key: ValueKey(photo.id),
                imageProvider: FileImage(File(photo.path)),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4.0,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'photo_${photo.id}',
                ),
                onTapUp: (context, details, controllerValue) {
                  setState(() => _showControls = !_showControls);
                },
                // 확대/축소 상태 감지
                scaleStateChangedCallback: (PhotoViewScaleState scaleState) {
                  setState(() {
                    _isZooming = scaleState != PhotoViewScaleState.initial;
                  });
                },
              );
            },
          ),
          _buildControlsOverlay(context, currentPhoto),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context, Photo currentPhoto) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.4),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (!currentPhoto.isVideo) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ImageEditorScreen(
                                      imagePath: currentPhoto.path,
                                    ),
                              ),
                            ),
                      ),
                    ],
                    IconButton(
                      icon: Icon(
                        currentPhoto.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color:
                            currentPhoto.isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed:
                          () => Provider.of<GalleryModel>(
                            context,
                            listen: false,
                          ).toggleFavorite(currentPhoto.id),
                    ),
                    // IconButton(
                    //   icon: const Icon(
                    //     Icons.add_to_photos,
                    //     color: Colors.white,
                    //   ),
                    //   onPressed:
                    //       () => _showAddToAlbumDialog(context, currentPhoto.id),
                    // ),
                    IconButton(
                      icon: const Icon(Icons.info, color: Colors.white),
                      onPressed:
                          () => _showPhotoInfoDialog(context, currentPhoto),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final galleryModel = Provider.of<GalleryModel>(
                          context,
                          listen: false,
                        );
                        final success = await galleryModel.deletePhoto(
                          currentPhoto.id,
                        );
                        if (success && mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(
                  16,
                ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child:
                    currentPhoto.isVideo
                        ? _buildVideoControls(currentPhoto)
                        : _buildPhotoControls(currentPhoto),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoControls(Photo photo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_currentMemo != null && _currentMemo!.isNotEmpty)
          PhotoMemoDisplay(
            memo: _currentMemo,
            voiceMemoPath: photo.voiceMemoPath,
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhotoControlButton(
              icon:
                  _currentMemo != null && _currentMemo!.isNotEmpty
                      ? Icons.note
                      : Icons.note_add,
              onPressed: () => _showMemoDialog(photo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoControls(Photo photo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_currentMemo != null && _currentMemo!.isNotEmpty)
          PhotoMemoDisplay(
            memo: _currentMemo,
            voiceMemoPath: photo.voiceMemoPath,
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhotoControlButton(
              icon:
                  _currentMemo != null && _currentMemo!.isNotEmpty
                      ? Icons.note
                      : Icons.note_add,
              onPressed: () => _showMemoDialog(photo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isVideoInitialized && _videoController != null)
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _toggleVideoPlayback,
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _videoController!,
                  builder: (context, VideoPlayerValue value, child) {
                    return Slider(
                      value: value.position.inMilliseconds.toDouble().clamp(
                        0.0,
                        value.duration.inMilliseconds.toDouble(),
                      ),
                      min: 0,
                      max: value.duration.inMilliseconds.toDouble(),
                      onChanged:
                          (newValue) => _videoController!.seekTo(
                            Duration(milliseconds: newValue.toInt()),
                          ),
                    );
                  },
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _videoController!,
                builder:
                    (context, VideoPlayerValue value, child) => Text(
                      '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // void _showAddToAlbumDialog(BuildContext context, String photoId) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     isScrollControlled: true,
  //     builder: (context) => AddToAlbumDialog(photoId: photoId),
  //   );
  // }

  void _showPhotoInfoDialog(BuildContext context, Photo photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: PhotoInfoDialog(photo: photo),
          ),
    );
  }

  Future<void> _loadDeviceAlbumPhotos() async {
    if (widget.deviceAlbum == null) return;

    setState(() {
      _isLoadingDevicePhotos = true;
    });

    try {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      final photos = await galleryModel.getDeviceAlbumPhotos(
        widget.deviceAlbum!,
      );

      if (mounted) {
        setState(() {
          _deviceAlbumPhotos = photos;
          _isLoadingDevicePhotos = false;
        });

        // 현재 사진의 인덱스 찾기
        final initialIndex = photos.indexWhere((p) => p.id == widget.photoId);
        if (initialIndex != -1) {
          setState(() {
            _pageController = PageController(initialPage: initialIndex);
            _loadDataForCurrentPhoto(galleryModel, photos[initialIndex]);
            _isLoading = false;
          });
        } else {
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDevicePhotos = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 로드 중 오류 발생: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
