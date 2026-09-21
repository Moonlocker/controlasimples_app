import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logotipo do gateway de pagamento (Asaas, Mercado Pago, Pagar.me...).
/// Usa as imagens embutidas em `assets/branding` para não depender de rede.
class PaymentProviderLogo extends StatelessWidget {
  const PaymentProviderLogo({
    super.key,
    required this.provider,
    this.size = 32,
    this.dim = false,
  });

  final String? provider;
  final double size;
  final bool dim;

  static const Map<String, String> _assets = {
    'asaas': 'assets/branding/provider-asaas.png',
    'mercadopago': 'assets/branding/provider-mercadopago.png',
    'pagarme': 'assets/branding/provider-pagarme.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = provider == null ? null : _assets[provider];
    final child = asset == null
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              size: size * 0.6,
              color: AppColors.mutedForeground,
            ),
          )
        : Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.account_balance_outlined,
              size: size * 0.7,
              color: AppColors.mutedForeground,
            ),
          );

    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: child,
      ),
    );
  }
}
