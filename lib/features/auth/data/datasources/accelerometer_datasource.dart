import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/step_data.dart';

/// DataSource para acelerómetro usando plugin sensors_plus
///
/// MIGRADO DE PLATFORM CHANNELS A PLUGIN:
/// ✅ Ya no usa EventChannel ni MethodChannel
/// ✅ Usa sensors_plus directamente
/// ✅ Toda la lógica ahora está en Dart (más testeable)
abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<void> resetCounter();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  // Stream del plugin sensors_plus
  StreamSubscription<AccelerometerEvent>? _subscription;
  
  // Controller para emitir datos procesados
  final StreamController<StepData> _controller = StreamController<StepData>.broadcast();

  // Estado del contador
  int _stepCount = 0;
  double _lastMagnitude = 0.0;
  bool _isTracking = false;

  // Variables para suavizado
  final List<double> _magnitudeHistory = [];
  final int _historySize = 10;
  int _sampleCount = 0;

  // Variables para detección de actividad
  String _lastActivityType = 'stationary';
  int _activityConfidence = 0;

  @override
  Stream<StepData> get stepStream => _controller.stream;

  @override
  Future<void> startCounting() async {
    if (_isTracking) return;

    _isTracking = true;
    _stepCount = 0;
    _magnitudeHistory.clear();
    _lastMagnitude = 0.0;
    _sampleCount = 0;
    _activityConfidence = 0;

    // Suscribirse al stream de eventos del acelerómetro
    _subscription = accelerometerEventStream().listen(
      _processAccelerometerEvent,
      onError: (error) {
        debugPrint('Error en acelerómetro: $error');
      },
    );
  }

  @override
  Future<void> stopCounting() async {
    _isTracking = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  Future<void> resetCounter() async {
    _stepCount = 0;
    _magnitudeHistory.clear();
    _lastMagnitude = 0.0;
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    if (!_isTracking) return;

    // Calcular magnitud del vector de aceleración
    final magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );

    // Agregar a historial para promedio móvil
    _magnitudeHistory.add(magnitude);
    if (_magnitudeHistory.length > _historySize) {
      _magnitudeHistory.removeAt(0);
    }

    // Calcular promedio para suavizar
    final avgMagnitude = _magnitudeHistory.isNotEmpty
        ? _magnitudeHistory.reduce((a, b) => a + b) / _magnitudeHistory.length
        : magnitude;

    // ═══════════════════════════════════════════════════════════
    // DETECCIÓN DE PASOS
    // ═══════════════════════════════════════════════════════════
    // Detectar pico (cruce de umbral hacia arriba)
    if (magnitude > 12.0 && _lastMagnitude <= 12.0) {
      _stepCount++;
    }
    _lastMagnitude = magnitude;

    // ═══════════════════════════════════════════════════════════
    // DETECCIÓN DE TIPO DE ACTIVIDAD
    // ═══════════════════════════════════════════════════════════
    String newActivityType;
    if (avgMagnitude < 10.5) {
      newActivityType = 'stationary';
    } else if (avgMagnitude < 13.5) {
      newActivityType = 'walking';
    } else {
      newActivityType = 'running';
    }

    // Solo cambiar si hay confianza (evita cambios erráticos)
    if (newActivityType == _lastActivityType) {
      _activityConfidence++;
    } else {
      _activityConfidence = 0;
    }

    final finalActivityType = _activityConfidence >= 3
        ? newActivityType
        : _lastActivityType;
    _lastActivityType = newActivityType;

    // ═══════════════════════════════════════════════════════════
    // DETECCIÓN DE CAÍDAS
    // ═══════════════════════════════════════════════════════════
    // Caída detectada con aceleración muy alta (> 25 m/s²)
    final fallDetected = avgMagnitude > 25.0;

    // ═══════════════════════════════════════════════════════════
    // EMITIR DATOS (cada 3 muestras para no saturar)
    // ═══════════════════════════════════════════════════════════
    _sampleCount++;
    if (_sampleCount >= 3) {
      _sampleCount = 0;

      final stepData = StepData(
        stepCount: _stepCount,
        activityType: _parseActivityType(finalActivityType),
        magnitude: avgMagnitude,
        fallDetected: fallDetected,
      );

      if (!_controller.isClosed) {
        _controller.add(stepData);
      }
    }
  }

  ActivityType _parseActivityType(String type) {
    switch (type) {
      case 'walking':
        return ActivityType.walking;
      case 'running':
        return ActivityType.running;
      case 'stationary':
        return ActivityType.stationary;
      default:
        return ActivityType.stationary;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    // En Android 13+ se requieren permisos explícitos
    if (await Permission.activityRecognition.isDenied) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return false;
    }

    if (await Permission.sensors.isDenied) {
      final status = await Permission.sensors.request();
      if (!status.isGranted) return false;
    }

    return true;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
