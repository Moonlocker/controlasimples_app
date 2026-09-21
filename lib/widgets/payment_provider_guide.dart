import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/payment_providers.dart';
import '../core/theme/app_colors.dart';

/// Passo a passo de configuração de um provedor de pagamento, com links,
/// eventos recomendados e URL do webhook.
class PaymentProviderGuide extends StatelessWidget {
  const PaymentProviderGuide({
    super.key,
    required this.providerId,
    this.webhookUrl,
    this.videoUrl,
  });

  final String providerId;
  final String? webhookUrl;
  final String? videoUrl;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL do webhook copiada.')));
    }
  }

  Widget _text(String value) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.mutedForeground,
        height: 1.35,
      ),
    );
  }

  Widget _link(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => _openUrl(context, url),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = paymentProviderCatalog(providerId);
    final textTheme = Theme.of(context).textTheme;
    if (entry == null) return const SizedBox.shrink();
    final url = webhookUrl ?? '';
    final hasVideo = (videoUrl ?? '').trim().isNotEmpty;

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
          'Como configurar no ${entry.label} (passo a passo)',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          for (var i = 0; i < entry.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _text('${entry.steps[i].title}. '),
                        _text(entry.steps[i].body),
                        if (entry.steps[i].linkUrl != null &&
                            entry.steps[i].linkLabel != null) ...[
                          const SizedBox(width: 4),
                          _link(
                            context,
                            entry.steps[i].linkLabel!,
                            entry.steps[i].linkUrl!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (entry.events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.steps.length + 1}. ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text('Marque os eventos:'),
                        const SizedBox(height: 4),
                        for (final event in entry.events)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 6),
                                  child: Icon(
                                    Icons.check,
                                    size: 13,
                                    color: AppColors.success,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    event,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (url.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL do webhook (cadastre no ${entry.label}):',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          url,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copy(context, url),
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar URL',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (hasVideo)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(context, videoUrl!.trim()),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Assistir ao vídeo explicativo'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
