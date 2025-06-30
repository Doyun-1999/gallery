// lib/screen/videos_screen.dart
import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';

class VideosScreen extends StatefulWidget {
  final bool isSelectMode;
  final Set<String> selectedPhotoIds;
  final void Function(String photoId) onPhotoTap;
  final void Function(String photoId) onPhotoLongPress;

  const VideosScreen({
    super.key,
    required this.isSelectMode,
    required this.selectedPhotoIds,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
  });

  @override
  VideosScreenState createState() => VideosScreenState();
}

class VideosScreenState extends State<VideosScreen>
    with AutomaticKeepAliveClientMixin<VideosScreen> {
  bool _isLoading = true;
  List<Photo> _videos = [];
  final Map<String, ImageProvider> _thumbnailCache = {};
  static const int _pageSize = 30;
  int _currentPage = 0;
  bool _hasMoreVideos = true;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _errorVideoIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _thumbnailCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreVideos();
    }
  }

  // 날짜별로 비디오들을 그룹화하는 함수
  Map<DateTime, List<Photo>> _groupVideosByDate(List<Photo> videos) {
    final Map<DateTime, List<Photo>> groupedVideos = {};

    for (final video in videos) {
      // 날짜를 년-월-일로 정규화 (시간 제거)
      final dateKey = DateTime(
        video.date.year,
        video.date.month,
        video.date.day,
      );

      if (!groupedVideos.containsKey(dateKey)) {
        groupedVideos[dateKey] = [];
      }
      groupedVideos[dateKey]!.add(video);
    }

    // 날짜별로 정렬 (최신 날짜가 위로)
    final sortedKeys =
        groupedVideos.keys.toList()..sort((a, b) => b.compareTo(a));

    final sortedGroupedVideos = <DateTime, List<Photo>>{};
    for (final key in sortedKeys) {
      sortedGroupedVideos[key] = groupedVideos[key]!;
    }

    return sortedGroupedVideos;
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

  Future<void> _loadVideos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _videos = [];
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<AssetEntity> videoAssets = await albums[0].getAssetListPaged(
        page: 0,
        size: _pageSize,
      );

      final List<Photo> newVideos = [];
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
          newVideos.add(photo);
        }
      }

      if (mounted) {
        setState(() {
          _videos = newVideos;
          _currentPage = 1;
          _isLoading = false;
          _hasMoreVideos = videoAssets.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('비디오 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _videos = [];
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (!_hasMoreVideos || _isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<AssetEntity> videoAssets = await albums[0].getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      if (videoAssets.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMoreVideos = false;
          });
        }
        return;
      }

      final List<Photo> newVideos = [];
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
          newVideos.add(photo);
        }
      }

      if (mounted) {
        setState(() {
          _videos.addAll(newVideos);
          _currentPage++;
          _isLoading = false;
          _hasMoreVideos = videoAssets.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('추가 비디오 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<ImageProvider> _getVideoThumbnail(Photo photo) async {
    if (_thumbnailCache.containsKey(photo.id)) {
      return _thumbnailCache[photo.id]!;
    }

    if (photo.asset != null) {
      try {
        final thumbnail = await photo.asset!.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 80,
        );
        if (thumbnail != null) {
          final imageProvider = MemoryImage(thumbnail);
          _thumbnailCache[photo.id] = imageProvider;
          return imageProvider;
        }
      } catch (e) {
        debugPrint('썸네일 생성 중 오류 발생: $e');
      }
    }

    return const AssetImage('assets/logo/logo.png');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayVideos =
        _videos.where((v) => !_errorVideoIds.contains(v.id)).toList();

    if (displayVideos.isEmpty) {
      return const Center(
        child: Text('동영상이 없습니다', style: TextStyle(fontSize: 16)),
      );
    }

    // 날짜별로 그룹화
    final groupedVideos = _groupVideosByDate(displayVideos);
    final allItems = <Widget>[];

    // 각 그룹에 대해 헤더와 비디오들을 추가
    groupedVideos.forEach((date, videoList) {
      // 날짜 헤더 추가
      allItems.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _formatDate(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      );

      // 해당 날짜의 비디오들을 그리드로 추가
      for (int i = 0; i < videoList.length; i += 3) {
        final rowVideos = videoList.skip(i).take(3).toList();
        allItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: List.generate(3, (index) {
                if (index < rowVideos.length) {
                  final video = rowVideos[index];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: PhotoGridItem(
                        photo: video,
                        imageProvider: const AssetImage(
                          'assets/logo/logo.png',
                        ), // Placeholder, will be replaced by thumbnail
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PhotoViewScreen(
                                    photoId: video.id,
                                    source: PhotoViewSource.video,
                                    videos: displayVideos,
                                  ),
                            ),
                          );
                        },
                        onLongPress: () => widget.onPhotoLongPress(video.id),
                        isSelectable: widget.isSelectMode,
                        isSelected: widget.selectedPhotoIds.contains(video.id),
                        onError: (videoId) {
                          if (mounted) {
                            setState(() {
                              _errorVideoIds.add(videoId);
                            });
                          }
                        },
                        key: ValueKey(video.id),
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
    if (_hasMoreVideos && _isLoading) {
      allItems.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: allItems.length,
      itemBuilder: (context, index) => allItems[index],
    );
  }
}
