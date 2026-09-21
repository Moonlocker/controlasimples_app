import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/mask_formatter.dart';
import '../../core/utils/error_messages.dart';
import '../../models/plan.dart';
import '../../models/user_business.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/quotes_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/brand_logo.dart';
import '../auth/auth_providers.dart';
import '../quotes/quotes_providers.dart';
import '../subscription/subscription_flow.dart';

/// Assistente de primeiros passos, exibido uma única vez no primeiro acesso.
///
/// Conduz o usuário por: boas-vindas → dados da conta → marca dos orçamentos →
/// escolha do plano → conclusão. Ao final grava `profiles.setup_completed`.
class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  static const int _stepCount = 5;

  final _pageController = PageController();
  int _step = 0;

  // Conta
  final _accountFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();

  // Marca (orçamentos)
  final _brandCompany = TextEditingController();
  final _brandDocument = TextEditingController();
  final _brandEmail = TextEditingController();
  final _brandPhone = TextEditingController();
  final _brandAddress = TextEditingController();
  final _brandPayment = TextEditingController();
  final _brandNote = TextEditingController();
  String? _logo;

  bool _busy = false;
  bool _planChosen = false;
  bool _brandHasData = false;
  bool _mirrorAccount = true;

  @override
  void initState() {
    super.initState();
    final workspace = ref.read(workspaceProvider).value;
    final profile = workspace?.profile;
    _name.text = profile?.name ?? '';
    _company.text = profile?.company ?? '';
    _document.text = profile?.document ?? '';
    _phone.text = profile?.phone ?? '';
    _planChosen = workspace?.onboardingCompleted ?? false;

    // A marca começa espelhando os dados da conta.
    _brandCompany.text = _company.text;
    _brandDocument.text = _document.text;
    _brandPhone.text = _phone.text;
    _brandEmail.text = profile?.email ?? '';
    _company.addListener(_syncBrandFromAccount);
    _document.addListener(_syncBrandFromAccount);
    _phone.addListener(_syncBrandFromAccount);

    ref.read(businessProvider.future).then((business) {
      if (!mounted || business == null) return;
      setState(() {
        _brandCompany.text = business.company ?? _company.text;
        _brandDocument.text = business.document ?? _document.text;
        _brandEmail.text = business.email ?? _brandEmail.text;
        _brandPhone.text = business.phone ?? _phone.text;
        _brandAddress.text = business.address ?? '';
        _brandPayment.text = business.paymentInfo ?? '';
        _brandNote.text = business.extraNote ?? '';
        _logo = business.logo;
        _brandHasData = _hasBrandContent(business);
      });
    });
  }

  void _syncBrandFromAccount() {
    if (!_mirrorAccount) return;
    _brandCompany.text = _company.text;
    _brandDocument.text = _document.text;
    _brandPhone.text = _phone.text;
  }

  void _setMirror(bool value) {
    setState(() => _mirrorAccount = value);
    if (value) _syncBrandFromAccount();
  }

  bool _hasBrandContent(UserBusiness business) =>
      (business.logo ?? '').isNotEmpty ||
      (business.company ?? '').isNotEmpty ||
      (business.paymentInfo ?? '').isNotEmpty ||
      (business.address ?? '').isNotEmpty;

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _company.dispose();
    _document.dispose();
    _phone.dispose();
    _brandCompany.dispose();
    _brandDocument.dispose();
    _brandEmail.dispose();
    _brandPhone.dispose();
    _brandAddress.dispose();
    _brandPayment.dispose();
    _brandNote.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  Future<void> _saveAccount() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(profileRepositoryProvider)
        .update(
          userId: userId,
          name: _name.text.trim(),
          company: _company.text.trim(),
          phone: _phone.text.trim(),
          document: onlyDigits(_document.text),
        );
    ref.invalidate(workspaceProvider);
  }

  Future<void> _saveBrand() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(quotesRepositoryProvider)
        .saveBusiness(
          userId: userId,
          logo: _logo,
          company: (_mirrorAccount ? _company : _brandCompany).text.trim(),
          document: (_mirrorAccount ? _document : _brandDocument).text.trim(),
          email: _brandEmail.text.trim(),
          phone: (_mirrorAccount ? _phone : _brandPhone).text.trim(),
          address: _brandAddress.text.trim(),
          paymentInfo: _brandPayment.text.trim(),
          extraNote: _brandNote.text.trim(),
        );
    ref.invalidate(businessProvider);
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 1 && !(_accountFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_step == 3 && !_planChosen) {
      _showMessage('Escolha um plano para continuar.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_step == 1) await _saveAccount();
      if (_step == 2) await _saveBrand();
      _goTo(_step + 1);
    } catch (error) {
      _showMessage(
        'Não foi possível salvar: ${friendlyError(error)}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skipBrand() {
    _goTo(_step + 1);
  }

  Future<void> _choosePlan(Plan plan) async {
    final ok = await subscribeToPlanFlow(context, ref, plan);
    if (!mounted) return;
    if (!ok) return;
    setState(() => _planChosen = true);
    // Plano gratuito não gera cobrança: segue direto para a conclusão.
    if (plan.price <= 0) _goTo(_step + 1);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/png';
      setState(() => _logo = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      _showMessage(
        'Não foi possível carregar a imagem: ${friendlyError(error)}',
        error: true,
      );
    }
  }

  Future<void> _finish() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).completeSetup(userId);
      ref.invalidate(workspaceProvider);
      if (mounted) {
        _showMessage('Tudo pronto! Bem-vindo ao Controla Simples.');
      }
    } catch (error) {
      _showMessage(
        'Não foi possível concluir: ${friendlyError(error)}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: _step,
              total: _stepCount,
              onBack: _step == 0 ? null : () => _goTo(_step - 1),
              onLogout: () => ref.read(authRepositoryProvider).signOut(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _WelcomeStep(),
                  _AccountStep(
                    formKey: _accountFormKey,
                    name: _name,
                    company: _company,
                    document: _document,
                    phone: _phone,
                  ),
                  _BrandStep(
                    logo: _logo,
                    company: _brandCompany,
                    document: _brandDocument,
                    email: _brandEmail,
                    phone: _brandPhone,
                    address: _brandAddress,
                    paymentInfo: _brandPayment,
                    extraNote: _brandNote,
                    mirrorAccount: _mirrorAccount,
                    onToggleMirror: _setMirror,
                    onPickLogo: _pickLogo,
                    onRemoveLogo: () => setState(() => _logo = null),
                  ),
                  _PlanStep(planChosen: _planChosen, onChoose: _choosePlan),
                  _DoneStep(
                    name: _name.text.trim(),
                    brandConfigured:
                        _brandHasData ||
                        _brandCompany.text.trim().isNotEmpty ||
                        _logo != null,
                  ),
                ],
              ),
            ),
            _WizardFooter(
              step: _step,
              busy: _busy,
              planChosen: _planChosen,
              onPrimary: _step == _stepCount - 1 ? _finish : _next,
              onSkip: _step == 2 ? _skipBrand : null,
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ header */

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.total,
    required this.onBack,
    required this.onLogout,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: onBack == null
                    ? null
                    : IconButton(
                        tooltip: 'Voltar',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
              ),
              const Spacer(),
              Text(
                'Passo ${step + 1} de $total',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sair',
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.muted,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ footer */

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.step,
    required this.busy,
    required this.planChosen,
    required this.onPrimary,
    this.onSkip,
  });

  final int step;
  final bool busy;
  final bool planChosen;
  final Future<void> Function() onPrimary;
  final VoidCallback? onSkip;

  String get _label {
    switch (step) {
      case 0:
        return 'Começar';
      case 2:
        return 'Salvar e continuar';
      case 4:
        return 'Começar a usar';
      default:
        return 'Continuar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = step != 3 || planChosen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: (!enabled || busy) ? null : () => onPrimary(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_label),
          ),
          if (onSkip != null)
            TextButton(
              onPressed: busy ? null : onSkip,
              child: const Text('Pular por agora'),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------- steps */

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const SizedBox(height: 12),
        const Center(child: BrandBadge()),
        const SizedBox(height: 28),
        Text(
          'Bem-vindo ao\nControla Simples',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vamos configurar sua conta em poucos passos para você começar '
          'com tudo no lugar. Leva menos de 2 minutos.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 32),
        const _FeatureRow(
          icon: Icons.receipt_long_outlined,
          title: 'Cobranças e recebimentos',
          description: 'Emita, acompanhe e receba com Pix, boleto ou cartão.',
        ),
        const _FeatureRow(
          icon: Icons.workspaces_outline,
          title: 'Serviços e recorrências',
          description: 'Organize serviços e gere cobranças automaticamente.',
        ),
        const _FeatureRow(
          icon: Icons.description_outlined,
          title: 'Orçamentos profissionais',
          description: 'Monte orçamentos com a sua marca e envie em PDF.',
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.formKey,
    required this.name,
    required this.company,
    required this.document,
    required this.phone,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController company;
  final TextEditingController document;
  final TextEditingController phone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepIntro(
              title: 'Seus dados',
              subtitle:
                  'Usamos essas informações nas cobranças e orçamentos. '
                  'Você pode editar depois em Configurações.',
            ),
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe seu nome'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: document,
              keyboardType: TextInputType.number,
              inputFormatters: [MaskTextInputFormatter(cpfCnpjMask)],
              decoration: const InputDecoration(
                labelText: 'CPF ou CNPJ *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length != 11 && digits.length != 14) {
                  return 'Informe um CPF ou CNPJ válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Empresa (opcional)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [MaskTextInputFormatter(phoneMask)],
              decoration: const InputDecoration(
                labelText: 'Telefone (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandStep extends StatelessWidget {
  const _BrandStep({
    required this.logo,
    required this.company,
    required this.document,
    required this.email,
    required this.phone,
    required this.address,
    required this.paymentInfo,
    required this.extraNote,
    required this.mirrorAccount,
    required this.onToggleMirror,
    required this.onPickLogo,
    required this.onRemoveLogo,
  });

  final String? logo;
  final TextEditingController company;
  final TextEditingController document;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController paymentInfo;
  final TextEditingController extraNote;
  final bool mirrorAccount;
  final ValueChanged<bool> onToggleMirror;
  final Future<void> Function() onPickLogo;
  final VoidCallback onRemoveLogo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepIntro(
            title: 'Sua marca nos orçamentos',
            subtitle:
                'Personalize o PDF enviado aos clientes. Tudo opcional — '
                'você pode preencher depois.',
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: mirrorAccount,
              onChanged: onToggleMirror,
              title: const Text('Usar os dados da conta'),
              subtitle: const Text(
                'Empresa, CPF/CNPJ e telefone iguais aos do passo anterior. '
                'Desligue para usar dados diferentes nos orçamentos.',
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logo == null
                      ? const Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppColors.mutedForeground,
                        )
                      : Image.memory(
                          base64Decode(logo!.split(',').last),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onPickLogo(),
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(logo == null ? 'Enviar logo' : 'Trocar logo'),
                    ),
                    if (logo != null)
                      TextButton(
                        onPressed: onRemoveLogo,
                        child: const Text('Remover'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: company,
            textCapitalization: TextCapitalization.words,
            enabled: !mirrorAccount,
            decoration: const InputDecoration(labelText: 'Empresa'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: document,
            keyboardType: TextInputType.number,
            enabled: !mirrorAccount,
            inputFormatters: [MaskTextInputFormatter(cpfCnpjMask)],
            decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            enabled: !mirrorAccount,
            inputFormatters: [MaskTextInputFormatter(phoneMask)],
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Endereço'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: paymentInfo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Formas de pagamento',
              hintText: 'Ex: Pix (chave), conta bancária…',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: extraNote,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observação padrão',
              hintText: 'Ex: Validade de 15 dias.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStep extends ConsumerWidget {
  const _PlanStep({required this.planChosen, required this.onChoose});

  final bool planChosen;
  final Future<void> Function(Plan plan) onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).value;
    final plans = workspace?.plans ?? const <Plan>[];
    final currentPlan = workspace?.plan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const _StepIntro(
          title: 'Escolha seu plano',
          subtitle:
              'Comece grátis ou assine agora. Você pode trocar de plano '
              'quando quiser.',
        ),
        if (planChosen)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plano selecionado. Toque em continuar para finalizar.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final plan in plans) ...[
          _WizardPlanCard(
            plan: plan,
            current: plan.id == currentPlan?.id,
            onTap: () => onChoose(plan),
          ),
          const SizedBox(height: 10),
        ],
        if (plans.isEmpty)
          const Text(
            'Nenhum plano disponível no momento. Fale com o suporte.',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _WizardPlanCard extends StatelessWidget {
  const _WizardPlanCard({
    required this.plan,
    required this.current,
    required this.onTap,
  });

  final Plan plan;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plan.highlighted ? AppColors.primary : AppColors.border,
            width: plan.highlighted ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  plan.price <= 0 ? 'Grátis' : '${brl(plan.price)}/mês',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final feature in plan.features.take(4))
                  _Chip(label: feature),
                if (plan.allowAsaasIntegration)
                  const _Chip(label: 'Pagamentos'),
                if (plan.allowWhatsappNotifications)
                  const _Chip(label: 'WhatsApp'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  current ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: current
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  current ? 'Plano atual' : 'Toque para escolher',
                  style: textTheme.labelMedium?.copyWith(
                    color: current
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.name, required this.brandConfigured});

  final String name;
  final bool brandConfigured;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = name.split(RegExp(r'\s+')).first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 52,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          firstName.isEmpty ? 'Tudo pronto!' : 'Tudo pronto, $firstName!',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Sua conta está configurada. Agora é só usar a plataforma.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 28),
        const _DoneItem(label: 'Dados da conta preenchidos'),
        if (brandConfigured)
          const _DoneItem(label: 'Marca dos orçamentos configurada'),
        const _DoneItem(label: 'Plano definido'),
      ],
    );
  }
}

class _DoneItem extends StatelessWidget {
  const _DoneItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
