import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/model/gallery_model.dart';
import 'package:gallery/screen/photo_view_screen.dart';
import 'package:gallery/widget/photo_grid_item.dart';
import 'package:provider/provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = true;
  @override
  Widget build(BuildContext context) {
    return Consumer<GalleryModel>(
      builder: (context, galleryModel, child) {
        final photos = galleryModel.photos;

        if (photos.isNotEmpty) {
          _isLoading = false;
        }

        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return PhotoGridItem(
                  photo: photo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PhotoViewScreen(
                              photoId: photo.id,
                              source: PhotoViewSource.gallery,
                            ),
                      ),
                    );
                  },
                  onFavoriteToggle: () {
                    galleryModel.toggleFavorite(photo.id);
                    _showFeedback(context, photo.isFavorite);
                  },
                );
              },
            );
      },
    );
  }

  void _showFeedback(BuildContext context, bool isFavorite) {
    final message = isFavorite ? '즐겨찾기에서 제거됨' : '즐겨찾기에 추가됨';
    final icon = isFavorite ? Icons.favorite_border : Icons.favorite;
    final color = isFavorite ? Colors.grey : Colors.red;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
      ),
    );
  }
}
