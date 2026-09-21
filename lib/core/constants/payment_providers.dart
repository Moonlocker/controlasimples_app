/// Catálogo dos provedores de pagamento (rótulos, links e passo a passo).
class PaymentProviderGuideStep {
  const PaymentProviderGuideStep({
    required this.title,
    required this.body,
    this.linkLabel,
    this.linkUrl,
  });

  final String title;
  final String body;
  final String? linkLabel;
  final String? linkUrl;
}

class PaymentProviderCatalog {
  const PaymentProviderCatalog({
    required this.id,
    required this.label,
    required this.short,
    required this.docsUrl,
    required this.webhookPath,
    required this.accessTokenLabel,
    required this.accessTokenPlaceholder,
    required this.webhookSecretLabel,
    required this.webhookSecretHint,
    required this.steps,
    required this.events,
  });

  final String id;
  final String label;
  final String short;
  final String docsUrl;
  final String webhookPath;
  final String accessTokenLabel;
  final String accessTokenPlaceholder;
  final String webhookSecretLabel;
  final String webhookSecretHint;
  final List<PaymentProviderGuideStep> steps;
  final List<String> events;
}

const List<PaymentProviderCatalog> paymentProviders = [
  PaymentProviderCatalog(
    id: 'asaas',
    label: 'Asaas',
    short: 'Asaas',
    docsUrl: 'https://www.asaas.com/',
    webhookPath: '/api/public/asaas-webhook',
    accessTokenLabel: 'Chave de API (access_token)',
    accessTokenPlaceholder: '\$aact_...',
    webhookSecretLabel: 'Token do webhook',
    webhookSecretHint: 'O mesmo token cadastrado no webhook do Asaas.',
    steps: [
      PaymentProviderGuideStep(
        title: 'Acesse sua conta Asaas',
        body: 'Entre em asaas.com (crie uma conta se ainda não tiver).',
        linkLabel: 'asaas.com',
        linkUrl: 'https://www.asaas.com/',
      ),
      PaymentProviderGuideStep(
        title: 'Gere uma chave de API',
        body: 'Abra Integrações › Chaves de API e gere uma nova chave (access token).',
        linkLabel: 'Integrações › Chaves de API',
        linkUrl: 'https://www.asaas.com/customerApiAccessToken/index',
      ),
      PaymentProviderGuideStep(
        title: 'Cole a chave e escolha o ambiente',
        body: 'Use Sandbox para testes ou Produção para valer de verdade.',
      ),
      PaymentProviderGuideStep(
        title: 'Ative e teste',
        body: 'Ligue a integração, salve e toque em Testar conexão.',
      ),
      PaymentProviderGuideStep(
        title: 'Gere o token do webhook',
        body: 'Crie um token no campo de webhook e salve.',
      ),
      PaymentProviderGuideStep(
        title: 'Cadastre o webhook',
        body: 'Abra Integrações › Webhooks, informe a URL abaixo e o mesmo token.',
        linkLabel: 'Integrações › Webhooks',
        linkUrl: 'https://www.asaas.com/customerConfigIntegrations/webhooks',
      ),
    ],
    events: [
      'PAYMENT_CREATED',
      'PAYMENT_UPDATED',
      'PAYMENT_CONFIRMED',
      'PAYMENT_RECEIVED',
      'PAYMENT_RECEIVED_IN_CASH',
      'PAYMENT_OVERDUE',
      'PAYMENT_DELETED',
      'PAYMENT_REFUNDED',
      'PAYMENT_CHARGEBACK_REQUESTED',
      'PAYMENT_DUNNING_RECEIVED',
      'SUBSCRIPTION_CREATED',
      'SUBSCRIPTION_UPDATED',
      'SUBSCRIPTION_INACTIVATED',
      'SUBSCRIPTION_DELETED',
    ],
  ),
  PaymentProviderCatalog(
    id: 'pagarme',
    label: 'Pagar.me',
    short: 'Pagar.me',
    docsUrl: 'https://docs.pagar.me/',
    webhookPath: '/api/public/pagarme-webhook',
    accessTokenLabel: 'Secret Key',
    accessTokenPlaceholder: 'sk_test_... ou sk_live_...',
    webhookSecretLabel: 'Senha do webhook',
    webhookSecretHint: 'A mesma senha (ou chave secreta) configurada no webhook do Pagar.me, usada para validar as notificações.',
    steps: [
      PaymentProviderGuideStep(
        title: 'Acesse o painel do Pagar.me',
        body:
            'Entre em dashboard.pagar.me (crie uma conta se ainda não tiver).',
        linkLabel: 'dashboard.pagar.me',
        linkUrl: 'https://dashboard.pagar.me/',
      ),
      PaymentProviderGuideStep(
        title: 'Copie a Secret Key',
        body: 'Abra Configurações › Chaves e copie a Secret Key (sk_test_ ou sk_live_).',
        linkLabel: 'Chaves de API',
        linkUrl: 'https://dashboard.pagar.me/#/account/keys',
      ),
      PaymentProviderGuideStep(
        title: 'Cole a chave e escolha o ambiente',
        body: 'Use Teste para validar e Produção para valer de verdade.',
      ),
      PaymentProviderGuideStep(
        title: 'Ative e teste',
        body: 'Ligue a integração, salve e toque em Testar conexão.',
      ),
      PaymentProviderGuideStep(
        title: 'Cadastre o webhook',
        body: 'Em Configurações › Webhooks, informe a URL abaixo, escolha uma senha e marque os eventos de cobrança/estorno.',
        linkLabel: 'Configurações › Webhooks',
        linkUrl: 'https://dashboard.pagar.me/#/account/webhooks',
      ),
      PaymentProviderGuideStep(
        title: 'Informe a senha do webhook',
        body: 'Copie a mesma senha cadastrada no webhook e cole no campo de segredo para validar as notificações.',
      ),
    ],
    events: [
      'charge.paid',
      'charge.pending',
      'charge.processing',
      'charge.payment_failed',
      'charge.canceled',
      'charge.refunded',
      'order.paid',
      'order.pending',
      'order.canceled',
      'checkout.paid',
    ],
  ),
  PaymentProviderCatalog(
    id: 'mercadopago',
    label: 'Mercado Pago',
    short: 'Mercado Pago',
    docsUrl: 'https://www.mercadopago.com.br/developers/pt',
    webhookPath: '/api/public/mercadopago-webhook',
    accessTokenLabel: 'Access Token',
    accessTokenPlaceholder: 'APP_USR-... ou TEST-...',
    webhookSecretLabel: 'Chave secreta do webhook',
    webhookSecretHint:
        'Usada para validar a assinatura das notificações do Mercado Pago.',
    steps: [
      PaymentProviderGuideStep(
        title: 'Acesse sua conta Mercado Pago',
        body:
            'Entre em mercadopago.com.br (crie uma conta se ainda não tiver).',
        linkLabel: 'mercadopago.com.br',
        linkUrl: 'https://www.mercadopago.com.br/',
      ),
      PaymentProviderGuideStep(
        title: 'Copie o Access Token',
        body: 'Abra Seu negócio › Configurações › Credenciais (produção ou teste) e copie o Access Token.',
        linkLabel: 'Credenciais de integração',
        linkUrl: 'https://www.mercadopago.com.br/settings/account/credentials',
      ),
      PaymentProviderGuideStep(
        title: 'Cole o token e escolha o ambiente',
        body: 'Use Teste para validar e Produção para valer de verdade.',
      ),
      PaymentProviderGuideStep(
        title: 'Ative e teste',
        body: 'Ligue a integração, salve e toque em Testar conexão.',
      ),
      PaymentProviderGuideStep(
        title: 'Cadastre o webhook',
        body: 'Em Suas integrações › sua aplicação › Webhooks, informe a URL abaixo e marque o evento Pagamentos.',
        linkLabel: 'Suas integrações (aplicações)',
        linkUrl: 'https://www.mercadopago.com.br/developers/panel/app',
      ),
      PaymentProviderGuideStep(
        title: 'Informe a chave secreta',
        body: 'Copie a Chave secreta exibida na tela de webhooks e cole no campo de segredo para validar as notificações.',
      ),
    ],
    events: ['Pagamentos (payment)', 'Assinaturas (preapproval)'],
  ),
];

PaymentProviderCatalog? paymentProviderCatalog(String? id) {
  for (final provider in paymentProviders) {
    if (provider.id == id) return provider;
  }
  return null;
}

String paymentProviderLabel(String? id) =>
    paymentProviderCatalog(id)?.short ?? 'gateway';
