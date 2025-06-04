import 'package:flutter/material.dart';
import 'package:gallery_memo/model/gallery_model.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:gallery_memo/screen/photo_view_screen.dart';
import 'package:gallery_memo/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class GalleryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final photos = galleryModel.photos;

        if (photos.isEmpty) {
          return const Center(child: Text('사진이 없습니다.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return PhotoGridItem(
              photo: photo,
              imageProvider: FileImage(File(photo.path)),
              onTap: () => onPhotoTap(photo.id),
              onLongPress: () => onPhotoLongPress(photo.id),
              isSelectable: isSelectMode,
              isSelected: selectedPhotoIds.contains(photo.id),
              key: ValueKey(photo.id),
            );
          },
        );
      },
    );
  }
}
