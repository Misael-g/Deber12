import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/platform/platform_channels.dart';
import '../../domain/entities/step_data.dart';

/// DataSource para acelerómetro usando EventChannel
///
/// - EventChannel se usa para STREAMS de datos continuos
/// - A diferencia de MethodChannel (petición/respuesta),
///   EventChannel envía datos constantemente
abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  /// EventChannel: para recibir stream de datos
  final EventChannel _eventChannel = const EventChannel(
    PlatformChannels.accelerometer
  );

  /// MethodChannel auxiliar: para control (start/stop)
  final MethodChannel _methodChannel = const MethodChannel(
    '${PlatformChannels.accelerometer}/control'
  );

  @override
  Stream<StepData> get stepStream {
    /// receiveBroadcastStream(): crea un stream que recibe
    /// datos continuamente desde el lado Android
    return _eventChannel.receiveBroadcastStream().map((event) {
      return StepData.fromMap(event as Map<dynamic, dynamic>);
    });
  }

  @override
  Future<void> startCounting() async {
    await _methodChannel.invokeMethod('start');
  }

  @override
  Future<void> stopCounting() async {
    await _methodChannel.invokeMethod('stop');
  }

  @override
  Future<bool> requestPermissions() async {
    final activityStatus = await Permission.activityRecognition.request();
    final sensorsStatus = await Permission.sensors.request();
    return activityStatus.isGranted && sensorsStatus.isGranted;
  }
}
