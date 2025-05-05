import 'package:flutter/material.dart';
import 'package:gallery/model/photo_model.dart';
import 'dart:io';

class PhotoGridItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'photo_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: Stack(
            children: [
              // 메모와 음성 메모 아이콘
              Positioned(
                bottom: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 텍스트 메모 아이콘
                    if (photo.memo != null && photo.memo!.isNotEmpty)
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
                    if (photo.voiceMemoPath != null)
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
            ],
          ),
        ),
      ),
    );
  }
}
