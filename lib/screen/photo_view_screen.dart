// lib/screen/photo_view_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screens/image_editor_screen.dart';
import 'package:photo_view/photo_view.dart';
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

  @override
  void initState() {
    super.initState();
    _currentPhotoId = widget.photoId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      final photoList = _getPhotoList(galleryModel);
      final initialIndex = photoList.indexWhere((p) => p.id == widget.photoId);

      if (initialIndex != -1) {
        setState(() {
          _pageController = PageController(initialPage: initialIndex);
          _loadDataForCurrentPhoto(galleryModel, photoList[initialIndex]);
          _isLoading = false;
        });
      } else {
        if (Navigator.canPop(context)) Navigator.pop(context);
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final galleryModel = Provider.of<GalleryModel>(context);
    final photoList = _getPhotoList(galleryModel);

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
            },
            itemBuilder: (context, index) {
              final photo = photoList[index];
              if (photo.isVideo) {
                return Container(color: Colors.black);
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
          if (currentPhoto.isVideo)
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Container(
                color: Colors.black,
                child:
                    _isVideoInitialized && _videoController != null
                        ? Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        )
                        : const Center(child: CircularProgressIndicator()),
              ),
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
                    IconButton(
                      icon: const Icon(
                        Icons.add_to_photos,
                        color: Colors.white,
                      ),
                      onPressed:
                          () => _showAddToAlbumDialog(context, currentPhoto.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info, color: Colors.white),
                      onPressed:
                          () => _showPhotoInfoDialog(context, currentPhoto),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteDialog(context, currentPhoto),
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
                        ? _buildVideoControls()
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
        PhotoMemoDisplay(
          memo: _currentMemo,
          voiceMemoPath: photo.voiceMemoPath,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhotoControlButton(
              icon: _currentMemo != null ? Icons.note : Icons.note_add,
              onPressed: () => _showMemoDialog(photo),
            ),
            const SizedBox(width: 16),
            PhotoControlButton(
              icon: Icons.edit,
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ImageEditorScreen(imagePath: photo.path),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoControls() {
    if (!_isVideoInitialized || _videoController == null) return Container();
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
          onPressed:
              () => setState(
                () =>
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play(),
              ),
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
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showAddToAlbumDialog(BuildContext context, String photoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToAlbumDialog(photoId: photoId),
    );
  }

  void _showDeleteDialog(BuildContext context, Photo photo) {
    showCupertinoDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => CupertinoAlertDialog(
            title: Text('${photo.isVideo ? '비디오' : '사진'} 삭제'),
            content: const Text('이 항목을 삭제하시겠습니까? 이 동작은 되돌릴 수 없습니다.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('삭제'),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    final galleryModel = Provider.of<GalleryModel>(
                      context,
                      listen: false,
                    );
                    final success = await galleryModel.deletePhoto(photo.id);
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('삭제에 실패했습니다.')),
                      );
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('삭제 중 오류 발생')),
                      );
                  }
                },
              ),
            ],
          ),
    );
  }

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
}
