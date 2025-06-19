// lib/widget/photo_grid_item.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGridItem extends StatefulWidget {
  final Photo photo;
  final ImageProvider imageProvider;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectable;
  final bool isSelected;
  final Function(String)? onError;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.imageProvider,
    required this.onTap,
    this.onLongPress,
    this.isSelectable = false,
    this.isSelected = false,
    this.onError,
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
    if (widget.photo.isVideo) {
      _loadVideoThumbnail();
    }
  }

  @override
  void didUpdateWidget(PhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo.asset?.id != oldWidget.photo.asset?.id) {
      _isLoadingThumbnail = false;
      _thumbnailProvider = null;
      if (widget.photo.isVideo) {
        _loadVideoThumbnail();
      }
    }
  }

  Future<void> _loadVideoThumbnail() async {
    if (widget.photo.asset == null || _isLoadingThumbnail) return;

    if (mounted) {
      setState(() {
        _isLoadingThumbnail = true;
      });
    }

    try {
      final thumbnail = await widget.photo.asset!.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
        quality: 80,
      );
      if (!mounted) return;

      if (thumbnail != null) {
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
          _isLoadingThumbnail = false;
        });
        widget.onError?.call(widget.photo.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image(
                  image:
                      widget.photo.isVideo && _thumbnailProvider != null
                          ? _thumbnailProvider!
                          : widget.imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    widget.onError?.call(widget.photo.id);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            if (_isLoadingThumbnail)
              const Center(child: CircularProgressIndicator()),
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
            if (widget.isSelectable)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.isSelected ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            if (widget.isSelectable)
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
    );
  }
}
