import '../domain/entities/auth_result.dart';

abstract class AuthenticateUser {
  Future<AuthResult> call(String username, String password);
}
