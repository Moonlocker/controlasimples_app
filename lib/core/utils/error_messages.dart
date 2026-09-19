/// Indica se o erro é provavelmente falta de conexão com a internet.
bool isOfflineError(Object? error) {
  final message = _rawMessage(error).toLowerCase();
  if (message.isEmpty) return false;
  return _connectionNeedles.any(message.contains);
}

const List<String> _connectionNeedles = [
  'failed host lookup',
  'socketexception',
  'socket exception',
  'network is unreachable',
  'network error',
  'connection refused',
  'connection closed',
  'connection reset',
  'connection error',
  'connection attempt',
  'clientexception',
  'xmlhttprequest',
  'no address associated',
  'nodename nor servname',
  'temporary failure in name resolution',
  'dns',
  'offline',
  'timed out',
  'timeout',
  'handshake',
];

/// Traduz erros técnicos em mensagens claras, curtas e amigáveis para o
/// usuário final.
///
/// Regra de ouro: nunca exibir códigos, stack traces, links quebrados ou
/// detalhes internos do servidor. Quando não houver tradução específica,
/// usamos um texto genérico e acolhedor.
String friendlyError(
  Object? error, {
  String fallback = 'Algo deu errado. Tente novamente em instantes.',
}) {
  final message = _rawMessage(error).trim().toLowerCase();
  if (message.isEmpty) return fallback;

  bool has(List<String> needles) => needles.any(message.contains);

  // Conexão / rede.
  if (isOfflineError(error)) {
    return 'Parece que você está sem internet. Verifique sua conexão e tente novamente.';
  }

  // Serviço fora do ar / erro do servidor.
  if (has(const [
    'service unavailable',
    'bad gateway',
    'gateway timeout',
    'internal server error',
    'erro 500',
    'erro 502',
    'erro 503',
    'erro 504',
    'statuscode: 500',
    'statuscode: 502',
    'statuscode: 503',
    'statuscode: 504',
  ])) {
    return 'Nosso serviço está temporariamente indisponível. Tente novamente em alguns instantes.';
  }

  // Sessão / permissão.
  if (has(const [
    'jwt expired',
    'invalid jwt',
    'not authenticated',
    'session expired',
    'refresh token',
    'statuscode: 401',
  ])) {
    return 'Sua sessão expirou. Entre novamente para continuar.';
  }
  if (has(const [
    'permission denied',
    'row level security',
    'not authorized',
    'statuscode: 403',
  ])) {
    return 'Você não tem permissão para fazer isso.';
  }

  // Autenticação.
  if (has(const ['invalid login credentials'])) {
    return 'E-mail ou senha inválidos.';
  }
  if (has(const ['email not confirmed'])) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (has(const ['user already registered', 'already registered'])) {
    return 'Este e-mail já está cadastrado. Faça login.';
  }
  if (has(const ['password should be at least'])) {
    return 'A senha é muito curta.';
  }
  if (has(const ['rate limit', 'too many requests', 'too many'])) {
    return 'Muitas tentativas. Aguarde um instante e tente de novo.';
  }

  // Dados inexistentes.
  if (has(const ['not found', 'statuscode: 404', 'no rows'])) {
    return 'Não encontramos essas informações.';
  }

  // Mensagens de negócio já legíveis (ex.: "Limite de mensagens atingido")
  // podem ser repassadas, desde que não pareçam técnicas.
  final raw = _rawMessage(error).trim();
  final looksTechnical =
      raw.contains('://') ||
      message.contains('exception') ||
      message.contains('#0') ||
      RegExp(r'\b[45]\d\d\b').hasMatch(raw);
  if (!looksTechnical && raw.length <= 180) return raw;

  return fallback;
}

String _rawMessage(Object? error) {
  if (error == null) return '';
  final raw = error.toString();
  // Erros genéricos (`Exception`) vêm prefixados; removemos o ruído técnico.
  return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
}
