import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Superfície onde a marca será aplicada.
enum BrandSurface {
  /// Logotipo colorido (texto escuro), ideal para fundos claros.
  light,

  /// Logotipo com texto branco, ideal para fundos escuros.
  dark,
}

/// Logotipo completo do Controla Simples (símbolo + assinatura).
///
/// Usa os mesmos arquivos de marca do sistema web para manter a identidade.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.surface = BrandSurface.light,
    this.width = 150,
    this.alignment = Alignment.centerLeft,
  });

  final BrandSurface surface;
  final double width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      surface == BrandSurface.dark
          ? 'assets/branding/logo-dark.png'
          : 'assets/branding/logo-light.png',
      width: width,
      alignment: alignment,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Controla Simples',
    );
  }
}

/// Símbolo (marca) do Controla Simples isolado, sem a assinatura.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.white = false});

  final double size;

  /// Quando verdadeiro usa a marca branca (para fundos escuros ou coloridos).
  final bool white;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      white ? 'assets/branding/mark-white.png' : 'assets/branding/mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Controla Simples',
    );
  }
}

/// Bloco de marca com o símbolo em destaque, usado em cabeçalhos e cartões.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 44, this.radius = 14, this.onDark = false});

  final double size;
  final double radius;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: BrandMark(size: size * 0.72, white: onDark),
    );
  }
}
