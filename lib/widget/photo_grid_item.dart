import 'package:flutter/material.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:gallery_memo/model/gallery_model.dart';

class PhotoGridItem extends StatefulWidget {
  final Photo photo;
  final ImageProvider imageProvider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectable; // 선택 모드 여부
  final bool isSelected; // 추가

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.imageProvider,
    required this.onTap,
    this.onLongPress,
    this.isSelectable = false,
    this.isSelected = false, // 추가
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  ImageProvider? _thumbnailProvider;
  bool _isLoadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    if (widget.photo.isVideo && widget.photo.asset != null) {
      _loadVideoThumbnail();
    }
  }

  @override
  void didUpdateWidget(PhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo.isVideo &&
        widget.photo.asset != null &&
        (oldWidget.photo.asset?.id != widget.photo.asset?.id ||
            _thumbnailProvider == null)) {
      _loadVideoThumbnail();
    }
  }

  Future<void> _loadVideoThumbnail() async {
    if (widget.photo.asset == null || _isLoadingThumbnail) return;

    setState(() {
      _isLoadingThumbnail = true;
    });

    try {
      final thumbnail = await widget.photo.asset!.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
        quality: 80,
      );
      if (thumbnail != null && mounted) {
        setState(() {
          _thumbnailProvider = MemoryImage(thumbnail);
          _isLoadingThumbnail = false;
        });
      } else {
        throw Exception('썸네일을 생성할 수 없습니다.');
      }
    } catch (e) {
      debugPrint('동영상 썸네일 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _thumbnailProvider = const AssetImage('assets/logo/logo.png');
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  void _handleLongPress() {
    if (!widget.isSelectable) {
      final galleryModel = Provider.of<GalleryModel>(context, listen: false);
      galleryModel.togglePhotoSelection(widget.photo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final isSelected = galleryModel.selectedPhotoIds.contains(
          widget.photo.id,
        );

        return GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Hero(
            tag: 'photo_${widget.photo.id}',
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.1),
                      image:
                          widget.photo.isVideo && _thumbnailProvider != null
                              ? DecorationImage(
                                image: _thumbnailProvider!,
                                fit: BoxFit.cover,
                              )
                              : DecorationImage(
                                image: widget.imageProvider,
                                fit: BoxFit.cover,
                                onError: (exception, stackTrace) {
                                  debugPrint('이미지 로드 오류: $exception');
                                },
                              ),
                    ),
                    child:
                        _isLoadingThumbnail
                            ? const Center(child: CircularProgressIndicator())
                            : null,
                  ),
                  if (widget.photo.isVideo)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (widget.isSelectable || widget.isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              widget.isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.white.withOpacity(0.8),
                          border: Border.all(
                            color:
                                widget.isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child:
                            widget.isSelected
                                ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
