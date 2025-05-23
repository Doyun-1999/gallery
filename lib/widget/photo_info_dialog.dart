import 'package:flutter/material.dart';
import 'package:gallery_memo/model/photo_model.dart';
import 'package:intl/intl.dart';

class PhotoInfoDialog extends StatelessWidget {
  final Photo photo;

  const PhotoInfoDialog({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
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
          Text('추가 날짜: ${_formatDate(photo.date)}'),
          const SizedBox(height: 8),
          Text('즐겨찾기 상태: ${photo.isFavorite ? "예" : "아니오"}'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
