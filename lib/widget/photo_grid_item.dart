import 'package:flutter/material.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGridItem extends StatefulWidget {
  final Photo photo;
  final ImageProvider imageProvider;
  final VoidCallback onTap;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.imageProvider,
    required this.onTap,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  ImageProvider? _thumbnailProvider;

  @override
  void initState() {
    super.initState();
    if (widget.photo.isVideo && widget.photo.asset != null) {
      _loadVideoThumbnail();
    }
  }

  Future<void> _loadVideoThumbnail() async {
    if (widget.photo.asset == null) return;

    try {
      final thumbnail = await widget.photo.asset!.thumbnailData;
      if (thumbnail != null && mounted) {
        setState(() {
          _thumbnailProvider = MemoryImage(thumbnail);
        });
      }
    } catch (e) {
      debugPrint('동영상 썸네일 로드 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: 'photo_${widget.photo.id}',
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
            child: Stack(
              children: [
                if (widget.photo.isVideo && _thumbnailProvider == null)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                // 메모와 음성 메모 아이콘
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 텍스트 메모 아이콘
                      if (widget.photo.memo != null &&
                          widget.photo.memo!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.note,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      // 음성 메모 아이콘
                      if (widget.photo.voiceMemoPath != null)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // 동영상 아이콘
                if (widget.photo.isVideo)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
