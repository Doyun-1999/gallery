import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'dart:io';

// 파일 수정 시간을 포함한 커스텀 FileImage 클래스
class _UniqueFileImage extends FileImage {
  final int modifiedTime;

  const _UniqueFileImage(super.file, this.modifiedTime);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _UniqueFileImage &&
        other.file.path == file.path &&
        other.modifiedTime == modifiedTime;
  }

  @override
  int get hashCode => Object.hash(file.path, modifiedTime);
}

class GalleryScreen extends StatefulWidget {
  final bool isSelectMode;
  final Set<String> selectedPhotoIds;
  final void Function(String photoId) onPhotoTap;
  final void Function(String photoId) onPhotoLongPress;

  const GalleryScreen({
    super.key,
    required this.isSelectMode,
    required this.selectedPhotoIds,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final Set<String> _errorPhotoIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String path) {
    // ResizeImage 성능 이점을 유지하면서 캐시 문제 해결
    // 파일 수정 시간을 포함한 unique FileImage 생성
    final file = File(path);
    final modTime = _getFileModTime(path);

    // 파일 수정 시간이 바뀌면 다른 FileImage로 인식되어 캐시가 새로 생성됨
    final uniqueFileImage = _UniqueFileImage(file, modTime);

    return ResizeImage(
      uniqueFileImage,
      width: 200,
      allowUpscaling: false,
      policy: ResizeImagePolicy.fit,
    );
  }

  // 파일의 수정 시간을 가져오는 메서드
  Future<int> _getFileModifiedTime(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified.millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('파일 수정 시간 가져오기 실패: $e');
    }
    return 0;
  }

  // 파일의 수정 시간을 가져오는 메서드 (위젯 key용)
  int _getFileModTime(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return file.statSync().modified.millisecondsSinceEpoch;
      }
    } catch (e) {
      // 오류 시 현재 시간 반환
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  // 특정 이미지의 캐시를 무효화하는 메서드
  void _invalidateImageCache(String path) {
    final imageProvider = FileImage(File(path));
    PaintingBinding.instance.imageCache.evict(imageProvider);

    // ResizeImage로 감싼 것도 제거
    final resizeImageProvider = ResizeImage(
      FileImage(File(path)),
      width: 200,
      allowUpscaling: false,
      policy: ResizeImagePolicy.fit,
    );
    PaintingBinding.instance.imageCache.evict(resizeImageProvider);
  }

  // 모든 이미지 캐시를 무효화하는 메서드
  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void _onScroll() {
    if (_isLoading) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<GalleryModel>().loadMorePhotos();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 날짜별로 사진들을 그룹화하는 함수
  Map<DateTime, List<Photo>> _groupPhotosByDate(List<Photo> photos) {
    final Map<DateTime, List<Photo>> groupedPhotos = {};

    for (final photo in photos) {
      // 날짜를 년-월-일로 정규화 (시간 제거)
      final dateKey = DateTime(
        photo.date.year,
        photo.date.month,
        photo.date.day,
      );

      if (!groupedPhotos.containsKey(dateKey)) {
        groupedPhotos[dateKey] = [];
      }
      groupedPhotos[dateKey]!.add(photo);
    }

    // 날짜별로 정렬 (최신 날짜가 위로)
    final sortedKeys =
        groupedPhotos.keys.toList()..sort((a, b) => b.compareTo(a));

    final sortedGroupedPhotos = <DateTime, List<Photo>>{};
    for (final key in sortedKeys) {
      sortedGroupedPhotos[key] = groupedPhotos[key]!;
    }

    return sortedGroupedPhotos;
  }

  // 날짜 포맷팅 함수
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return '오늘';
    } else if (dateToCheck == yesterday) {
      return '어제';
    } else {
      // 한국어 날짜 포맷
      final months = [
        '1월',
        '2월',
        '3월',
        '4월',
        '5월',
        '6월',
        '7월',
        '8월',
        '9월',
        '10월',
        '11월',
        '12월',
      ];

      final days = ['일', '월', '화', '수', '목', '금', '토'];

      final month = months[date.month - 1];
      final day = date.day;
      final weekday = days[date.weekday - 1];

      // 올해가 아닌 경우 연도 포함
      if (date.year != now.year) {
        return '${date.year}년 $month $day일 ($weekday요일)';
      } else {
        return '$month $day일 ($weekday요일)';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final photos =
            galleryModel.photos
                .where((p) => !_errorPhotoIds.contains(p.id))
                .toList();

        if (photos.isEmpty && !galleryModel.isLoading) {
          return const Center(child: Text('사진이 없습니다.'));
        }

        // 날짜별로 그룹화
        final groupedPhotos = _groupPhotosByDate(photos);
        final allItems = <Widget>[];

        // 각 그룹에 대해 헤더와 사진들을 추가
        groupedPhotos.forEach((date, photoList) {
          // 날짜 헤더 추가
          allItems.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _formatDate(date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          );

          // 해당 날짜의 사진들을 그리드로 추가
          for (int i = 0; i < photoList.length; i += 3) {
            final rowPhotos = photoList.skip(i).take(3).toList();
            allItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: List.generate(3, (index) {
                    if (index < rowPhotos.length) {
                      final photo = rowPhotos[index];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: PhotoGridItem(
                            photo: photo,
                            imageProvider: _getImageProvider(photo.path),
                            onTap: () => widget.onPhotoTap(photo.id),
                            onLongPress:
                                () => widget.onPhotoLongPress(photo.id),
                            isSelectable: widget.isSelectMode,
                            isSelected: widget.selectedPhotoIds.contains(
                              photo.id,
                            ),
                            onError: (photoId) {
                              if (mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  setState(() {
                                    _errorPhotoIds.add(photoId);
                                  });
                                });
                              }
                            },
                            key: ValueKey(
                              '${photo.id}_${photo.path}_${_getFileModTime(photo.path)}',
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const Expanded(child: SizedBox());
                    }
                  }),
                ),
              ),
            );
          }
        });

        // 로딩 인디케이터 추가
        if (_isLoading) {
          allItems.add(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo is ScrollEndNotification) {
              _onScroll();
            }
            return true;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: allItems.length,
            itemBuilder: (context, index) => allItems[index],
          ),
        );
      },
    );
  }
}
