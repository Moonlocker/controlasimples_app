import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';

/// Passo a passo de configuração do Asaas, com vídeo explicativo opcional.
class AsaasSetupGuide extends StatelessWidget {
  const AsaasSetupGuide({super.key, this.videoUrl});

  final String? videoUrl;

  static const _steps = <String>[
    'Acesse asaas.com e entre na sua conta (crie uma se ainda não tiver).',
    'No menu, vá em Integrações › Chaves de API e gere uma nova chave (access token).',
    'Copie a chave e cole no campo "Chave de API" abaixo. Escolha Sandbox para testes ou Produção para valer de verdade.',
    'Ligue a opção "Ativar emissão de cobranças", salve e toque em "Testar conexão".',
    'Gere um token de webhook no painel do Asaas e informe o mesmo valor no sistema.',
    'No Asaas, vá em Integrações › Webhooks, cadastre a URL do sistema e marque para receber todos os eventos.',
    'Pronto! Ao gerar uma cobrança, ela é criada na sua conta Asaas e o status é atualizado automaticamente.',
  ];

  Future<void> _openVideo(BuildContext context) async {
    final url = videoUrl?.trim() ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.checklist, color: AppColors.primary),
        title: Text(
          'Como configurar no Asaas (passo a passo)',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if ((videoUrl ?? '').trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openVideo(context),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Assistir ao vídeo explicativo'),
              ),
            ),
        ],
      ),
    );
  }
}
