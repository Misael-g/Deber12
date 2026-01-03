import 'package:flutter/material.dart';
import 'dart:async';
import '../../../auth/data/datasources/accelerometer_datasource.dart';
import '../../../auth/domain/entities/step_data.dart';
import '../../../notifications/data/datasources/notification_datasource.dart';

/// Widget que muestra el contador de pasos
///
/// NUEVAS CARACTERÍSTICAS:
/// - Detecta cuando se alcanzan 30 pasos y muestra alerta
/// - Detecta caídas y muestra alerta de emergencia
class StepCounterWidget extends StatefulWidget {
  const StepCounterWidget({super.key});

  @override
  State<StepCounterWidget> createState() => _StepCounterWidgetState();
}

class _StepCounterWidgetState extends State<StepCounterWidget> {
  final AccelerometerDataSource _dataSource = AccelerometerDataSourceImpl();
  final NotificationDataSource _notificationDataSource = NotificationDataSourceImpl();

  StreamSubscription<StepData>? _subscription;
  StepData? _currentData;
  bool _isTracking = false;
  bool _goalReached = false;  // NUEVO: Evitar múltiples alertas de meta

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationDataSource.initialize();
    await _notificationDataSource.requestPermission();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  void _startTracking() async {
    // Solicitar permisos
    final hasPermission = await _dataSource.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos de sensores denegados'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _dataSource.startCounting();

    // SUSCRIBIRSE AL STREAM
    _subscription = _dataSource.stepStream.listen(
      (data) {
        setState(() {
          _currentData = data;
        });

        // ─────────────────────────────────────────────────
        // RETO 1: Notificación al alcanzar 30 pasos
        // ─────────────────────────────────────────────────
        if (data.stepCount >= 30 && !_goalReached) {
          _goalReached = true;
          _showGoalReachedAlert(data.stepCount);
        }

        // ─────────────────────────────────────────────────
        // RETO 2: Alerta de caída detectada
        // ─────────────────────────────────────────────────
        if (data.fallDetected) {
          _showFallDetectedAlert();
        }
      },
      onError: (error) {
        print('Error en stream: $error');
      },
    );

    setState(() {
      _isTracking = true;
      _goalReached = false;
    });
  }

  void _stopTracking() async {
    await _dataSource.stopCounting();
    _subscription?.cancel();

    setState(() {
      _isTracking = false;
    });
  }

  /// RETO 1: Mostrar alerta cuando se alcanzan 30 pasos
  void _showGoalReachedAlert(int steps) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Meta Alcanzada!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Has completado $steps pasos',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 ¡Excelente trabajo! ¡Sigue así!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('¡Genial!'),
          ),
        ],
      ),
    );

    // Enviar notificación local también
    _notificationDataSource.showNotification(
      title: 'Meta Alcanzada',
      body: 'Has completado $steps pasos. ¡Bien hecho!',
    );
  }

  /// RETO 2: Mostrar alerta de caída detectada
  void _showFallDetectedAlert() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, color: Colors.red, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Caída Detectada!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se ha detectado una posible caída',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ ¿Estás bien? Si necesitas ayuda, contacta a emergencias.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Falsa alarma'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aquí podrías implementar llamada a emergencias
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('En una app real, esto llamaría a emergencias'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Necesito ayuda'),
          ),
        ],
      ),
    );

    // Enviar notificación local de emergencia
    _notificationDataSource.showNotification(
      title: 'Caída detectada',
      body: 'Se ha detectado una posible caída. ¿Estás bien?',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contador de Pasos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Contador
            Text(
              '${_currentData?.stepCount ?? 0}',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: _goalReached ? Colors.green : const Color(0xFF6366F1),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('pasos', style: TextStyle(fontSize: 16, color: Colors.grey)),
                if (_goalReached) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const Text(' Meta alcanzada', 
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Indicadores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(
                  icon: _getActivityIcon(_currentData?.activityType),
                  label: _getActivityLabel(_currentData?.activityType),
                  color: _currentData?.activityType == ActivityType.fallDetected 
                    ? Colors.red 
                    : Colors.blue,
                ),
                _buildInfoChip(
                  icon: Icons.local_fire_department,
                  label: '${_currentData?.estimatedCalories.toStringAsFixed(1) ?? "0"} cal',
                  color: Colors.orange,
                ),
              ],
            ),

            // NUEVO: Indicador de progreso hacia la meta
            if (_isTracking && !_goalReached) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_currentData?.stepCount ?? 0) / 30,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              const SizedBox(height: 8),
              Text(
                'Faltan ${30 - (_currentData?.stepCount ?? 0)} pasos para la meta',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType? type) {
    switch (type) {
      case ActivityType.walking:
        return Icons.directions_walk;
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.stationary:
        return Icons.accessibility_new;
      case ActivityType.fallDetected:
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  String _getActivityLabel(ActivityType? type) {
    switch (type) {
      case ActivityType.walking:
        return 'Caminando';
      case ActivityType.running:
        return 'Corriendo';
      case ActivityType.stationary:
        return 'Quieto';
      case ActivityType.fallDetected:
        return '¡Caída!';
      default:
        return 'Detectando...';
    }
  }
}
