import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/biometric_auth.dart';
import 'auth_providers.dart';

/// O aparelho oferece autenticação local (biometria ou senha/PIN)?
final biometricSupportProvider = FutureProvider<bool>((ref) {
  return BiometricAuth.instance.isSupported();
});

/// Acesso por biometria/senha do aparelho ativado para o usuário atual.
final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
      BiometricEnabledNotifier.new,
    );

class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  String get _key {
    final userId = ref.watch(currentUserIdProvider) ?? 'anon';
    return 'controla_simples.biometric.$userId';
  }

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// A sessão atual está desbloqueada? No início do app fica `false` quando o
/// acesso por biometria está ativo, exigindo a autenticação antes de mostrar
/// o conteúdo. Um login com senha/e-mail (ou Google) desbloqueia a sessão.
final appUnlockedProvider = NotifierProvider<AppUnlockedNotifier, bool>(
  AppUnlockedNotifier.new,
);

class AppUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}
