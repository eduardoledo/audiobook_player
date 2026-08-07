import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/structure_detection_models.dart';
import 'structure_detection_job.dart';

/// System notification for structure detection progress.
class StructureDetectionNotifications {
  static const _channelId = 'structure_detection';
  static const _channelName = 'Detección de estructura';
  static const _notifId = 42042;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  double _lastReportedProgress = -1;
  String _lastStatus = '';

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Progreso de detección de capítulos',
        importance: Importance.low,
      ),
    );

    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    _initialized = true;
  }

  Future<void> update(StructureDetectionJob job) async {
    await init();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (job.status == StructureDetectionJobStatus.idle) {
      await cancel();
      return;
    }

    final bookTitle = job.book?.title ?? 'Audiolibro';
    final p = job.progress;
    final progress = p?.progress ?? 0.0;
    final status = p?.status ?? job.status.name;
    final markers = job.partialMarkers.length;

    final shouldUpdate = job.status == StructureDetectionJobStatus.paused ||
        job.status == StructureDetectionJobStatus.completed ||
        job.status == StructureDetectionJobStatus.error ||
        status != _lastStatus ||
        (progress - _lastReportedProgress).abs() >= 0.03;

    if (!shouldUpdate) return;
    _lastReportedProgress = progress;
    _lastStatus = status;

    final pct = (progress * 100).round();
    String body;
    switch (job.status) {
      case StructureDetectionJobStatus.paused:
        body = 'Pausado · $markers marcadores · $pct%';
      case StructureDetectionJobStatus.completed:
        body = 'Listo · $markers marcadores';
      case StructureDetectionJobStatus.error:
        body = 'Error: ${job.error}';
      default:
        body = '$status · $markers marcadores · $pct%';
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Progreso de detección de capítulos',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: job.status == StructureDetectionJobStatus.running ||
          job.status == StructureDetectionJobStatus.paused,
      maxProgress: 100,
      progress: pct.clamp(0, 100),
      ongoing: job.isActive,
      autoCancel: !job.isActive,
    );

    await _plugin.show(
      _notifId,
      'Estructura: $bookTitle',
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(_notifId);
    _lastReportedProgress = -1;
    _lastStatus = '';
  }
}
