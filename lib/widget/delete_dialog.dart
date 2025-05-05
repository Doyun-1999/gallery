import 'package:flutter/material.dart';
import 'package:gallery/model/photo_model.dart';

class DeleteDialog extends StatelessWidget {
  final Photo photo;
  final VoidCallback onDelete;

  const DeleteDialog({super.key, required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사진 삭제'),
      content: const Text('이 사진을 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            onDelete();
            Navigator.pop(context);
          },
          child: const Text('삭제'),
        ),
      ],
    );
  }
}
