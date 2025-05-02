// screens/photo_view_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/model/photo_model.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'dart:io';

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
  _PhotoViewScreenState createState() => _PhotoViewScreenState();
}

enum PhotoViewSource { gallery, favorites, album }

class _PhotoViewScreenState extends State<PhotoViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late String _currentPhotoId;
  bool _showControls = true;
  double _currentScale = 1.0;
  bool _isZoomed = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final bool _showingDetails = true;

  @override
  void initState() {
    super.initState();
    _currentPhotoId = widget.photoId;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
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
      default:
        return galleryModel.photos;
    }
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
        final currentIndex = photoList.indexWhere(
          (p) => p.id == _currentPhotoId,
        );

        // 현재 사진의 날짜 형식화 - 이 부분이 누락되었습니다
        final dateFormat = DateFormat('yyyy년 MM월 dd일');
        final String photoDate = dateFormat.format(currentPhoto.dateAdded);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar:
              _showControls
                  ? PreferredSize(
                    preferredSize: Size.fromHeight(
                      !_showingDetails ? kToolbarHeight : kToolbarHeight + 50,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              leading: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              title: Text(
                                '${currentIndex + 1}/${photoList.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              centerTitle: true,
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
                                    galleryModel.toggleFavorite(
                                      currentPhoto.id,
                                    );
                                    _showFavoriteAnimation(
                                      context,
                                      !currentPhoto.isFavorite,
                                    );
                                  },
                                ),
                                PopupMenuButton(
                                  enabled: !_isZoomed,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'album') {
                                      _showAddToAlbumDialog(
                                        context,
                                        galleryModel,
                                        currentPhoto.id,
                                      );
                                    } else if (value == 'info') {
                                      _showPhotoInfo(context, currentPhoto);
                                    } else if (value == 'delete') {
                                      _showDeleteDialog(
                                        context,
                                        galleryModel,
                                        currentPhoto.id,
                                      );
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
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                            if (_animation.value > 0)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _animation.value * 50.0,
                                child: Opacity(
                                  opacity: _animation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          photoDate,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (currentPhoto.isFavorite)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.favorite,
                                                    color: Colors.red,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    '즐겨찾기',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                              ),
                                            const Icon(
                                              Icons.photo,
                                              color: Colors.white70,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getFileSize(currentPhoto.path),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : null,
          body: GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // 향상된 줌 기능을 가진 갤러리 뷰
                  PhotoViewGallery.builder(
                    scrollPhysics:
                        _isZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                    pageController: _pageController,
                    itemCount: photoList.length,
                    onPageChanged: (index) {
                      if (!_isZoomed) {
                        setState(() {
                          _currentPhotoId = photoList[index].id;
                        });
                      }
                    },
                    builder: (context, index) {
                      final photo = photoList[index];

                      return PhotoViewGalleryPageOptions(
                        imageProvider: FileImage(File(photo.path)),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        heroAttributes: PhotoViewHeroAttributes(tag: photo.id),
                        onScaleEnd: (context, details, controllerValue) {
                          setState(() {
                            _currentScale = controllerValue.scale ?? 1.0;
                            _isZoomed = _currentScale > 1.1;
                          });
                        },
                      );
                    },
                    loadingBuilder:
                        (context, event) => Center(
                          child: SizedBox(
                            width: 30.0,
                            height: 30.0,
                            child: CircularProgressIndicator(
                              value:
                                  event == null
                                      ? 0
                                      : event.cumulativeBytesLoaded /
                                          (event.expectedTotalBytes ?? 1),
                            ),
                          ),
                        ),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                  ),

                  // 하단 컨트롤
                  // if (_showControls && !_isZoomed)
                  //   Positioned(
                  //     bottom: 0,
                  //     left: 0,
                  //     right: 0,
                  //     child: Container(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       decoration: BoxDecoration(
                  //         gradient: LinearGradient(
                  //           begin: Alignment.bottomCenter,
                  //           end: Alignment.topCenter,
                  //           colors: [
                  //             Colors.black.withOpacity(0.7),
                  //             Colors.transparent,
                  //           ],
                  //         ),
                  //       ),
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //         children: [
                  //           // IconButton(
                  //           //   icon: const Icon(
                  //           //     Icons.rotate_left,
                  //           //     color: Colors.white,
                  //           //   ),
                  //           //   onPressed: () {
                  //           //     // 이미지 회전 기능 (추가 구현 필요)
                  //           //   },
                  //           // ),

                  //           // IconButton(
                  //           //   icon: const Icon(Icons.crop, color: Colors.white),
                  //           //   onPressed: () {
                  //           //     // 이미지 자르기 기능 (추가 구현 필요)
                  //           //   },
                  //           // ),
                  //           FloatingActionButton(
                  //             heroTag: null,
                  //             mini: true,
                  //             onPressed: () {
                  //               galleryModel.toggleFavorite(currentPhoto.id);
                  //               _showFavoriteAnimation(
                  //                 context,
                  //                 !currentPhoto.isFavorite,
                  //               );
                  //             },
                  //             backgroundColor: Colors.white.withOpacity(0.2),
                  //             child: Icon(
                  //               currentPhoto.isFavorite
                  //                   ? Icons.favorite
                  //                   : Icons.favorite_border,
                  //               color:
                  //                   currentPhoto.isFavorite
                  //                       ? Colors.red
                  //                       : Colors.white,
                  //             ),
                  //           ),

                  //           // IconButton(
                  //           //   icon: const Icon(
                  //           //     Icons.share,
                  //           //     color: Colors.white,
                  //           //   ),
                  //           //   onPressed: () {
                  //           //     // 공유 기능 (추가 구현 필요)
                  //           //   },
                  //           // ),

                  //           // IconButton(
                  //           //   icon: const Icon(Icons.edit, color: Colors.white),
                  //           //   onPressed: () {
                  //           //     // 이미지 편집 기능 (추가 구현 필요)
                  //           //   },
                  //           // ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),

                  // 줌 안내 표시기
                  if (_isZoomed)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '확대 모드 (${(_currentScale * 100).toInt()}%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 줌 모드에서 빠져나오는 힌트
                  if (_isZoomed && _showControls)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '축소하여 다른 사진으로 이동할 수 있습니다',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ),

                  // 좌우 스와이프 힌트
                  if (!_isZoomed && _showControls) ...[
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: currentIndex > 0 ? 0.7 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () {
                                if (currentIndex > 0) {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity:
                              currentIndex < photoList.length - 1 ? 0.7 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () {
                                if (currentIndex < photoList.length - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

  // 사진 삭제 확인 대화상자
  void _showDeleteDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('사진 삭제'),
          content: const Text('이 사진을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await galleryModel.deletePhoto(photoId);

                final photoList = _getPhotoList(galleryModel);
                if (photoList.isEmpty) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showAddToAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Album'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: galleryModel.albums.length,
              itemBuilder: (context, index) {
                final album = galleryModel.albums[index];
                final bool isInAlbum = album.photoIds.contains(photoId);

                return ListTile(
                  title: Text(album.name),
                  trailing:
                      isInAlbum
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                  onTap: () {
                    if (isInAlbum) {
                      galleryModel.removePhotoFromAlbum(photoId, album.id);
                    } else {
                      galleryModel.addPhotoToAlbum(photoId, album.id);
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed:
                  () => _showCreateAlbumDialog(context, galleryModel, photoId),
              child: const Text('Create New Album'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateAlbumDialog(
    BuildContext context,
    GalleryModel galleryModel,
    String photoId,
  ) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Album'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'Album Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  await galleryModel.createAlbum(name);
                  final albumId = galleryModel.albums.last.id;
                  await galleryModel.addPhotoToAlbum(photoId, albumId);
                  Navigator.pop(context);
                  Navigator.pop(context); // Close both dialogs
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
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

  void _showPhotoInfo(BuildContext context, Photo photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '사진 정보',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text('ID: ${photo.id}'),
              const SizedBox(height: 8),
              Text('경로: ${photo.path}'),
              const SizedBox(height: 8),
              Text('추가 날짜: ${_formatDate(photo.dateAdded)}'),
              const SizedBox(height: 8),
              Text('즐겨찾기 상태: ${photo.isFavorite ? "예" : "아니오"}'),
              if (photo.isFavorite && photo.favoritedAt != null)
                Text('즐겨찾기 추가 날짜: ${_formatDate(photo.favoritedAt!)}'),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
