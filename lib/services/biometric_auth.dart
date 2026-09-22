import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Resultado de uma tentativa de autenticação local.
class BiometricResult {
  const BiometricResult({required this.success, this.message});

  final bool success;

  /// Mensagem amigável quando a autenticação falha (nula quando o usuário
  /// apenas cancela — nesse caso não é preciso exibir nada).
  final String? message;
}

/// Envolve o `local_auth` para oferecer o acesso rápido por biometria
/// (digital/rosto) ou pela senha/PIN do aparelho.
class BiometricAuth {
  BiometricAuth._();

  static final BiometricAuth instance = BiometricAuth._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Há biometria cadastrada neste aparelho?
  Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// O aparelho suporta autenticação local (biometria ou senha/PIN/padrão)?
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Pede a autenticação. Por padrão aceita biometria **ou** a senha do
  /// aparelho, para o usuário escolher como prefere entrar.
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Acesso ao Controla Simples',
            signInHint: 'Use a digital, o rosto ou a senha do celular',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
            localizedFallbackTitle: 'Usar senha do celular',
          ),
        ],
      );
      return BiometricResult(success: success);
    } on LocalAuthException catch (error) {
      return BiometricResult(success: false, message: _messageFor(error));
    } catch (_) {
      return const BiometricResult(
        success: false,
        message: 'Não foi possível usar a biometria. Tente novamente.',
      );
    }
  }

  String? _messageFor(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.userRequestedFallback:
        return null;
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Configure a biometria ou a senha do celular nas configurações do aparelho.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Nenhuma biometria disponível. Use a senha do celular ou cadastre uma digital.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Muitas tentativas. Use a senha do celular ou tente novamente mais tarde.';
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return 'Não foi possível autenticar. Tente novamente.';
    }
  }
}
