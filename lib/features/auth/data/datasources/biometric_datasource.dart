import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../domain/entities/auth_result.dart';

/// DataSource para autenticación biométrica usando plugin local_auth
/// 
/// MIGRADO DE PLATFORM CHANNELS A PLUGIN:
/// ✅ Ya no usa MethodChannel
/// ✅ Usa el plugin local_auth directamente
/// ✅ Funciona automáticamente en iOS y Android
abstract class BiometricDataSource {
  Future<bool> canAuthenticate();
  Future<AuthResult> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  /// Plugin de autenticación local
  /// Reemplaza completamente el MethodChannel anterior
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      // Verificar si el dispositivo tiene biometría disponible
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      
      return canAuthenticateWithBiometrics || canAuthenticate;
    } catch (e) {
      debugPrint('Error verificando biometría: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      // Verificar disponibilidad primero
      final canAuth = await canAuthenticate();
      if (!canAuth) {
        return const AuthResult(
          success: false,
          message: 'Biometría no disponible en este dispositivo',
        );
      }

      // Autenticar con biometría
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Usa tu huella dactilar o Face ID para entrar',
        options: const AuthenticationOptions(
          stickyAuth: true,           // Mantener diálogo hasta éxito/cancelar
          biometricOnly: false,       // Permitir PIN si biometría falla
          useErrorDialogs: true,      // Mostrar diálogos de error nativos
        ),
      );

      return AuthResult(
        success: authenticated,
        message: authenticated 
            ? 'Autenticación exitosa' 
            : 'Autenticación cancelada o fallida',
      );
    } catch (e) {
      debugPrint('Error autenticando con biometría: ${e.toString()}');
      return AuthResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// NUEVO: Obtener tipos de biometría disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error obteniendo biometrías: $e');
      return [];
    }
  }
}
