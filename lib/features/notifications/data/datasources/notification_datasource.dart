import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// DataSource para notificaciones usando Platform Channel
/// 
/// EXPLICACIÓN:
/// - Usa MethodChannel para comunicarse con código nativo Android
/// - Maneja permisos de notificaciones (Android 13+)
abstract class NotificationDataSource {
  Future<bool> requestPermission();
  Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
  });
  Future<void> initialize();
}

class NotificationDataSourceImpl implements NotificationDataSource {
  final MethodChannel _channel = const MethodChannel(
    'com.tuinstituto.fitness/notifications'
  );

  @override
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } on PlatformException catch (e) {
      debugPrint('Error inicializando notificaciones: ${e.message}');
    }
  }

  @override
  Future<bool> requestPermission() async {
    // En Android 13+ se requiere permiso explícito
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'channelId': channelId ?? 'fitness_tracker_channel',
      });
    } on PlatformException catch (e) {
      debugPrint('Error mostrando notificación: ${e.message}');
    }
  }
}
