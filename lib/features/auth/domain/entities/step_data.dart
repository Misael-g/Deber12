import 'package:equatable/equatable.dart';

/// Tipos de actividad detectados
enum ActivityType {
  stationary,  // Quieto
  walking,     // Caminando
  running,     // Corriendo
  fallDetected // Caída detectada
}

/// Datos del acelerómetro
class StepData extends Equatable {
  final int stepCount;
  final ActivityType activityType;
  final double magnitude;
  final bool fallDetected;

  const StepData({
    required this.stepCount,
    required this.activityType,
    required this.magnitude,
    this.fallDetected = false,
  });


  /// Calorías estimadas (0.04 cal por paso)
  double get estimatedCalories => stepCount * 0.04;

  /// Factory para crear desde Map del Platform Channel
  factory StepData.fromMap(Map<dynamic, dynamic> map) {
    final activityTypeString = map['activityType'] as String? ?? 'stationary';

    return StepData(
      stepCount: (map['stepCount'] as num?)?.toInt() ?? 0,
      activityType: _parseActivityType(activityTypeString),
      magnitude: (map['magnitude'] as num?)?.toDouble() ?? 0.0,
      fallDetected: (map['fallDetected'] as bool?) ?? false,
    );
  }

  static ActivityType _parseActivityType(String type) {
    switch (type) {
      case 'walking':
        return ActivityType.walking;
      case 'running':
        return ActivityType.running;
      default:
        return ActivityType.stationary;
    }
  }

  @override
  List<Object> get props => [stepCount, activityType, magnitude];
}
