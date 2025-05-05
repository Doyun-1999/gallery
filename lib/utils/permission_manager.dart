// utils/permission_manager.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:app_settings/app_settings.dart';

class PermissionManager {
  // 사진 접근 권한 확인 및 요청
  static Future<bool> requestPhotoPermission(BuildContext context) async {
    // 먼저 현재 권한 상태 확인
    final PermissionState photoPermission =
        await PhotoManager.requestPermissionExtend();

    if (photoPermission.isAuth) {
      // 이미 권한이 있는 경우
      return true;
    } else if (photoPermission.hasAccess) {
      // 제한된 접근 권한이 있는 경우 (iOS의 경우 일부 사진에만 접근 가능)
      // 사용자에게 모든 사진에 대한 접근이 필요함을 알림
      final bool upgradePermission = await _showPermissionDialog(
        context,
        '제한된 사진 접근',
        '현재 일부 사진에만 접근할 수 있습니다. 모든 사진에 접근하려면 설정에서 권한을 변경해주세요.',
        '설정으로 이동',
        '현재 권한으로 계속하기',
      );

      if (upgradePermission) {
        // 설정 화면으로 이동
        await AppSettings.openAppSettings();
        // 앱 설정에서 돌아오면 권한을 다시 확인
        return await _checkPhotoPermissionAfterSettings();
      }
      // 제한된 접근으로 계속 진행
      return true;
    } else {
      // 권한이 완전히 없는 경우
      final bool requestPermission = await _showPermissionDialog(
        context,
        '사진 접근 권한 필요',
        '갤러리 기능을 사용하려면 사진 접근 권한이 필요합니다. 권한을 허용하시겠습니까?',
        '권한 허용하기',
        '나중에',
      );

      if (requestPermission) {
        // 권한 요청 다이얼로그 표시
        final status = await Permission.photos.request();

        if (status.isGranted || status.isLimited) {
          return true;
        } else if (status.isPermanentlyDenied) {
          // 영구적으로 거부된 경우 설정으로 이동하도록 안내
          final bool goToSettings = await _showPermissionDialog(
            context,
            '권한이 거부됨',
            '사진 접근 권한이 거부되었습니다. 갤러리 기능을 사용하려면 설정에서 권한을 허용해주세요.',
            '설정으로 이동',
            '취소',
          );

          if (goToSettings) {
            await AppSettings.openAppSettings();
            return await _checkPhotoPermissionAfterSettings();
          }
        }
        return false;
      } else {
        // 사용자가 권한 요청을 거부
        return false;
      }
    }
  }

  // 카메라 권한 확인 및 요청
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      // 권한이 거부된 경우 설정으로 이동할지 물어보기
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('카메라 권한 필요'),
              content: const Text(
                '사진을 찍기 위해서는 카메라 권한이 필요합니다. 설정에서 권한을 허용하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('설정으로 이동'),
                ),
              ],
            ),
      );

      if (shouldOpenSettings == true) {
        await AppSettings.openAppSettings();
      }
    } else if (status.isPermanentlyDenied) {
      // 권한이 영구적으로 거부된 경우 설정으로 이동
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('카메라 권한 필요'),
              content: const Text(
                '사진을 찍기 위해서는 카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await AppSettings.openAppSettings();
                  },
                  child: const Text('설정으로 이동'),
                ),
              ],
            ),
      );
    }

    return false;
  }

  // 설정에서 돌아온 후 권한 확인
  static Future<bool> _checkPhotoPermissionAfterSettings() async {
    final PermissionState photoPermission =
        await PhotoManager.requestPermissionExtend();
    return photoPermission.isAuth || photoPermission.hasAccess;
  }

  // 권한 요청 다이얼로그 표시
  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String content,
    String confirmText,
    String cancelText,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // 여러 권한 한 번에 확인 (앱 시작 시 유용)
  static Future<Map<Permission, bool>> checkMultiplePermissions(
    BuildContext context,
    List<Permission> permissions,
  ) async {
    Map<Permission, bool> statuses = {};

    for (var permission in permissions) {
      if (permission == Permission.photos) {
        statuses[permission] = await requestPhotoPermission(context);
      } else if (permission == Permission.camera) {
        statuses[permission] = await requestCameraPermission(context);
      } else {
        final status = await permission.status;
        statuses[permission] = status.isGranted;
      }
    }

    return statuses;
  }
}
