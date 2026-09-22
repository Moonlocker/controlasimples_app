import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../services/biometric_auth.dart';
import '../../widgets/brand_logo.dart';
import 'biometric_providers.dart';

/// Tela de bloqueio exibida ao abrir o app quando o acesso por biometria está
/// ativo. Pede a biometria ou a senha do celular antes de liberar o conteúdo.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await BiometricAuth.instance.authenticate(
      reason: 'Desbloqueie o Controla Simples',
    );
    if (!mounted) return;
    if (result.success) {
      ref.read(appUnlockedProvider.notifier).unlock();
      return;
    }
    setState(() => _busy = false);
    final message = result.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const BrandMark(size: 68),
              ),
              const SizedBox(height: 28),
              Text(
                'Conta protegida',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use sua biometria ou a senha do celular para acessar o Controla Simples.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _authenticate,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(_busy ? 'Autenticando...' : 'Desbloquear'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
