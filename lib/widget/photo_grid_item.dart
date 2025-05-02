import 'package:flutter/material.dart';
import 'package:gallery/model/photo_model.dart';
import 'dart:io';

class PhotoGridItem extends StatelessWidget {
  final Photo photo;
  final Function() onTap;
  final Function() onFavoriteToggle;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 이미지
          Image.file(File(photo.path), fit: BoxFit.cover),

          // 즐겨찾기 버튼
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onFavoriteToggle,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  photo.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: photo.isFavorite ? Colors.red : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
