// screens/photo_view_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:gallery/widget/memo_dialog.dart';
import 'package:gallery/widget/album_dialog.dart';
import 'package:gallery/widget/photo_info_dialog.dart';
import 'package:gallery/widget/delete_dialog.dart';

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
  final double _currentScale = 1.0;
  bool _isZoomed = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final bool _showingDetails = true;
  final _audioRecorder = AudioRecorder();
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentVoiceMemoPath;
  String? _currentMemo;

  @override
  void initState() {
    super.initState();
    _currentPhotoId = widget.photoId;
    _audioPlayer = AudioPlayer();

    // 애니메이션 컨트롤러 설정
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final galleryModel = Provider.of<GalleryModel>(context);
    final List<Photo> photoList = _getPhotoList(galleryModel);

    final int initialIndex = photoList.indexWhere(
      (photo) => photo.id == widget.photoId,
    );
    if (initialIndex == -1) {
      Navigator.pop(context);
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

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _currentVoiceMemoPath = path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('녹음 시작 중 오류가 발생했습니다.')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final galleryModel = Provider.of<GalleryModel>(context, listen: false);
        await galleryModel.addVoiceMemo(_currentPhotoId, path);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('녹음 중지 중 오류가 발생했습니다.')));
    }
  }

  Future<void> _playVoiceMemo(String path) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (_audioPlayer.playing) {
          await _audioPlayer.play();
        } else {
          await _audioPlayer.setFilePath(path);
          await _audioPlayer.play();
        }
        setState(() {
          _isPlaying = true;
        });

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('음성 메모 재생 중 오류가 발생했습니다.')));
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _loadMemoData() async {
    final galleryModel = Provider.of<GalleryModel>(context, listen: false);
    final photo = galleryModel.photos.firstWhere(
      (photo) => photo.id == _currentPhotoId,
      orElse: () => galleryModel.photos.first,
    );

    setState(() {
      _currentVoiceMemoPath = photo.voiceMemoPath;
      _currentMemo = photo.memo;
    });
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

        // 현재 사진의 메모 가져오기
        final currentMemo = galleryModel.getMemo(_currentPhotoId);

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
                      PopupMenuButton(
                        enabled: !_isZoomed,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'album') {
                            _showAddToAlbumDialog(
                              context,
                              galleryModel,
                              currentPhoto.id,
                            );
                          } else if (value == 'info') {
                            _showPhotoInfoDialog(context, currentPhoto);
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, currentPhoto);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'album',
                                child: ListTile(
                                  leading: Icon(Icons.add_to_photos),
                                  title: Text('앨범에 추가'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'info',
                                child: ListTile(
                                  leading: Icon(Icons.info),
                                  title: Text('정보'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    '삭제',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
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
                child: PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    final photo = photoList[index];
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(File(photo.path)),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                      onScaleEnd: (context, details, controllerValue) {
                        setState(() {
                          _isZoomed = (controllerValue.scale ?? 1.0) > 1.0;
                        });
                      },
                    );
                  },
                  itemCount: photoList.length,
                  loadingBuilder:
                      (context, event) =>
                          const Center(child: CircularProgressIndicator()),
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPhotoId = photoList[index].id;
                    });
                    _loadMemoData();
                  },
                ),
              ),
              if (_showControls)
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
                        // 메모 표시
                        if (currentMemo != null && currentMemo.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                Colors.white.withAlpha(26),
                                Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.note,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentMemo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 컨트롤 버튼
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(
                              icon:
                                  currentMemo != null ||
                                          _currentVoiceMemoPath != null
                                      ? Icons.note
                                      : Icons.note_add,
                              onPressed: () => _showMemoDialog(currentPhoto),
                            ),
                            const SizedBox(width: 24),
                            _buildControlButton(
                              icon: _isRecording ? Icons.stop : Icons.mic,
                              color: _isRecording ? Colors.red : Colors.white,
                              onPressed:
                                  _isRecording
                                      ? _stopRecording
                                      : _startRecording,
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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              Colors.white.withAlpha(51),
              Colors.transparent,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  String _getFileSize(String filepath) {
    final file = File(filepath);
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showDeleteDialog(BuildContext context, Photo photo) {
    showDialog(
      context: context,
      builder:
          (context) => DeleteDialog(
            photo: photo,
            onDelete: () {
              final galleryModel = Provider.of<GalleryModel>(
                context,
                listen: false,
              );
              galleryModel.deletePhoto(photo.id);
              Navigator.pop(context);
            },
          ),
    );
  }

  void _showAddToAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlbumDialog(photoId: photoId),
    );
  }

  void _showFavoriteAnimation(BuildContext context, bool adding) {
    if (adding) {
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) {
          Future.delayed(const Duration(milliseconds: 800), () {
            Navigator.of(context).pop();
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 1.5),
                    child: Opacity(
                      opacity: value > 0.5 ? 2.0 - (value * 2.0) : value * 2.0,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 100,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
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
