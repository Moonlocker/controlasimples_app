import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/biometric_auth.dart';
import '../../widgets/brand_logo.dart';
import 'biometric_providers.dart';

/// Tela de ativação do acesso rápido por biometria/senha do aparelho.
///
/// Referência visual: ilustração no topo, título, três destaques e o botão
/// "Ativar", seguindo a identidade do Controla Simples.
class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _busy = false;

  Future<void> _activate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await BiometricAuth.instance.authenticate(
      reason: 'Ative o acesso rápido à sua conta',
    );
    if (!mounted) return;
    if (result.success) {
      await ref.read(biometricEnabledProvider.notifier).setEnabled(true);
      if (!mounted) return;
      context.pop(true);
      return;
    }
    setState(() => _busy = false);
    final message = result.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Fecha sem ativar: registra que o convite foi recusado para não insistir a
  /// cada abertura (o usuário ainda pode ativar em Configurações).
  Future<void> _close() async {
    await ref.read(biometricPromptDismissedProvider.notifier).dismiss();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Fechar',
                onPressed: _close,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _BiometricIllustration(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acesso rápido, fácil e conta protegida com a biometria',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _FeatureRow(
                          icon: Icons.lock_outline,
                          text: 'Ative o desbloqueio do celular para entrar na conta de forma fácil e segura',
                        ),
                        const _FeatureDivider(),
                        const _FeatureRow(
                          icon: Icons.fingerprint,
                          text: 'Use impressão digital, o reconhecimento facial ou a senha do celular',
                        ),
                        const _FeatureDivider(),
                        const _FeatureRow(
                          icon: Icons.handshake_outlined,
                          text: 'Praticidade para você enquanto protegemos a sua conta!',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                onPressed: _busy ? null : _activate,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ativar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.foreground, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 26, color: AppColors.border);
  }
}

/// Ilustração de marca com o símbolo do Controla Simples cercado por atalhos
/// de segurança (cadeado, digital, verificação e senha).
class _BiometricIllustration extends StatelessWidget {
  const _BiometricIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primarySoft, AppColors.surface],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 224,
            height: 224,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 168,
            height: 168,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const BrandMark(size: 92),
          ),
          const Align(
            alignment: Alignment(-0.62, -0.62),
            child: _IllustrationChip(icon: Icons.lock_outline),
          ),
          const Align(
            alignment: Alignment(0.66, -0.5),
            child: _IllustrationChip(icon: Icons.fingerprint),
          ),
          const Align(
            alignment: Alignment(0.6, 0.62),
            child: _IllustrationChip(icon: Icons.verified_user_outlined),
          ),
          const Align(
            alignment: Alignment(-0.66, 0.55),
            child: _IllustrationChip(icon: Icons.password_outlined),
          ),
        ],
      ),
    );
  }
}

class _IllustrationChip extends StatelessWidget {
  const _IllustrationChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.primary, size: 26),
    );
  }
}
